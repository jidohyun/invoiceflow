package com.invoiceflow.features.dashboard.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.invoiceflow.features.dashboard.data.DashboardRepository
import com.invoiceflow.features.dashboard.data.model.KpiSummaryDto
import com.invoiceflow.features.invoices.data.model.InvoiceDto
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import javax.inject.Inject

data class DashboardState(
    val kpi: KpiSummaryDto? = null,
    val recent: List<InvoiceDto> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null,
)

@HiltViewModel
class DashboardViewModel @Inject constructor(
    private val repository: DashboardRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(DashboardState())
    val state: StateFlow<DashboardState> = _state.asStateFlow()

    init { refresh() }

    fun refresh() {
        _state.update { it.copy(isLoading = true, error = null) }
        viewModelScope.launch {
            runCatching {
                val kpi = repository.getKpi()
                val recent = repository.getRecentInvoices(limit = 5)
                kpi to recent
            }.onSuccess { (kpi, recent) ->
                _state.update { it.copy(kpi = kpi, recent = recent, isLoading = false) }
            }.onFailure { e ->
                _state.update { it.copy(error = e.message ?: "대시보드를 불러오지 못했습니다", isLoading = false) }
            }
        }
    }
}
