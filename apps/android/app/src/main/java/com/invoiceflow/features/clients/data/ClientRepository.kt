package com.invoiceflow.features.clients.data

import com.invoiceflow.core.network.ApiService
import com.invoiceflow.features.clients.data.model.ClientDto
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class ClientRepository @Inject constructor(
    private val apiService: ApiService,
) {
    suspend fun getClients(): List<ClientDto> = apiService.getClients()

    suspend fun getClient(id: String): ClientDto = apiService.getClient(id)
}
