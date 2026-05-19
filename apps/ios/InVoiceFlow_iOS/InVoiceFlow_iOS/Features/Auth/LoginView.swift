import SwiftUI

struct LoginView: View {
    @Environment(AuthViewModel.self) private var auth

    @State private var email = ""
    @State private var password = ""
    @State private var showRegister = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("다시 오신 걸 환영합니다")
                        .font(.title2.bold())
                    Text("로그인하여 송장을 관리하세요")
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
                            .textContentType(.password)
                    }

                    if let error = auth.error {
                        Text(error).foregroundStyle(.red).font(.footnote)
                    }

                    Button {
                        Task { await auth.login(email: email, password: password) }
                    } label: {
                        if auth.isSubmitting {
                            ProgressView().tint(.white).frame(maxWidth: .infinity)
                        } else {
                            Text("로그인").frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(auth.isSubmitting || email.isEmpty || password.isEmpty)

                    Button("계정이 없으신가요? 회원가입") {
                        showRegister = true
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tint)
                    .frame(maxWidth: .infinity)
                }
                .padding(24)
            }
            .navigationDestination(isPresented: $showRegister) {
                RegisterView()
            }
        }
    }
}

struct LabeledField<Content: View>: View {
    let label: String
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.footnote).foregroundStyle(.secondary)
            content()
                .textFieldStyle(.roundedBorder)
        }
    }
}
