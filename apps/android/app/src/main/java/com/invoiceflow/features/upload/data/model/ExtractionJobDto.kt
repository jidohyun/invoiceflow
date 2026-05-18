package com.invoiceflow.features.upload.data.model

import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass
import com.invoiceflow.features.invoices.data.model.InvoiceItemDto

@JsonClass(generateAdapter = true)
data class ExtractionJobDto(
    val id: String,
    val status: String, // pending, processing, completed, failed
    @Json(name = "file_name") val fileName: String,
    @Json(name = "file_size") val fileSize: Long? = null,
    @Json(name = "extracted_data") val extractedData: ExtractedDataDto? = null,
    @Json(name = "error_message") val errorMessage: String? = null,
    @Json(name = "invoice_id") val invoiceId: String? = null,
    @Json(name = "inserted_at") val insertedAt: String,
    @Json(name = "updated_at") val updatedAt: String,
)

@JsonClass(generateAdapter = true)
data class ExtractedDataDto(
    @Json(name = "invoice_number") val invoiceNumber: String? = null,
    @Json(name = "vendor_name") val vendorName: String? = null,
    @Json(name = "issued_at") val issuedAt: String? = null,
    @Json(name = "due_at") val dueAt: String? = null,
    val total: Long? = null,
    val currency: String? = null,
    @Json(name = "line_items") val lineItems: List<InvoiceItemDto> = emptyList(),
)
