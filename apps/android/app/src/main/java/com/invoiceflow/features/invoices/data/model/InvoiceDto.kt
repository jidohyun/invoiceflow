package com.invoiceflow.features.invoices.data.model

import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass
import com.invoiceflow.features.clients.data.model.ClientDto

/**
 * Matches AutoMyInvoiceWeb.Api.JsonHelpers.render_invoice/1.
 *
 * Money fields (`amount`, `paidAmount`, item `unitPrice`) come over as
 * JSON strings because Phoenix renders Decimal as strings to preserve
 * precision — the UI converts to BigDecimal when needed.
 */
@JsonClass(generateAdapter = true)
data class InvoiceDto(
    val id: String,
    @Json(name = "invoice_number") val invoiceNumber: String,
    val status: String,
    val amount: String,
    @Json(name = "paid_amount") val paidAmount: String,
    val currency: String,
    @Json(name = "due_date") val dueDate: String?,
    @Json(name = "sent_at") val sentAt: String?,
    @Json(name = "paid_at") val paidAt: String?,
    val notes: String?,
    @Json(name = "client_id") val clientId: String?,
    val client: ClientDto?,
    val items: List<InvoiceItemDto> = emptyList(),
    @Json(name = "inserted_at") val insertedAt: String,
    @Json(name = "updated_at") val updatedAt: String,
)

@JsonClass(generateAdapter = true)
data class InvoiceItemDto(
    val id: String? = null,
    val description: String,
    val quantity: String,
    @Json(name = "unit_price") val unitPrice: String,
    val position: Int? = null,
)

@JsonClass(generateAdapter = true)
data class InvoiceCreateRequest(
    @Json(name = "client_id") val clientId: String,
    val amount: String,
    val currency: String = "KRW",
    @Json(name = "due_date") val dueDate: String,
    val notes: String? = null,
    val items: List<InvoiceItemRequest> = emptyList(),
)

@JsonClass(generateAdapter = true)
data class InvoiceItemRequest(
    val description: String,
    val quantity: String = "1",
    @Json(name = "unit_price") val unitPrice: String,
)

@JsonClass(generateAdapter = true)
data class InvoiceUpdateRequest(
    @Json(name = "client_id") val clientId: String? = null,
    val amount: String? = null,
    val currency: String? = null,
    @Json(name = "due_date") val dueDate: String? = null,
    val notes: String? = null,
)

@JsonClass(generateAdapter = true)
data class SendInvoiceRequest(val message: String? = null)

@JsonClass(generateAdapter = true)
data class MarkPaidRequest(
    @Json(name = "paid_at") val paidAt: String? = null,
    @Json(name = "payment_method") val paymentMethod: String? = null,
    @Json(name = "payment_reference") val paymentReference: String? = null,
)
