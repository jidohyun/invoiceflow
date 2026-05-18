package com.invoiceflow.features.dashboard.data

import com.invoiceflow.core.network.ApiService
import com.invoiceflow.features.dashboard.data.model.KpiSummaryDto
import com.invoiceflow.features.invoices.data.model.InvoiceDto
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class DashboardRepository @Inject constructor(private val apiService: ApiService) {
    suspend fun getKpi(): KpiSummaryDto = apiService.getDashboardKpi().data
    suspend fun getRecentInvoices(limit: Int = 5): List<InvoiceDto> = apiService.getRecentInvoices(limit).data
}
