package com.invoiceflow.core.data

import com.invoiceflow.features.invoices.data.model.InvoiceDto
import com.invoiceflow.features.clients.data.model.ClientDto

object MockData {
    val invoices = listOf(
        InvoiceDto(
            id = "1",
            number = "INV-2026-001",
            status = "paid",
            amount = 1500000.0,
            currency = "KRW",
            dueDate = "2026-03-15",
            clientName = "주식회사 테크스타",
            insertedAt = "2026-03-01",
        ),
        InvoiceDto(
            id = "2",
            number = "INV-2026-002",
            status = "sent",
            amount = 850000.0,
            currency = "KRW",
            dueDate = "2026-03-20",
            clientName = "디자인랩 코리아",
            insertedAt = "2026-03-05",
        ),
        InvoiceDto(
            id = "3",
            number = "INV-2026-003",
            status = "overdue",
            amount = 3200000.0,
            currency = "KRW",
            dueDate = "2026-02-28",
            clientName = "스타트업 벤처스",
            insertedAt = "2026-02-10",
        ),
        InvoiceDto(
            id = "4",
            number = "INV-2026-004",
            status = "partially_paid",
            amount = 2100000.0,
            currency = "KRW",
            dueDate = "2026-03-25",
            clientName = "글로벌 이커머스",
            insertedAt = "2026-03-08",
        ),
        InvoiceDto(
            id = "5",
            number = "INV-2026-005",
            status = "draft",
            amount = 500000.0,
            currency = "KRW",
            dueDate = "2026-04-01",
            clientName = "크리에이티브 스튜디오",
            insertedAt = "2026-03-10",
        ),
    )

    val clients = listOf(
        ClientDto(id = "1", name = "주식회사 테크스타", email = "billing@techstar.co.kr", phone = "02-1234-5678", company = "테크스타"),
        ClientDto(id = "2", name = "디자인랩 코리아", email = "contact@designlab.kr", phone = "02-9876-5432", company = "디자인랩"),
        ClientDto(id = "3", name = "스타트업 벤처스", email = "ceo@startupventures.io", phone = null, company = "스타트업 벤처스"),
    )
}
