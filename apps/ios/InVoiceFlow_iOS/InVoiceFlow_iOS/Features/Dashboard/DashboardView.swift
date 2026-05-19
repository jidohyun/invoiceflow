import SwiftUI

struct DashboardView: View {
    @Environment(AuthViewModel.self) private var auth
    @State private var vm = DashboardViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let error = vm.error {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.08), in: .rect(cornerRadius: 8))
                    }

                    KpiRow(kpi: vm.kpi, isLoading: vm.isLoading)

                    HStack {
                        Text("최근 송장").font(.headline)
                        Spacer()
                    }

                    if vm.recent.isEmpty && !vm.isLoading {
                        EmptyRecentInvoices()
                    } else {
                        ForEach(vm.recent) { invoice in
                            RecentInvoiceRow(invoice: invoice)
                        }
                    }
                }
                .padding(16)
            }
            .refreshable { await vm.refresh() }
            .task { await vm.refresh() }
            .navigationTitle("한눈에 보기")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("로그아웃") { auth.logOut() }
                }
            }
        }
    }
}

private struct KpiRow: View {
    let kpi: KpiSummaryDTO?
    let isLoading: Boolean

    typealias Boolean = Bool

    var body: some View {
        HStack(spacing: 8) {
            KpiCard(
                label: "미수금",
                value: kpi.map { formatKrw($0.outstandingAmount) } ?? placeholder,
                sub: kpi.map { "연체 \($0.overdueCount)건" } ?? ""
            )
            KpiCard(
                label: "수금률",
                value: kpi.map { "\($0.collectionRate)%" } ?? placeholder,
                sub: "이번 달"
            )
            KpiCard(
                label: "이번 달 수금",
                value: kpi.map { formatKrw($0.collectedThisMonth) } ?? placeholder,
                sub: ""
            )
        }
    }

    private var placeholder: String { isLoading ? "..." : "₩0" }
}

private struct KpiCard: View {
    let label: String
    let value: String
    let sub: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.weight(.semibold)).lineLimit(1)
            if !sub.isEmpty {
                Text(sub).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: .rect(cornerRadius: 10))
    }
}

private struct RecentInvoiceRow: View {
    let invoice: InvoiceDTO
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("#\(invoice.invoiceNumber)").font(.body.weight(.semibold))
                Text(invoice.status.uppercased()).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(invoice.currency) \(invoice.amount)").font(.body)
        }
        .padding(.vertical, 6)
    }
}

private struct EmptyRecentInvoices: View {
    var body: some View {
        VStack(spacing: 6) {
            Text("아직 송장이 없습니다").font(.body)
            Text("웹에서 첫 송장을 발행해 보세요.").font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(.regularMaterial, in: .rect(cornerRadius: 10))
    }
}

private func formatKrw(_ raw: String) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = "KRW"
    formatter.maximumFractionDigits = 0
    if let n = Decimal(string: raw) {
        return formatter.string(from: n as NSDecimalNumber) ?? "₩0"
    }
    return "₩0"
}
