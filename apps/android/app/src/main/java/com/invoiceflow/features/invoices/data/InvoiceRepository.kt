package com.invoiceflow.features.invoices.data

import com.invoiceflow.core.network.ApiService
import com.invoiceflow.features.invoices.data.model.InvoiceDto
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class InvoiceRepository @Inject constructor(
    private val apiService: ApiService,
) {
    suspend fun getInvoices(): List<InvoiceDto> = apiService.getInvoices()

    suspend fun getInvoice(id: String): InvoiceDto = apiService.getInvoice(id)
}
