package com.invoiceflow.core.network

import com.invoiceflow.features.auth.data.model.LoginRequest
import com.invoiceflow.features.auth.data.model.LoginResponse
import com.invoiceflow.features.auth.data.model.RegisterRequest
import com.invoiceflow.features.clients.data.model.ClientDto
import com.invoiceflow.features.invoices.data.model.InvoiceDto
import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.POST
import retrofit2.http.Path

interface ApiService {

    // Auth
    @POST("users/login")
    suspend fun login(@Body request: LoginRequest): LoginResponse

    @POST("users/register")
    suspend fun register(@Body request: RegisterRequest): LoginResponse

    // Invoices
    @GET("invoices")
    suspend fun getInvoices(): List<InvoiceDto>

    @GET("invoices/{id}")
    suspend fun getInvoice(@Path("id") id: String): InvoiceDto

    // Clients
    @GET("clients")
    suspend fun getClients(): List<ClientDto>

    @GET("clients/{id}")
    suspend fun getClient(@Path("id") id: String): ClientDto
}
