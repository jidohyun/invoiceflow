import Foundation
import Observation

/// AMI-88 (iOS): app-wide auth state. Holds the current user, drives
/// login/register, and persists the token in Keychain so cold starts
/// stay logged in until the token expires.
@MainActor
@Observable
final class AuthViewModel {
    enum State: Equatable {
        case checking
        case loggedOut
        case loggedIn(AuthUser)
    }

    private(set) var state: State = .checking
    var isSubmitting = false
    var error: String?

    private let api: APIClient
    private let keychain: KeychainStore

    init(api: APIClient = .shared, keychain: KeychainStore = .shared) {
        self.api = api
        self.keychain = keychain
    }

    func bootstrap() {
        // We only check whether a token exists locally; the first real API
        // call will surface APIError.unauthorized if the token is stale and
        // logOut() will be triggered from there.
        if keychain.token() != nil {
            // We don't carry the user from cold storage — DashboardView's
            // first refresh either succeeds (token valid) or fails into
            // logOut(). Until then we treat us as logged-in with a stub.
            state = .loggedIn(AuthUser(id: "_pending", email: ""))
        } else {
            state = .loggedOut
        }
    }

    func login(email: String, password: String) async {
        guard !isSubmitting else { return }
        isSubmitting = true
        error = nil
        defer { isSubmitting = false }

        do {
            let data = try await api.login(email: email, password: password)
            keychain.save(token: data.token)
            state = .loggedIn(data.user)
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    func register(email: String, password: String) async {
        guard !isSubmitting else { return }
        isSubmitting = true
        error = nil
        defer { isSubmitting = false }

        do {
            let data = try await api.register(email: email, password: password)
            keychain.save(token: data.token)
            state = .loggedIn(data.user)
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    func logOut() {
        keychain.clear()
        state = .loggedOut
    }
}
