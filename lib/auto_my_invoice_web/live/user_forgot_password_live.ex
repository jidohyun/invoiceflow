defmodule AutoMyInvoiceWeb.UserForgotPasswordLive do
  use AutoMyInvoiceWeb, :live_view

  alias AutoMyInvoice.Accounts

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
          <div class="flex justify-center mb-4">
            <div class="w-12 h-12 rounded-full bg-primary/10 flex items-center justify-center">
              <span class="material-icons text-primary text-2xl">lock_reset</span>
            </div>
          </div>
          <h2 class="text-2xl font-bold font-display mb-2">비밀번호 재설정</h2>
          <p class="text-base-content/60 text-sm">
            가입하신 이메일을 입력하시면 재설정 링크를 보내드립니다.
          </p>
        </div>

        <.form for={@form} id="reset_password_form" phx-submit="send_instructions" class="space-y-4">
          <div>
            <label for="email" class="block text-sm font-medium mb-1">이메일 주소</label>
            <input
              type="email"
              name="user[email]"
              id="email"
              required
              placeholder="you@example.com"
              class="input input-bordered w-full"
              autocomplete="email"
            />
          </div>

          <button type="submit" class="btn btn-primary w-full" phx-disable-with="전송 중...">
            재설정 링크 받기
          </button>
        </.form>

        <div class="text-center mt-6">
          <.link navigate={~p"/users/log_in"} class="text-sm text-base-content/60 hover:text-primary">
            로그인 화면으로
          </.link>
        </div>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "비밀번호 재설정")
     |> assign(form: to_form(%{}, as: "user"))}
  end

  def handle_event("send_instructions", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_user_reset_password_instructions(
        user,
        &url(~p"/users/reset_password/#{&1}")
      )
    end

    # Always show the same confirmation so we don't leak which emails are
    # registered.
    {:noreply,
     socket
     |> put_flash(
       :info,
       "이메일이 등록되어 있다면 잠시 후 재설정 안내 메일이 도착합니다. 받은편지함을 확인해 주세요."
     )
     |> push_navigate(to: ~p"/users/log_in")}
  end
end
