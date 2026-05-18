package com.invoiceflow.features.dashboard.ui

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.QrCode
import androidx.compose.material.icons.filled.Add
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.invoiceflow.features.dashboard.viewmodel.DashboardViewModel
import com.invoiceflow.features.dashboard.data.model.KpiSummaryDto
import com.invoiceflow.features.invoices.data.model.InvoiceDto
import java.text.NumberFormat
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DashboardScreen(
    onNavigateToInvoice: (String) -> Unit,
    onNavigateToCreate: () -> Unit,
    onNavigateToInvoices: () -> Unit,
    viewModel: DashboardViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val refreshing = state.isLoading

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("한눈에 보기") },
                actions = {
                    IconButton(onClick = onNavigateToCreate) {
                        Icon(Icons.Default.Add, contentDescription = "새 송장")
                    }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .padding(padding)
                .padding(horizontal = 16.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            state.error?.let { msg ->
                Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer)) {
                    Text(msg, modifier = Modifier.padding(16.dp), color = MaterialTheme.colorScheme.onErrorContainer)
                }
            }

            KpiRow(state.kpi, refreshing)

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("최근 송장", style = MaterialTheme.typography.titleMedium)
                TextButton(onClick = onNavigateToInvoices) { Text("전체 보기") }
            }

            if (state.recent.isEmpty() && !refreshing) {
                EmptyRecentInvoices(onNavigateToCreate)
            } else {
                state.recent.forEach { inv ->
                    RecentInvoiceRow(inv) { onNavigateToInvoice(inv.id) }
                }
            }

            Spacer(Modifier.height(24.dp))
        }
    }
}

@Composable
private fun KpiRow(kpi: KpiSummaryDto?, refreshing: Boolean) {
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        KpiCard(
            label = "미수금",
            value = kpi?.outstandingAmount?.let { formatKrw(it) } ?: if (refreshing) "..." else "₩0",
            sub = kpi?.overdueCount?.let { "연체 ${it}건" } ?: "",
            modifier = Modifier.weight(1f),
        )
        KpiCard(
            label = "수금률",
            value = kpi?.collectionRate?.let { "${it}%" } ?: if (refreshing) "..." else "0%",
            sub = "이번 달",
            modifier = Modifier.weight(1f),
        )
        KpiCard(
            label = "이번달 수금",
            value = kpi?.collectedThisMonth?.let { formatKrw(it) } ?: if (refreshing) "..." else "₩0",
            sub = "",
            modifier = Modifier.weight(1f),
        )
    }
}

@Composable
private fun KpiCard(label: String, value: String, sub: String, modifier: Modifier = Modifier) {
    Card(modifier = modifier) {
        Column(Modifier.padding(12.dp)) {
            Text(label, style = MaterialTheme.typography.labelMedium)
            Spacer(Modifier.height(4.dp))
            Text(value, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
            if (sub.isNotEmpty()) {
                Spacer(Modifier.height(2.dp))
                Text(sub, style = MaterialTheme.typography.labelSmall)
            }
        }
    }
}

@Composable
private fun RecentInvoiceRow(invoice: InvoiceDto, onClick: () -> Unit) {
    Card(onClick = onClick) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(Modifier.weight(1f)) {
                Text(
                    invoice.invoiceNumber ?: "송장 #${invoice.id.take(6)}",
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.SemiBold,
                )
                Text(invoice.status.uppercase(), style = MaterialTheme.typography.labelSmall)
            }
            Text(
                "${invoice.currency} ${invoice.amount}",
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Medium,
            )
        }
    }
}

@Composable
private fun EmptyRecentInvoices(onCreate: () -> Unit) {
    Card {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text("아직 송장이 없습니다", style = MaterialTheme.typography.bodyMedium)
            Text("첫 송장을 발행해 시작해 보세요.", style = MaterialTheme.typography.labelSmall)
            Button(onClick = onCreate) { Text("송장 만들기") }
        }
    }
}

private fun formatKrw(raw: String): String {
    val n = raw.toBigDecimalOrNull() ?: return "₩0"
    val fmt = NumberFormat.getCurrencyInstance(Locale.KOREA)
    return fmt.format(n)
}
