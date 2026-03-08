package com.invoiceflow.features.invoices.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
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
import com.invoiceflow.features.invoices.viewmodel.InvoiceViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun InvoiceDetailScreen(
    invoiceId: String,
    onNavigateBack: () -> Unit,
    viewModel: InvoiceViewModel = hiltViewModel(),
) {
    val state by viewModel.detailState.collectAsStateWithLifecycle()

    LaunchedEffect(invoiceId) { viewModel.loadInvoice(invoiceId) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Invoice Detail") },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        }
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
                state.invoice != null -> {
                    val invoice = state.invoice!!
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text(text = "Invoice #${invoice.number}", style = MaterialTheme.typography.headlineMedium)
                        Spacer(modifier = Modifier.height(16.dp))
                        Text(text = "Client: ${invoice.clientName}", style = MaterialTheme.typography.bodyLarge)
                        Text(text = "Status: ${invoice.status.uppercase()}", style = MaterialTheme.typography.bodyLarge)
                        Text(text = "Amount: ${invoice.currency} ${invoice.amount}", style = MaterialTheme.typography.bodyLarge)
                        Text(text = "Due: ${invoice.dueDate}", style = MaterialTheme.typography.bodyLarge)
                    }
                }
            }
        }
    }
}
