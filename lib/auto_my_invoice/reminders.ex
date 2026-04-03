defmodule AutoMyInvoice.Reminders do
  @moduledoc "리마인더 스케줄링, 발송, 추적 Context"

  import Ecto.Query
  alias AutoMyInvoice.Repo
  alias AutoMyInvoice.Reminders.Reminder
  alias AutoMyInvoice.Workers.ReminderWorker

  @step_offsets %{1 => 1, 2 => 7, 3 => 14}

  ## 스케줄링

  @spec schedule_reminders(map()) :: {:ok, [Reminder.t()]}
  def schedule_reminders(%{id: invoice_id, due_date: due_date, client: client}) do
    timezone = client.timezone || "UTC"

    reminders =
      for {step, offset} <- @step_offsets do
        scheduled_at = calculate_send_time(due_date, offset, timezone)

        {:ok, reminder} =
          %Reminder{invoice_id: invoice_id}
          |> Reminder.changeset(%{step: step, scheduled_at: scheduled_at, status: "scheduled"})
          |> Repo.insert()

        {:ok, oban_job} =
          %{reminder_id: reminder.id}
          |> ReminderWorker.new(scheduled_at: scheduled_at)
          |> Oban.insert()

        {:ok, updated} =
          reminder
          |> Reminder.changeset(%{oban_job_id: oban_job.id})
          |> Repo.update()

        updated
      end

    {:ok, reminders}
  end

  ## 수동 리마인더

  @manual_allowed_statuses ~w(sent overdue partially_paid)

  @spec send_manual_reminder(map()) :: {:ok, Reminder.t()} | {:error, :invalid_status | :rate_limited}
  def send_manual_reminder(%{status: status} = _invoice) when status not in @manual_allowed_statuses do
    {:error, :invalid_status}
  end

  def send_manual_reminder(%{id: invoice_id} = _invoice) do
    today = Date.utc_today()
    today_start = DateTime.new!(today, ~T[00:00:00], "Etc/UTC")
    today_end = DateTime.new!(Date.add(today, 1), ~T[00:00:00], "Etc/UTC")

    already_sent_today =
      from(r in Reminder,
        where: r.invoice_id == ^invoice_id,
        where: r.step == 0,
        where: r.sent_at >= ^today_start and r.sent_at < ^today_end
      )
      |> Repo.exists?()

    if already_sent_today do
      {:error, :rate_limited}
    else
      # Remove previous step=0 reminder to avoid unique constraint violation
      from(r in Reminder,
        where: r.invoice_id == ^invoice_id,
        where: r.step == 0
      )
      |> Repo.delete_all()

      now = DateTime.truncate(DateTime.utc_now(), :second)

      {:ok, reminder} =
        %Reminder{invoice_id: invoice_id}
        |> Reminder.changeset(%{step: 0, scheduled_at: now, status: "scheduled"})
        |> Repo.insert()

      {:ok, _oban_job} =
        %{reminder_id: reminder.id}
        |> ReminderWorker.new()
        |> Oban.insert()

      {:ok, reminder}
    end
  end

  ## 취소

  @spec cancel_pending_reminders(binary()) :: {integer(), nil}
  def cancel_pending_reminders(invoice_id) do
    pending_reminders =
      from(r in Reminder,
        where: r.invoice_id == ^invoice_id,
        where: r.status in ~w(pending scheduled)
      )
      |> Repo.all()

    Enum.each(pending_reminders, fn reminder ->
      if reminder.oban_job_id, do: Oban.cancel_job(reminder.oban_job_id)

      reminder
      |> Reminder.changeset(%{status: "cancelled"})
      |> Repo.update()
    end)

    {length(pending_reminders), nil}
  end

  ## 추적

  @spec record_open(binary()) :: {:ok, Reminder.t()}
  def record_open(reminder_id) do
    reminder = Repo.get!(Reminder, reminder_id)

    attrs = %{
      open_count: reminder.open_count + 1,
      opened_at: reminder.opened_at || DateTime.truncate(DateTime.utc_now(), :second)
    }

    reminder
    |> Reminder.tracking_changeset(attrs)
    |> Repo.update()
  end

  @spec record_click(binary()) :: {:ok, Reminder.t()}
  def record_click(reminder_id) do
    reminder = Repo.get!(Reminder, reminder_id)

    attrs = %{
      click_count: reminder.click_count + 1,
      clicked_at: reminder.clicked_at || DateTime.truncate(DateTime.utc_now(), :second)
    }

    reminder
    |> Reminder.tracking_changeset(attrs)
    |> Repo.update()
  end

  ## 조회

  @spec count_active_reminders(binary()) :: integer()
  def count_active_reminders(user_id) do
    from(r in Reminder,
      join: i in assoc(r, :invoice),
      where: i.user_id == ^user_id,
      where: r.status in ~w(pending scheduled),
      select: count(r.id)
    )
    |> Repo.one()
  end

  @spec list_reminders_for_invoice(binary()) :: [Reminder.t()]
  def list_reminders_for_invoice(invoice_id) do
    from(r in Reminder,
      where: r.invoice_id == ^invoice_id,
      order_by: [asc: r.step]
    )
    |> Repo.all()
  end

  @spec reminder_stats(binary()) :: [map()]
  def reminder_stats(user_id) do
    from(r in Reminder,
      join: i in assoc(r, :invoice),
      where: i.user_id == ^user_id,
      where: r.status == "sent",
      group_by: r.step,
      select: %{
        step: r.step,
        total_sent: count(r.id),
        total_opened: count(r.opened_at),
        total_clicked: count(r.clicked_at),
        open_rate: fragment("ROUND(COUNT(?) * 100.0 / NULLIF(COUNT(*), 0), 1)", r.opened_at),
        click_rate: fragment("ROUND(COUNT(?) * 100.0 / NULLIF(COUNT(*), 0), 1)", r.clicked_at)
      }
    )
    |> Repo.all()
  end

  ## Private

  defp calculate_send_time(due_date, offset_days, client_timezone) do
    target_date = Date.add(due_date, offset_days)
    target_date = skip_weekends(target_date)

    hour = Enum.random(9..10)
    minute = Enum.random(0..59)

    {:ok, naive} = NaiveDateTime.new(target_date, Time.new!(hour, minute, 0))

    case DateTime.from_naive(naive, client_timezone) do
      {:ok, dt} -> DateTime.shift_zone!(dt, "UTC")
      {:ambiguous, dt, _} -> DateTime.shift_zone!(dt, "UTC")
      {:gap, _, dt} -> DateTime.shift_zone!(dt, "UTC")
      {:error, _} ->
        # Timezone not found, fall back to UTC
        {:ok, dt} = DateTime.from_naive(naive, "UTC")
        dt
    end
  end

  defp skip_weekends(date) do
    case Date.day_of_week(date) do
      6 -> Date.add(date, 2)
      7 -> Date.add(date, 1)
      _ -> date
    end
  end
end
