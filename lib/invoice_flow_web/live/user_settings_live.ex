defmodule InvoiceFlowWeb.UserSettingsLive do
  use InvoiceFlowWeb, :live_view

  alias InvoiceFlow.Accounts

  @timezones [
    "Asia/Seoul",
    "Asia/Tokyo",
    "Asia/Shanghai",
    "Asia/Singapore",
    "America/New_York",
    "America/Chicago",
    "America/Denver",
    "America/Los_Angeles",
    "Europe/London",
    "Europe/Paris",
    "Europe/Berlin",
    "Pacific/Auckland",
    "Australia/Sydney",
    "UTC"
  ]

  @brand_tones [
    {"Professional", "professional"},
    {"Friendly", "friendly"},
    {"Formal", "formal"}
  ]

  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto p-6">
      <h1 class="text-3xl font-bold mb-8">Settings</h1>

      <div class="card bg-base-100 shadow-xl mb-6">
        <div class="card-body">
          <h2 class="card-title text-lg mb-4">Account</h2>

          <div class="flex items-center gap-4 mb-4">
            <div class="avatar placeholder">
              <div class="bg-primary text-primary-content rounded-full w-12">
                <span class="text-xl">{String.first(@current_user.email)}</span>
              </div>
            </div>
            <div>
              <p class="font-medium">{@current_user.email}</p>
              <div class="badge badge-outline badge-sm mt-1">{String.capitalize(@current_user.plan)} plan</div>
            </div>
          </div>
        </div>
      </div>

      <div class="card bg-base-100 shadow-xl">
        <div class="card-body">
          <h2 class="card-title text-lg mb-4">Profile</h2>

          <.form
            for={@form}
            id="settings_form"
            phx-change="validate"
            phx-submit="save"
            class="space-y-4"
          >
            <div class="form-control">
              <label class="label" for="profile_company_name">
                <span class="label-text">Company name</span>
              </label>
              <input
                type="text"
                name="profile[company_name]"
                id="profile_company_name"
                value={@form[:company_name].value}
                class="input input-bordered w-full"
                placeholder="Your company"
              />
            </div>

            <div class="form-control">
              <label class="label" for="profile_timezone">
                <span class="label-text">Timezone</span>
              </label>
              <select
                name="profile[timezone]"
                id="profile_timezone"
                class="select select-bordered w-full"
              >
                <option
                  :for={tz <- @timezones}
                  value={tz}
                  selected={@form[:timezone].value == tz}
                >
                  {tz}
                </option>
              </select>
            </div>

            <div class="form-control">
              <label class="label" for="profile_brand_tone">
                <span class="label-text">Brand tone</span>
              </label>
              <select
                name="profile[brand_tone]"
                id="profile_brand_tone"
                class="select select-bordered w-full"
              >
                <option
                  :for={{label, value} <- @brand_tones}
                  value={value}
                  selected={@form[:brand_tone].value == value}
                >
                  {label}
                </option>
              </select>
              <label class="label">
                <span class="label-text-alt text-base-content/50">
                  Affects AI-generated invoice reminder tone
                </span>
              </label>
            </div>

            <div class="form-control mt-6">
              <button type="submit" phx-disable-with="Saving..." class="btn btn-primary">
                Save changes
              </button>
            </div>
          </.form>
        </div>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    changeset = Accounts.change_user_profile(user)

    socket =
      socket
      |> assign(timezones: @timezones, brand_tones: @brand_tones)
      |> assign_form(changeset)

    {:ok, socket}
  end

  def handle_event("validate", %{"profile" => profile_params}, socket) do
    changeset =
      socket.assigns.current_user
      |> Accounts.change_user_profile(profile_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"profile" => profile_params}, socket) do
    case Accounts.update_profile(socket.assigns.current_user, profile_params) do
      {:ok, user} ->
        changeset = Accounts.change_user_profile(user)

        {:noreply,
         socket
         |> assign(current_user: user)
         |> assign_form(changeset)
         |> put_flash(:info, "Settings updated successfully.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, form: to_form(changeset, as: "profile"))
  end
end
