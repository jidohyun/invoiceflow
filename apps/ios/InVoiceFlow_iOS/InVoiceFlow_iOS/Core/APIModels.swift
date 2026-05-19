import Foundation

/// Wraps every `:data` response from the Phoenix API (see
/// `AutoMyInvoiceWeb.Api.*` controllers).
struct APIResponse<Data: Decodable>: Decodable {
    let data: Data
}

/// Backend `JsonHelpers.render_invoice/1`. Money fields are strings
/// because Phoenix renders `Decimal` as strings to preserve precision.
struct InvoiceDTO: Decodable, Identifiable, Hashable {
    let id: String
    let invoiceNumber: String
    let status: String
    let amount: String
    let paidAmount: String
    let currency: String
    let dueDate: String?
    let sentAt: String?
    let paidAt: String?
    let notes: String?
    let clientId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case invoiceNumber = "invoice_number"
        case status
        case amount
        case paidAmount = "paid_amount"
        case currency
        case dueDate = "due_date"
        case sentAt = "sent_at"
        case paidAt = "paid_at"
        case notes
        case clientId = "client_id"
    }
}

/// Backend `AutoMyInvoiceWeb.Api.DashboardController.index/2`. Outstanding
/// is already rolled up to KRW server-side (AMI-90).
struct KpiSummaryDTO: Decodable {
    let outstandingAmount: String
    let overdueCount: Int
    let collectionRate: Int
    let collectedThisMonth: String

    enum CodingKeys: String, CodingKey {
        case outstandingAmount = "outstanding_amount"
        case overdueCount = "overdue_count"
        case collectionRate = "collection_rate"
        case collectedThisMonth = "collected_this_month"
    }
}

struct AuthData: Decodable {
    let token: String
    let user: AuthUser
}

struct AuthUser: Decodable, Hashable {
    let id: String
    let email: String
}

struct LoginRequest: Encodable {
    let email: String
    let password: String
}
