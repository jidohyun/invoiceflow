package com.invoiceflow.features.clients.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.invoiceflow.features.clients.data.model.ClientDto
import com.invoiceflow.features.clients.viewmodel.ClientViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ClientListScreen(
    onNavigateToDetail: (String) -> Unit,
    viewModel: ClientViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    LaunchedEffect(Unit) { viewModel.loadClients() }

    Scaffold(
        topBar = { TopAppBar(title = { Text("Clients") }) }
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            when {
                state.isLoading -> CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))
                state.error != null -> Text(
                    text = state.error ?: "",
                    color = MaterialTheme.colorScheme.error,
                    modifier = Modifier.align(Alignment.Center),
                )
                state.clients.isEmpty() -> Text(
                    text = "No clients yet",
                    modifier = Modifier.align(Alignment.Center),
                )
                else -> LazyColumn(modifier = Modifier.fillMaxSize()) {
                    items(state.clients, key = { it.id }) { client ->
                        ClientListItem(
                            client = client,
                            onClick = { onNavigateToDetail(client.id) },
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun ClientListItem(
    client: ClientDto,
    onClick: () -> Unit,
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp)
            .clickable(onClick = onClick),
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(text = client.name, style = MaterialTheme.typography.titleMedium)
            Text(text = client.email, style = MaterialTheme.typography.bodyMedium)
            client.company?.let {
                Text(text = it, style = MaterialTheme.typography.bodySmall)
            }
        }
    }
}
