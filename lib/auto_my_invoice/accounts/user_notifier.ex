defmodule AutoMyInvoice.Accounts.UserNotifier do
  @moduledoc "Account-related transactional emails (e.g. password reset)."

  import Swoosh.Email

  alias AutoMyInvoice.Mailer

  @from_name "AutoMyInvoice"

  @spec deliver_reset_password_instructions(map(), String.t()) ::
          {:ok, Swoosh.Email.t()} | {:error, term()}
  def deliver_reset_password_instructions(user, url) do
    new()
    |> to({user.email, user.email})
    |> from({@from_name, from_email()})
    |> subject("[AutoMyInvoice] 비밀번호 재설정 안내")
    |> text_body(reset_text(url))
    |> html_body(reset_html(url))
    |> Mailer.deliver()
  end

  defp reset_text(url) do
    """
    안녕하세요,

    AutoMyInvoice 계정의 비밀번호 재설정 요청을 받았습니다.
    아래 링크를 24시간 이내에 클릭해 새 비밀번호를 설정하세요.

    #{url}

    본인이 요청한 것이 아니라면 이 메일을 무시하세요. 비밀번호는 변경되지 않습니다.
    """
  end

  defp reset_html(url) do
    """
    <p>안녕하세요,</p>
    <p>AutoMyInvoice 계정의 비밀번호 재설정 요청을 받았습니다.
    아래 버튼을 <strong>24시간 이내</strong>에 클릭해 새 비밀번호를 설정하세요.</p>
    <p><a href="#{url}" style="display:inline-block;padding:12px 24px;background:#6d28d9;color:#fff;text-decoration:none;border-radius:6px;">비밀번호 재설정</a></p>
    <p>버튼이 동작하지 않으면 아래 링크를 브라우저에 붙여넣으세요:</p>
    <p><code>#{url}</code></p>
    <p>본인이 요청한 것이 아니라면 이 메일을 무시하세요. 비밀번호는 변경되지 않습니다.</p>
    """
  end

  # AMI-16: From address comes from MAILER_FROM env var via runtime.exs.
  defp from_email do
    Application.get_env(:auto_my_invoice, :sender_email, "noreply@automyinvoice.local")
  end
end
