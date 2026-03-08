package com.invoiceflow.features.auth.data.model

import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass

@JsonClass(generateAdapter = true)
data class LoginRequest(
    val email: String,
    val password: String,
)

@JsonClass(generateAdapter = true)
data class RegisterRequest(
    val email: String,
    val password: String,
    @Json(name = "password_confirmation") val passwordConfirmation: String,
    val name: String,
)

@JsonClass(generateAdapter = true)
data class LoginResponse(
    val token: String,
    val user: UserDto,
)

@JsonClass(generateAdapter = true)
data class UserDto(
    val id: String,
    val email: String,
    val name: String,
)
