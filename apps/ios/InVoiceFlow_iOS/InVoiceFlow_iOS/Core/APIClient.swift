import Foundation

enum APIError: LocalizedError {
    case http(status: Int, body: String)
    case decoding(Error)
    case transport(Error)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .http(let s, let b): return "서버 오류 \(s) — \(b)"
        case .decoding: return "응답을 해석하지 못했습니다."
        case .transport(let e): return "네트워크 오류: \(e.localizedDescription)"
        case .unauthorized: return "로그인이 필요합니다."
        }
    }
}

/// AMI-88 (iOS): minimal async/await HTTP client wired to the
/// /api/v1 surface. Token is read from Keychain on every request; the
/// session-expired (401) case bubbles up as [.unauthorized] so
/// `AuthViewModel` can decide whether to log the user out.
@MainActor
final class APIClient {
    static let shared = APIClient()

    private let session = URLSession.shared
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    /// Override at app start if needed (UserDefaults / build setting).
    /// Default points at the local Phoenix dev server.
    var baseURL = URL(string: "http://localhost:4000/api/v1")!

    private init() {
        decoder = JSONDecoder()
        encoder = JSONEncoder()
    }

    // MARK: - Public surface

    func login(email: String, password: String) async throws -> AuthData {
        let req = try makeRequest(
            path: "/auth/login",
            method: "POST",
            body: LoginRequest(email: email, password: password),
            requiresAuth: false
        )
        return try await send(req, as: APIResponse<AuthData>.self).data
    }

    func register(email: String, password: String) async throws -> AuthData {
        let req = try makeRequest(
            path: "/auth/register",
            method: "POST",
            body: LoginRequest(email: email, password: password),
            requiresAuth: false
        )
        return try await send(req, as: APIResponse<AuthData>.self).data
    }

    func dashboard() async throws -> KpiSummaryDTO {
        let req = try makeRequest(path: "/dashboard", method: "GET")
        return try await send(req, as: APIResponse<KpiSummaryDTO>.self).data
    }

    func recentInvoices(limit: Int = 5) async throws -> [InvoiceDTO] {
        let req = try makeRequest(path: "/dashboard/recent?limit=\(limit)", method: "GET")
        return try await send(req, as: APIResponse<[InvoiceDTO]>.self).data
    }

    // MARK: - Private

    private func makeRequest<B: Encodable>(
        path: String,
        method: String,
        body: B,
        requiresAuth: Bool = true
    ) throws -> URLRequest {
        var req = baseRequest(path: path, method: method, requiresAuth: requiresAuth)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try encoder.encode(body)
        return req
    }

    private func makeRequest(
        path: String,
        method: String,
        requiresAuth: Bool = true
    ) throws -> URLRequest {
        return baseRequest(path: path, method: method, requiresAuth: requiresAuth)
    }

    private func baseRequest(path: String, method: String, requiresAuth: Bool) -> URLRequest {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if requiresAuth, let token = KeychainStore.shared.token() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return req
    }

    private func send<T: Decodable>(_ req: URLRequest, as: T.Type) async throws -> T {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw APIError.transport(error)
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(status) else {
            throw APIError.http(status: status, body: String(data: data, encoding: .utf8) ?? "")
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }
}
