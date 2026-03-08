package com.invoiceflow.features.invoices.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
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
import com.invoiceflow.features.invoices.data.model.InvoiceDto
import com.invoiceflow.features.invoices.viewmodel.InvoiceViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun InvoiceListScreen(
    onNavigateToDetail: (String) -> Unit,
    onNavigateToCreate: () -> Unit,
    viewModel: InvoiceViewModel = hiltViewModel(),
) {
    val state by viewModel.listState.collectAsStateWithLifecycle()

    LaunchedEffect(Unit) { viewModel.loadInvoices() }

    Scaffold(
        topBar = { TopAppBar(title = { Text("Invoices") }) },
        floatingActionButton = {
            FloatingActionButton(onClick = onNavigateToCreate) {
                Icon(Icons.Default.Add, contentDescription = "Create invoice")
            }
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
                state.invoices.isEmpty() -> Text(
                    text = "No invoices yet",
                    modifier = Modifier.align(Alignment.Center),
                )
                else -> LazyColumn(modifier = Modifier.fillMaxSize()) {
                    items(state.invoices, key = { it.id }) { invoice ->
                        InvoiceListItem(
                            invoice = invoice,
                            onClick = { onNavigateToDetail(invoice.id) },
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun InvoiceListItem(
    invoice: InvoiceDto,
    onClick: () -> Unit,
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp)
            .clickable(onClick = onClick),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column {
                Text(text = "#${invoice.number}", style = MaterialTheme.typography.titleMedium)
                Text(text = invoice.clientName, style = MaterialTheme.typography.bodyMedium)
                Text(text = "Due: ${invoice.dueDate}", style = MaterialTheme.typography.bodySmall)
            }
            Column(horizontalAlignment = Alignment.End) {
                Text(
                    text = "${invoice.currency} ${invoice.amount}",
                    style = MaterialTheme.typography.titleMedium,
                )
                Text(
                    text = invoice.status.uppercase(),
                    style = MaterialTheme.typography.labelLarge,
                    color = when (invoice.status) {
                        "paid" -> MaterialTheme.colorScheme.secondary
                        "overdue" -> MaterialTheme.colorScheme.error
                        else -> MaterialTheme.colorScheme.onSurface
                    }
                )
            }
        }
    }
}
