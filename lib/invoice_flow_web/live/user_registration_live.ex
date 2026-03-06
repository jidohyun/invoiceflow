defmodule InvoiceFlowWeb.UserRegistrationLive do
  use InvoiceFlowWeb, :live_view

  alias InvoiceFlow.Accounts
  alias InvoiceFlow.Accounts.User

  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-base-200 px-4 relative overflow-hidden">
      <div class="absolute inset-0 z-0 pointer-events-none overflow-hidden">
        <div class="absolute top-[-10%] left-[-10%] w-[40%] h-[40%] bg-primary/10 rounded-full blur-3xl">
        </div>
        <div class="absolute bottom-[-10%] right-[-10%] w-[50%] h-[50%] bg-secondary/10 rounded-full blur-3xl">
        </div>
      </div>

      <div class="w-full max-w-md bg-base-100 rounded-xl shadow-xl border border-base-300 p-8 relative z-10">
        <div class="text-center mb-8">
          <h2 class="text-2xl font-bold font-display mb-2">Join InvoiceFlow</h2>
          <p class="text-base-content/60 text-sm">
            Automate your invoice reminders and get paid faster.
          </p>
        </div>

        <div class="space-y-3 mb-6">
          <a
            href={~p"/auth/google"}
            class="btn btn-outline w-full gap-3 font-medium normal-case"
          >
            <svg class="w-5 h-5" viewBox="0 0 24 24">
              <path
                fill="#4285F4"
                d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92a5.06 5.06 0 0 1-2.2 3.32v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.1z"
              />
              <path
                fill="#34A853"
                d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
              />
              <path
                fill="#FBBC05"
                d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"
              />
              <path
                fill="#EA4335"
                d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"
              />
            </svg>
            Sign up with Google
          </a>

          <button class="btn w-full gap-3 font-medium normal-case bg-[#24292F] hover:bg-[#24292F]/90 text-white border-transparent">
            <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
              <path
                fill-rule="evenodd"
                clip-rule="evenodd"
                d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z"
              />
            </svg>
            Sign up with GitHub
          </button>
        </div>

        <div class="flex items-center gap-4 py-2 mb-6">
          <div class="flex-grow border-t border-base-300"></div>
          <span class="text-base-content/40 text-sm shrink-0">or continue with email</span>
          <div class="flex-grow border-t border-base-300"></div>
        </div>

        <.form
          for={@form}
          id="registration_form"
          phx-submit="save"
          phx-change="validate"
          phx-trigger-action={@trigger_submit}
          action={~p"/users/log_in"}
          method="post"
          class="space-y-4"
        >
          <div class="form-control">
            <label class="block text-sm font-medium mb-1" for="user_email">
              Email address
            </label>
            <input
              type="email"
              name="user[email]"
              id="user_email"
              value={@form[:email].value}
              class={["input input-bordered w-full", @form[:email].errors != [] && "input-error"]}
              placeholder="you@example.com"
              autocomplete="email"
              phx-debounce="blur"
              required
            />
            <p :for={{msg, _opts} <- @form[:email].errors} class="text-error text-sm mt-1">
              {msg}
            </p>
          </div>

          <div class="form-control">
            <label class="block text-sm font-medium mb-1" for="user_password">
              Password
            </label>
            <input
              type="password"
              name="user[password]"
              id="user_password"
              value={@form[:password].value}
              class={[
                "input input-bordered w-full",
                @form[:password].errors != [] && "input-error"
              ]}
              placeholder="At least 8 characters"
              autocomplete="new-password"
              phx-debounce="blur"
              required
            />
            <p :for={{msg, _opts} <- @form[:password].errors} class="text-error text-sm mt-1">
              {msg}
            </p>
          </div>

          <div class="form-control">
            <label class="block text-sm font-medium mb-1" for="user_company_name">
              Company name <span class="text-base-content/40">(optional)</span>
            </label>
            <input
              type="text"
              name="user[company_name]"
              id="user_company_name"
              value={@form[:company_name].value}
              class="input input-bordered w-full"
              placeholder="Your company"
            />
          </div>

          <div class="pt-2">
            <button
              type="submit"
              phx-disable-with="Creating account..."
              class="btn btn-primary w-full"
            >
              Create account
            </button>
          </div>
        </.form>

        <p class="mt-6 text-center text-sm text-base-content/60">
          Already have an account?
          <.link navigate={~p"/users/log_in"} class="font-medium text-primary hover:text-primary/80">
            Sign in
          </.link>
        </p>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_registration(%User{})

    socket =
      socket
      |> assign(trigger_submit: false, check_errors: false)
      |> assign_form(changeset)

    {:ok, socket, temporary_assigns: [form: nil]}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        changeset = Accounts.change_user_registration(user)

        {:noreply,
         socket
         |> assign(trigger_submit: true)
         |> assign_form(changeset)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign(check_errors: true)
         |> assign_form(changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_registration(%User{}, user_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")

    if changeset.valid? do
      assign(socket, form: form, check_errors: false)
    else
      assign(socket, form: form)
    end
  end
end
