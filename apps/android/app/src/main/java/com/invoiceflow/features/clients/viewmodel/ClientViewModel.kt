package com.invoiceflow.features.clients.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.invoiceflow.features.clients.data.ClientRepository
import com.invoiceflow.features.clients.data.model.ClientDto
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class ClientListState(
    val clients: List<ClientDto> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null,
)

@HiltViewModel
class ClientViewModel @Inject constructor(
    private val clientRepository: ClientRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(ClientListState())
    val state: StateFlow<ClientListState> = _state.asStateFlow()

    fun loadClients() {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true, error = null) }
            try {
                val clients = clientRepository.getClients()
                _state.update { it.copy(clients = clients, isLoading = false) }
            } catch (e: Exception) {
                _state.update { it.copy(error = e.message ?: "Failed to load clients", isLoading = false) }
            }
        }
    }
}
