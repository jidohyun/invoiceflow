package com.invoiceflow.core.data

import com.invoiceflow.features.clients.data.model.ClientDto
import com.invoiceflow.features.invoices.data.model.InvoiceDto
import com.invoiceflow.features.invoices.data.model.InvoiceItemDto

/**
 * Mock data used for Compose previews and the offline empty-state path.
 * Field names match `JsonHelpers.render_invoice/1` on the backend.
 */
object MockData {
    val clients = listOf(
        ClientDto(id = "1", name = "주식회사 테크스타", email = "billing@techstar.co.kr", phone = "02-1234-5678", company = "테크스타"),
        ClientDto(id = "2", name = "디자인랩 코리아", email = "contact@designlab.kr", phone = "02-9876-5432", company = "디자인랩"),
        ClientDto(id = "3", name = "스타트업 벤처스", email = "ceo@startupventures.io", phone = null, company = "스타트업 벤처스"),
    )

    val invoices = listOf(
        InvoiceDto(
            id = "1", invoiceNumber = "INV-2026-001", status = "paid",
            amount = "1650000", paidAmount = "1650000", currency = "KRW",
            dueDate = "2026-03-15", sentAt = "2026-03-01T00:00:00Z", paidAt = "2026-03-10T00:00:00Z",
            notes = null, clientId = clients[0].id, client = clients[0],
            items = listOf(InvoiceItemDto(description = "UI 디자인", quantity = "1", unitPrice = "1500000")),
            insertedAt = "2026-03-01T00:00:00Z", updatedAt = "2026-03-10T00:00:00Z",
        ),
        InvoiceDto(
            id = "2", invoiceNumber = "INV-2026-002", status = "sent",
            amount = "935000", paidAmount = "0", currency = "KRW",
            dueDate = "2026-03-20", sentAt = "2026-03-05T00:00:00Z", paidAt = null,
            notes = "2차 작업분", clientId = clients[1].id, client = clients[1],
            items = listOf(InvoiceItemDto(description = "브랜딩 작업", quantity = "1", unitPrice = "850000")),
            insertedAt = "2026-03-05T00:00:00Z", updatedAt = "2026-03-05T00:00:00Z",
        ),
        InvoiceDto(
            id = "3", invoiceNumber = "INV-2026-003", status = "overdue",
            amount = "3520000", paidAmount = "0", currency = "KRW",
            dueDate = "2026-02-28", sentAt = "2026-02-10T00:00:00Z", paidAt = null,
            notes = null, clientId = clients[2].id, client = clients[2],
            items = listOf(InvoiceItemDto(description = "개발 컨설팅", quantity = "4", unitPrice = "800000")),
            insertedAt = "2026-02-10T00:00:00Z", updatedAt = "2026-02-10T00:00:00Z",
        ),
        InvoiceDto(
            id = "4", invoiceNumber = "INV-2026-004", status = "partially_paid",
            amount = "2310000", paidAmount = "1000000", currency = "KRW",
            dueDate = "2026-03-25", sentAt = "2026-03-08T00:00:00Z", paidAt = null,
            notes = null, clientId = clients[0].id, client = clients[0],
            items = listOf(InvoiceItemDto(description = "앱 개발", quantity = "1", unitPrice = "2100000")),
            insertedAt = "2026-03-08T00:00:00Z", updatedAt = "2026-03-08T00:00:00Z",
        ),
        InvoiceDto(
            id = "5", invoiceNumber = "INV-2026-005", status = "draft",
            amount = "550000", paidAmount = "0", currency = "KRW",
            dueDate = "2026-04-01", sentAt = null, paidAt = null,
            notes = "초안", clientId = clients[1].id, client = clients[1],
            items = listOf(InvoiceItemDto(description = "로고 디자인", quantity = "1", unitPrice = "500000")),
            insertedAt = "2026-03-10T00:00:00Z", updatedAt = "2026-03-10T00:00:00Z",
        ),
    )
}
