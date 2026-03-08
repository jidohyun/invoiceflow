package com.invoiceflow.features.auth.data

import com.invoiceflow.core.data.TokenRepository
import com.invoiceflow.core.network.ApiService
import com.invoiceflow.features.auth.data.model.LoginRequest
import com.invoiceflow.features.auth.data.model.LoginResponse
import com.invoiceflow.features.auth.data.model.RegisterRequest
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class AuthRepository @Inject constructor(
    private val apiService: ApiService,
    private val tokenRepository: TokenRepository,
) {
    suspend fun login(email: String, password: String): LoginResponse {
        val response = apiService.login(LoginRequest(email, password))
        tokenRepository.saveToken(response.token)
        return response
    }

    suspend fun register(email: String, password: String, name: String): LoginResponse {
        val response = apiService.register(
            RegisterRequest(
                email = email,
                password = password,
                passwordConfirmation = password,
                name = name,
            )
        )
        tokenRepository.saveToken(response.token)
        return response
    }

    suspend fun logout() {
        tokenRepository.clearToken()
    }

    fun isLoggedIn() = tokenRepository.tokenFlow
}
