package com.invoiceflow.features.invoices.ui

import android.Manifest
import android.content.Context
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
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
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.FilterChip
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.invoiceflow.features.invoices.data.model.InvoiceDto
import com.invoiceflow.features.invoices.viewmodel.InvoiceViewModel
import kotlinx.coroutines.launch
import java.io.File

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun InvoiceListScreen(
    onNavigateToDetail: (String) -> Unit,
    onNavigateToCreate: () -> Unit,
    viewModel: InvoiceViewModel = hiltViewModel(),
) {
    val state by viewModel.listState.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val snackbarHostState = remember { SnackbarHostState() }

    // 촬영된 이미지 URI
    var photoUri by remember { mutableStateOf<Uri?>(null) }

    // 카메라 실행 launcher
    val cameraLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.TakePicture()
    ) { success ->
        if (success && photoUri != null) {
            scope.launch {
                snackbarHostState.showSnackbar("사진 저장 완료: ${photoUri?.lastPathSegment}")
            }
            // TODO: photoUri를 서버에 업로드하거나 OCR 처리
        }
    }

    // 카메라 권한 요청 launcher
    val permissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) {
            val uri = createPhotoUri(context)
            photoUri = uri
            cameraLauncher.launch(uri)
        } else {
            scope.launch {
                snackbarHostState.showSnackbar("카메라 권한이 필요합니다")
            }
        }
    }

    LaunchedEffect(Unit) { viewModel.loadInvoices() }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Invoices") },
                actions = {
                    IconButton(onClick = { permissionLauncher.launch(Manifest.permission.CAMERA) }) {
                        Icon(
                            imageVector = Icons.Default.CameraAlt,
                            contentDescription = "송장 촬영",
                            tint = MaterialTheme.colorScheme.primary,
                        )
                    }
                }
            )
        },
        floatingActionButton = {
            FloatingActionButton(onClick = onNavigateToCreate) {
                Icon(Icons.Default.Add, contentDescription = "Create invoice")
            }
        },
        snackbarHost = { SnackbarHost(snackbarHostState) },
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            Column(modifier = Modifier.fillMaxSize()) {
                FilterBar(
                    statusFilter = state.statusFilter,
                    search = state.search,
                    onStatusChange = viewModel::setStatusFilter,
                    onSearchChange = viewModel::setSearch,
                )
                when {
                    state.isLoading -> Box(Modifier.fillMaxSize()) {
                        CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))
                    }
                    state.error != null -> Box(Modifier.fillMaxSize()) {
                        Text(
                            text = state.error ?: "",
                            color = MaterialTheme.colorScheme.error,
                            modifier = Modifier.align(Alignment.Center),
                        )
                    }
                    state.invoices.isEmpty() -> Box(Modifier.fillMaxSize()) {
                        Text(text = "조건에 맞는 송장이 없습니다", modifier = Modifier.align(Alignment.Center))
                    }
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
}

private fun createPhotoUri(context: Context): Uri {
    val dir = File(context.cacheDir, "invoice_photos").apply { mkdirs() }
    val file = File.createTempFile("INV_", ".jpg", dir)
    return FileProvider.getUriForFile(
        context,
        "${context.packageName}.fileprovider",
        file,
    )
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
                Text(text = "#${invoice.invoiceNumber}", style = MaterialTheme.typography.titleMedium)
                Text(text = invoice.client?.name ?: "", style = MaterialTheme.typography.bodyMedium)
                Text(text = "Due: ${invoice.dueDate ?: ""}", style = MaterialTheme.typography.bodySmall)
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

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun FilterBar(
    statusFilter: String?,
    search: String,
    onStatusChange: (String?) -> Unit,
    onSearchChange: (String) -> Unit,
) {
    val options: List<Pair<String?, String>> = listOf(
        null to "전체",
        "draft" to "임시저장",
        "sent" to "발송",
        "overdue" to "연체",
        "paid" to "결제완료",
        "partially_paid" to "부분결제",
    )
    Column(Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 8.dp)) {
        OutlinedTextField(
            value = search,
            onValueChange = onSearchChange,
            placeholder = { Text("송장 번호, 거래처, 메모 검색") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(8.dp))
        LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            items(options) { (value, label) ->
                FilterChip(
                    selected = statusFilter == value,
                    onClick = { onStatusChange(value) },
                    label = { Text(label) },
                )
            }
        }
    }
}
