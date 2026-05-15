defmodule AutoMyInvoice.Billing do
  @moduledoc "구독 플랜 및 빌링 관리 Context"

  import Ecto.Query
  alias AutoMyInvoice.Repo
  alias AutoMyInvoice.Billing.Subscription
  alias AutoMyInvoice.Accounts

  ## 구독 활성화 (Webhook)

  @spec activate_subscription(map()) :: :ok | {:error, term()}
  def activate_subscription(data) do
    user_id = get_in(data, ["custom_data", "user_id"])
    plan = get_in(data, ["custom_data", "plan"])

    if is_nil(user_id) or is_nil(plan) do
      {:error, :missing_custom_data}
    else
      activate_subscription_impl(user_id, data, plan)
    end
  end

  defp activate_subscription_impl(user_id, data, plan) do
    with {:ok, _sub} <- create_or_update_subscription(user_id, data, plan),
         user <- Accounts.get_user!(user_id),
         {:ok, _user} <-
           Accounts.update_profile(user, %{
             plan: plan,
             paddle_customer_id: data["customer_id"]
           }) do
      :ok
    end
  end

  ## 구독 취소 (Webhook)

  @spec cancel_subscription(map()) :: :ok
  def cancel_subscription(data) do
    sub_id = data["id"]

    case get_subscription_by_paddle_id(sub_id) do
      %Subscription{} = sub ->
        sub
        |> Subscription.changeset(%{
          status: "cancelled",
          cancelled_at: DateTime.truncate(DateTime.utc_now(), :second)
        })
        |> Repo.update()

        :ok

      nil ->
        :ok
    end
  end

  ## 구독 업데이트 (Webhook)

  @spec update_subscription(map()) :: :ok
  def update_subscription(data) do
    sub_id = data["id"]

    case get_subscription_by_paddle_id(sub_id) do
      %Subscription{} = sub ->
        sub
        |> Subscription.changeset(%{
          status: data["status"],
          current_period_start:
            parse_datetime(get_in(data, ["current_billing_period", "starts_at"])),
          current_period_end: parse_datetime(get_in(data, ["current_billing_period", "ends_at"]))
        })
        |> Repo.update()

        :ok

      nil ->
        :ok
    end
  end

  ## 조회

  @spec get_active_subscription(binary()) :: Subscription.t() | nil
  def get_active_subscription(user_id) do
    from(s in Subscription,
      where: s.user_id == ^user_id,
      where: s.status == "active",
      order_by: [desc: s.inserted_at],
      limit: 1
    )
    |> Repo.one()
  end

  ## 플랜 정보 및 사용량

  @plans %{
    "free" => %{name: "Free", monthly_invoices: 3, price: 0},
    "starter" => %{name: "Starter", monthly_invoices: :unlimited, price: 9},
    "pro" => %{name: "Pro", monthly_invoices: :unlimited, price: 29}
  }

  @spec plans() :: map()
  def plans, do: @plans

  @spec plans_ordered() :: [{String.t(), map()}]
  def plans_ordered do
    @plans
    |> Enum.sort_by(fn {_id, plan} -> plan.price end)
  end

  @spec plan_info(String.t()) :: map()
  def plan_info(plan), do: Map.get(@plans, plan, @plans["free"])

  @spec usage_summary(binary()) :: map()
  def usage_summary(user_id) do
    user = Accounts.get_user!(user_id)
    info = plan_info(user.plan)
    count = invoice_count_this_month(user_id)
    limit = info.monthly_invoices

    %{
      plan: user.plan,
      plan_name: info.name,
      invoices_used: count,
      invoices_limit: limit,
      can_create: limit == :unlimited or count < limit,
      usage_percent: if(limit == :unlimited, do: 0, else: min(round(count / limit * 100), 100))
    }
  end

  defp invoice_count_this_month(user_id) do
    start_of_month = Date.utc_today() |> Date.beginning_of_month()

    from(i in "invoices",
      where: i.user_id == type(^user_id, :binary_id),
      where: fragment("?::date", i.inserted_at) >= ^start_of_month,
      select: count(i.id)
    )
    |> Repo.one()
  end

  ## Private

  defp create_or_update_subscription(user_id, data, plan) do
    attrs = %{
      paddle_subscription_id: data["id"],
      paddle_customer_id: data["customer_id"],
      plan: plan,
      status: "active",
      current_period_start: parse_datetime(get_in(data, ["current_billing_period", "starts_at"])),
      current_period_end: parse_datetime(get_in(data, ["current_billing_period", "ends_at"]))
    }

    case get_subscription_by_paddle_id(data["id"]) do
      nil ->
        %Subscription{user_id: user_id}
        |> Subscription.changeset(attrs)
        |> Repo.insert()

      existing ->
        existing
        |> Subscription.changeset(attrs)
        |> Repo.update()
    end
  end

  defp get_subscription_by_paddle_id(nil), do: nil

  defp get_subscription_by_paddle_id(paddle_id) do
    Repo.get_by(Subscription, paddle_subscription_id: paddle_id)
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end
end
