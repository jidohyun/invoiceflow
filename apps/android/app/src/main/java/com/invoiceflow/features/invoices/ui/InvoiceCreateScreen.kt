package com.invoiceflow.features.invoices.ui

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.invoiceflow.features.clients.viewmodel.ClientViewModel
import com.invoiceflow.features.invoices.data.model.InvoiceCreateRequest
import com.invoiceflow.features.invoices.viewmodel.InvoiceCreateViewModel
import java.time.LocalDate

/**
 * AMI-88: minimal "new invoice" form for mobile.
 *
 * Picks a client, takes amount + currency + due date + optional notes,
 * POSTs to /api/v1/invoices via [InvoiceCreateViewModel.submit]. On
 * success [onCreated] navigates to the detail screen for the new invoice.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun InvoiceCreateScreen(
    onBack: () -> Unit,
    onCreated: (String) -> Unit,
    clientViewModel: ClientViewModel = hiltViewModel(),
    viewModel: InvoiceCreateViewModel = hiltViewModel(),
) {
    val clientState by clientViewModel.state.collectAsStateWithLifecycle()
    val state by viewModel.state.collectAsStateWithLifecycle()

    LaunchedEffect(Unit) { clientViewModel.loadClients() }
    LaunchedEffect(state.createdInvoiceId) {
        val id = state.createdInvoiceId
        if (id != null) {
            onCreated(id)
            viewModel.consumeNavigation()
        }
    }

    var clientMenuOpen by remember { mutableStateOf(false) }
    var currencyMenuOpen by remember { mutableStateOf(false) }
    var amount by rememberSaveable { mutableStateOf("") }
    var currency by rememberSaveable { mutableStateOf("KRW") }
    var notes by rememberSaveable { mutableStateOf("") }
    var dueDate by rememberSaveable { mutableStateOf(LocalDate.now().plusDays(14).toString()) }
    var selectedClientId by rememberSaveable { mutableStateOf<String?>(null) }
    val selectedClient = clientState.clients.find { it.id == selectedClientId }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("새 송장") },
                navigationIcon = {
                    IconButton(onClick = onBack) { Icon(Icons.Default.ArrowBack, "뒤로") }
                },
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .padding(padding)
                .padding(16.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            // Client picker
            Box {
                OutlinedButton(
                    onClick = { clientMenuOpen = true },
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text(selectedClient?.name ?: "거래처를 선택하세요")
                }
                DropdownMenu(
                    expanded = clientMenuOpen,
                    onDismissRequest = { clientMenuOpen = false },
                ) {
                    clientState.clients.forEach { c ->
                        DropdownMenuItem(
                            text = { Text(c.name) },
                            onClick = {
                                selectedClientId = c.id
                                clientMenuOpen = false
                            },
                        )
                    }
                }
            }

            OutlinedTextField(
                value = amount,
                onValueChange = { input ->
                    amount = input.filter { ch -> ch.isDigit() || ch == '.' }
                },
                label = { Text("금액") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )

            // Currency picker
            Box {
                OutlinedButton(
                    onClick = { currencyMenuOpen = true },
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text("통화: $currency")
                }
                DropdownMenu(
                    expanded = currencyMenuOpen,
                    onDismissRequest = { currencyMenuOpen = false },
                ) {
                    listOf("KRW", "USD", "EUR", "JPY", "GBP").forEach { c ->
                        DropdownMenuItem(
                            text = { Text(c) },
                            onClick = {
                                currency = c
                                currencyMenuOpen = false
                            },
                        )
                    }
                }
            }

            OutlinedTextField(
                value = dueDate,
                onValueChange = { dueDate = it },
                label = { Text("지급 기한 (YYYY-MM-DD)") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )

            OutlinedTextField(
                value = notes,
                onValueChange = { notes = it },
                label = { Text("메모 (선택)") },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(96.dp),
            )

            state.error?.let { msg -> Text(msg, color = MaterialTheme.colorScheme.error) }

            Button(
                onClick = {
                    val clientId = selectedClientId
                    if (clientId == null || amount.isBlank()) return@Button
                    viewModel.submit(
                        InvoiceCreateRequest(
                            clientId = clientId,
                            amount = amount,
                            currency = currency,
                            dueDate = dueDate,
                            notes = if (notes.isBlank()) null else notes,
                        )
                    )
                },
                enabled = !state.isSubmitting && selectedClientId != null && amount.isNotBlank(),
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(if (state.isSubmitting) "생성 중..." else "송장 생성")
            }
        }
    }
}
