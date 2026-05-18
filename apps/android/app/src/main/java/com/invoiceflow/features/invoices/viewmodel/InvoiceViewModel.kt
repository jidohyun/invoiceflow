package com.invoiceflow.features.invoices.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.invoiceflow.BuildConfig
import com.invoiceflow.core.data.MockData
import com.invoiceflow.features.invoices.data.InvoiceRepository
import com.invoiceflow.features.invoices.data.model.InvoiceDto
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class InvoiceListState(
    val invoices: List<InvoiceDto> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null,
    /** One of: null (all) | "draft" | "sent" | "overdue" | "paid" | "partially_paid". */
    val statusFilter: String? = null,
    val search: String = "",
)

data class InvoiceDetailState(
    val invoice: InvoiceDto? = null,
    val isLoading: Boolean = false,
    val error: String? = null,
)

@HiltViewModel
class InvoiceViewModel @Inject constructor(
    private val invoiceRepository: InvoiceRepository,
) : ViewModel() {

    private val _listState = MutableStateFlow(InvoiceListState())
    val listState: StateFlow<InvoiceListState> = _listState.asStateFlow()

    private val _detailState = MutableStateFlow(InvoiceDetailState())
    val detailState: StateFlow<InvoiceDetailState> = _detailState.asStateFlow()

    fun loadInvoices() {
        val state = _listState.value
        viewModelScope.launch {
            _listState.update { it.copy(isLoading = true, error = null) }
            try {
                val response = invoiceRepository.getInvoices(
                    status = state.statusFilter,
                    search = state.search.takeIf { q -> q.isNotBlank() },
                )
                _listState.update { it.copy(invoices = response.data, isLoading = false) }
            } catch (e: Exception) {
                if (BuildConfig.DEBUG) {
                    val filtered = MockData.invoices
                        .filter { state.statusFilter == null || it.status == state.statusFilter }
                        .filter {
                            state.search.isBlank() ||
                                it.invoiceNumber.contains(state.search, ignoreCase = true) ||
                                (it.client?.name ?: "").contains(state.search, ignoreCase = true)
                        }
                    _listState.update { it.copy(invoices = filtered, isLoading = false) }
                } else {
                    _listState.update { it.copy(error = e.message ?: "Failed to load invoices", isLoading = false) }
                }
            }
        }
    }

    fun setStatusFilter(status: String?) {
        _listState.update { it.copy(statusFilter = status) }
        loadInvoices()
    }

    fun setSearch(query: String) {
        _listState.update { it.copy(search = query) }
        loadInvoices()
    }

    fun loadInvoice(id: String) {
        viewModelScope.launch {
            _detailState.update { it.copy(isLoading = true, error = null) }
            try {
                val invoice = invoiceRepository.getInvoice(id)
                _detailState.update { it.copy(invoice = invoice, isLoading = false) }
            } catch (e: Exception) {
                if (BuildConfig.DEBUG) {
                    val mock = MockData.invoices.find { it.id == id } ?: MockData.invoices.first()
                    _detailState.update { it.copy(invoice = mock, isLoading = false) }
                } else {
                    _detailState.update { it.copy(error = e.message ?: "Failed to load invoice", isLoading = false) }
                }
            }
        }
    }
}
