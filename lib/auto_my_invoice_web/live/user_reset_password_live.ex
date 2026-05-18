defmodule AutoMyInvoiceWeb.UserResetPasswordLive do
  use AutoMyInvoiceWeb, :live_view

  alias AutoMyInvoice.Accounts

  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-base-200 px-4">
      <div class="w-full max-w-md bg-base-100 rounded-xl shadow-xl border border-base-300 p-8">
        <div class="text-center mb-8">
          <h2 class="text-2xl font-bold font-display mb-2">새 비밀번호 설정</h2>
          <%= if @user do %>
            <p class="text-base-content/60 text-sm">
              <strong>{@user.email}</strong> 계정의 새 비밀번호를 입력하세요.
            </p>
          <% else %>
            <p class="text-error text-sm">
              링크가 만료되었거나 잘못된 링크입니다. 다시 요청해 주세요.
            </p>
          <% end %>
        </div>

        <%= if @user do %>
          <.form
            for={@form}
            id="reset_password_form"
            phx-submit="reset_password"
            phx-change="validate"
            class="space-y-4"
          >
            <div>
              <label for="password" class="block text-sm font-medium mb-1">새 비밀번호</label>
              <input
                type="password"
                name="user[password]"
                id="password"
                required
                minlength="8"
                maxlength="72"
                placeholder="8자 이상"
                class="input input-bordered w-full"
                autocomplete="new-password"
              />
              <p :for={msg <- @form[:password].errors} class="text-error text-xs mt-1">
                {translate_error(msg)}
              </p>
            </div>

            <div>
              <label for="password_confirmation" class="block text-sm font-medium mb-1">
                새 비밀번호 확인
              </label>
              <input
                type="password"
                name="user[password_confirmation]"
                id="password_confirmation"
                required
                placeholder="새 비밀번호 다시 입력"
                class="input input-bordered w-full"
                autocomplete="new-password"
              />
            </div>

            <button type="submit" class="btn btn-primary w-full" phx-disable-with="저장 중...">
              비밀번호 변경
            </button>
          </.form>
        <% else %>
          <.link navigate={~p"/users/reset_password"} class="btn btn-outline w-full">
            재설정 링크 다시 요청
          </.link>
        <% end %>
      </div>
    </div>
    """
  end

  def mount(params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "새 비밀번호 설정")
      |> assign_user_and_form(params)

    {:ok, socket, temporary_assigns: [form: nil]}
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      socket.assigns.user
      |> AutoMyInvoice.Accounts.User.password_changeset(user_params, hash_password: false)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset, as: "user"))}
  end

  def handle_event("reset_password", %{"user" => user_params}, socket) do
    case Accounts.reset_user_password(socket.assigns.user, user_params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "비밀번호가 변경되었습니다. 새 비밀번호로 로그인해 주세요.")
         |> push_navigate(to: ~p"/users/log_in")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: "user"))}
    end
  end

  defp assign_user_and_form(socket, %{"token" => token}) do
    if user = Accounts.get_user_by_reset_password_token(token) do
      socket
      |> assign(:user, user)
      |> assign(:token, token)
      |> assign(
        :form,
        to_form(AutoMyInvoice.Accounts.User.password_changeset(user, %{}), as: "user")
      )
    else
      socket
      |> assign(:user, nil)
      |> assign(:token, nil)
      |> assign(:form, to_form(%{}, as: "user"))
    end
  end

end
