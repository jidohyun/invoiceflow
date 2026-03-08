package com.invoiceflow.features.invoices.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
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
        viewModelScope.launch {
            _listState.update { it.copy(isLoading = true, error = null) }
            try {
                val invoices = invoiceRepository.getInvoices()
                _listState.update { it.copy(invoices = invoices, isLoading = false) }
            } catch (e: Exception) {
                _listState.update { it.copy(error = e.message ?: "Failed to load invoices", isLoading = false) }
            }
        }
    }

    fun loadInvoice(id: String) {
        viewModelScope.launch {
            _detailState.update { it.copy(isLoading = true, error = null) }
            try {
                val invoice = invoiceRepository.getInvoice(id)
                _detailState.update { it.copy(invoice = invoice, isLoading = false) }
            } catch (e: Exception) {
                _detailState.update { it.copy(error = e.message ?: "Failed to load invoice", isLoading = false) }
            }
        }
    }
}
