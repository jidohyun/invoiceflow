package com.invoiceflow.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.invoiceflow.ui.theme.StatusCancelledBg
import com.invoiceflow.ui.theme.StatusCancelledFg
import com.invoiceflow.ui.theme.StatusDraftBg
import com.invoiceflow.ui.theme.StatusDraftFg
import com.invoiceflow.ui.theme.StatusOverdue
import com.invoiceflow.ui.theme.StatusOverdueBg
import com.invoiceflow.ui.theme.StatusPaid
import com.invoiceflow.ui.theme.StatusPaidBg
import com.invoiceflow.ui.theme.StatusPartiallyPaid
import com.invoiceflow.ui.theme.StatusPartiallyPaidBg
import com.invoiceflow.ui.theme.StatusSent
import com.invoiceflow.ui.theme.StatusSentBg

enum class InvoiceStatus(
    val label: String,
    val fg: Color,
    val bg: Color,
) {
    PAID("Paid", StatusPaid, StatusPaidBg),
    SENT("Sent", StatusSent, StatusSentBg),
    OVERDUE("Overdue", StatusOverdue, StatusOverdueBg),
    PARTIALLY_PAID("Partial", StatusPartiallyPaid, StatusPartiallyPaidBg),
    DRAFT("Draft", StatusDraftFg, StatusDraftBg),
    CANCELLED("Cancelled", StatusCancelledFg, StatusCancelledBg);

    companion object {
        fun from(value: String): InvoiceStatus = entries
            .firstOrNull { it.name.equals(value, ignoreCase = true) }
            ?: DRAFT
    }
}

@Composable
fun StatusPill(
    status: InvoiceStatus,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier
            .background(color = status.bg, shape = RoundedCornerShape(9999.dp))
            .padding(horizontal = 10.dp, vertical = 4.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = status.label,
            color = status.fg,
            fontSize = 12.sp,
            fontWeight = FontWeight.Medium,
            letterSpacing = 0.3.sp,
        )
    }
}

@Composable
fun StatusPill(
    statusString: String,
    modifier: Modifier = Modifier,
) = StatusPill(status = InvoiceStatus.from(statusString), modifier = modifier)
