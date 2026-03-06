defmodule InvoiceFlowWeb.UserForgotPasswordLive do
  use InvoiceFlowWeb, :live_view

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
          <h2 class="text-2xl font-bold font-display mb-2">Reset your password</h2>
          <p class="text-base-content/60 text-sm">
            Password reset functionality is coming soon.
          </p>
        </div>

        <div class="bg-info/10 border border-info/20 rounded-lg p-4 mb-6">
          <div class="flex gap-3">
            <span class="material-icons text-info text-xl shrink-0 mt-0.5">info</span>
            <p class="text-sm text-base-content/70">
              In the meantime, please contact support if you need to reset your password.
            </p>
          </div>
        </div>

        <.link navigate={~p"/users/log_in"} class="btn btn-outline w-full">
          Back to sign in
        </.link>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end
