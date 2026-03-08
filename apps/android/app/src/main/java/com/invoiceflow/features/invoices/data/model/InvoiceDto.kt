package com.invoiceflow.features.invoices.data.model

import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass

@JsonClass(generateAdapter = true)
data class InvoiceDto(
    val id: String,
    val number: String,
    val status: String,
    val amount: Double,
    val currency: String,
    @Json(name = "due_date") val dueDate: String,
    @Json(name = "client_name") val clientName: String,
    @Json(name = "inserted_at") val insertedAt: String,
)
