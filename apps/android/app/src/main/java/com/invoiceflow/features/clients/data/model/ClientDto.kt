package com.invoiceflow.features.clients.data.model

import com.squareup.moshi.JsonClass

@JsonClass(generateAdapter = true)
data class ClientDto(
    val id: String,
    val name: String,
    val email: String,
    val phone: String?,
    val company: String?,
)
