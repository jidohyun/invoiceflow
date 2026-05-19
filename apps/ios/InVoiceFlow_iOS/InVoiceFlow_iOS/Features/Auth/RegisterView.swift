import SwiftUI

struct RegisterView: View {
    @Environment(AuthViewModel.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("회원가입")
                    .font(.title2.bold())
                Text("이메일과 비밀번호로 새 계정을 만듭니다")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                LabeledField(label: "이메일 주소") {
                    TextField("you@example.com", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                LabeledField(label: "비밀번호") {
                    SecureField("8자 이상", text: $password)
                        .textContentType(.newPassword)
                }

                if let error = auth.error {
                    Text(error).foregroundStyle(.red).font(.footnote)
                }

                Button {
                    Task { await auth.register(email: email, password: password) }
                } label: {
                    if auth.isSubmitting {
                        ProgressView().tint(.white).frame(maxWidth: .infinity)
                    } else {
                        Text("계정 만들기").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(auth.isSubmitting || email.isEmpty || password.count < 8)
            }
            .padding(24)
        }
        .navigationTitle("회원가입")
        .navigationBarTitleDisplayMode(.inline)
    }
}
