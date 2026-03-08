package com.invoiceflow.features.auth.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.invoiceflow.features.auth.data.AuthRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class AuthState(
    val isLoading: Boolean = false,
    val error: String? = null,
)

sealed interface AuthEvent {
    data class LoginSuccess(val token: String) : AuthEvent
    data class RegisterSuccess(val token: String) : AuthEvent
    data class Error(val message: String) : AuthEvent
}

@HiltViewModel
class AuthViewModel @Inject constructor(
    private val authRepository: AuthRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(AuthState())
    val state: StateFlow<AuthState> = _state.asStateFlow()

    val isLoggedIn: StateFlow<Boolean> = authRepository.isLoggedIn()
        .map { it != null }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), false)

    private val _events = MutableStateFlow<AuthEvent?>(null)
    val events: StateFlow<AuthEvent?> = _events.asStateFlow()

    fun login(email: String, password: String) {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true, error = null) }
            try {
                val response = authRepository.login(email, password)
                _events.value = AuthEvent.LoginSuccess(response.token)
            } catch (e: Exception) {
                val message = e.message ?: "Login failed"
                _state.update { it.copy(error = message) }
                _events.value = AuthEvent.Error(message)
            } finally {
                _state.update { it.copy(isLoading = false) }
            }
        }
    }

    fun register(email: String, password: String, name: String) {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true, error = null) }
            try {
                val response = authRepository.register(email, password, name)
                _events.value = AuthEvent.RegisterSuccess(response.token)
            } catch (e: Exception) {
                val message = e.message ?: "Registration failed"
                _state.update { it.copy(error = message) }
                _events.value = AuthEvent.Error(message)
            } finally {
                _state.update { it.copy(isLoading = false) }
            }
        }
    }

    fun consumeEvent() {
        _events.value = null
    }

    fun clearError() {
        _state.update { it.copy(error = null) }
    }
}
