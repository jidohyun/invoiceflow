import Foundation
import Observation

/// AMI-88 (iOS): KPIs + recent invoices, mirrored 1:1 with the Android
/// DashboardViewModel and the web LiveDashboard.
///
/// All four KPIs come from `GET /api/v1/dashboard` (already rolled up to
/// KRW server-side); the recent-invoices list comes from
/// `GET /api/v1/dashboard/recent?limit=5`.
@MainActor
@Observable
final class DashboardViewModel {
    private(set) var kpi: KpiSummaryDTO?
    private(set) var recent: [InvoiceDTO] = []
    private(set) var isLoading = false
    private(set) var error: String?

    private let api: APIClient

    init(api: APIClient = .shared) {
        self.api = api
    }

    func refresh() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            async let kpi = api.dashboard()
            async let recent = api.recentInvoices()
            self.kpi = try await kpi
            self.recent = try await recent
        } catch let e as APIError {
            self.error = e.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
    }
}
