package com.invoiceflow.core.network

import com.invoiceflow.features.auth.data.model.AuthData
import com.invoiceflow.features.auth.data.model.LoginRequest
import com.invoiceflow.features.auth.data.model.RefreshTokenRequest
import com.invoiceflow.features.auth.data.model.RegisterRequest
import com.invoiceflow.features.clients.data.model.ClientDto
import com.invoiceflow.features.clients.data.model.ClientRequest
import com.invoiceflow.features.dashboard.data.model.KpiSummaryDto
import com.invoiceflow.features.invoices.data.model.InvoiceCreateRequest
import com.invoiceflow.features.invoices.data.model.InvoiceDto
import com.invoiceflow.features.invoices.data.model.InvoiceUpdateRequest
import com.invoiceflow.features.invoices.data.model.MarkPaidRequest
import com.invoiceflow.features.invoices.data.model.SendInvoiceRequest
import com.invoiceflow.features.settings.data.model.UserSettingsDto
import com.invoiceflow.features.settings.data.model.UserSettingsRequest
import com.invoiceflow.features.upload.data.model.ExtractionJobDto
import okhttp3.MultipartBody
import retrofit2.http.Body
import retrofit2.http.DELETE
import retrofit2.http.GET
import retrofit2.http.Multipart
import retrofit2.http.POST
import retrofit2.http.PUT
import retrofit2.http.Part
import retrofit2.http.Path
import retrofit2.http.Query

interface ApiService {

    // Auth
    @POST("auth/login")
    suspend fun login(@Body request: LoginRequest): ApiResponse<AuthData>

    @POST("auth/register")
    suspend fun register(@Body request: RegisterRequest): ApiResponse<AuthData>

    @POST("auth/refresh")
    suspend fun refreshToken(@Body request: RefreshTokenRequest): ApiResponse<AuthData>

    @DELETE("auth/logout")
    suspend fun logout()

    // Dashboard — backend route is /api/v1/dashboard (DashboardController :index).
    @GET("dashboard")
    suspend fun getDashboardKpi(): ApiResponse<KpiSummaryDto>

    @GET("dashboard/recent")
    suspend fun getRecentInvoices(@Query("limit") limit: Int = 5): ApiResponse<List<InvoiceDto>>

    // Invoices
    @GET("invoices")
    suspend fun getInvoices(
        @Query("page") page: Int = 1,
        @Query("limit") limit: Int = 20,
        @Query("status") status: String? = null,
        @Query("client_id") clientId: String? = null,
        @Query("search") search: String? = null,
    ): PaginatedApiResponse<InvoiceDto>

    @GET("invoices/{id}")
    suspend fun getInvoice(@Path("id") id: String): ApiResponse<InvoiceDto>

    @POST("invoices")
    suspend fun createInvoice(@Body request: InvoiceCreateRequest): ApiResponse<InvoiceDto>

    @PUT("invoices/{id}")
    suspend fun updateInvoice(@Path("id") id: String, @Body request: InvoiceUpdateRequest): ApiResponse<InvoiceDto>

    @DELETE("invoices/{id}")
    suspend fun deleteInvoice(@Path("id") id: String)

    @POST("invoices/{id}/send")
    suspend fun sendInvoice(@Path("id") id: String, @Body request: SendInvoiceRequest = SendInvoiceRequest()): ApiResponse<InvoiceDto>

    @POST("invoices/{id}/mark_paid")
    suspend fun markInvoicePaid(@Path("id") id: String, @Body request: MarkPaidRequest = MarkPaidRequest()): ApiResponse<InvoiceDto>

    // Clients
    @GET("clients")
    suspend fun getClients(
        @Query("page") page: Int = 1,
        @Query("limit") limit: Int = 20,
        @Query("q") query: String? = null,
    ): PaginatedApiResponse<ClientDto>

    @GET("clients/{id}")
    suspend fun getClient(@Path("id") id: String): ApiResponse<ClientDto>

    @POST("clients")
    suspend fun createClient(@Body request: ClientRequest): ApiResponse<ClientDto>

    @PUT("clients/{id}")
    suspend fun updateClient(@Path("id") id: String, @Body request: ClientRequest): ApiResponse<ClientDto>

    @DELETE("clients/{id}")
    suspend fun deleteClient(@Path("id") id: String)

    // Upload & Extraction
    @Multipart
    @POST("upload")
    suspend fun uploadFile(@Part file: MultipartBody.Part): ApiResponse<ExtractionJobDto>

    @GET("upload/{jobId}")
    suspend fun getExtractionJob(@Path("jobId") jobId: String): ApiResponse<ExtractionJobDto>

    // Settings
    @GET("settings")
    suspend fun getSettings(): ApiResponse<UserSettingsDto>

    @PUT("settings")
    suspend fun updateSettings(@Body request: UserSettingsRequest): ApiResponse<UserSettingsDto>
}
