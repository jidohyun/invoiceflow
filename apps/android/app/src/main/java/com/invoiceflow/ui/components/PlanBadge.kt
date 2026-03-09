package com.invoiceflow.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.invoiceflow.ui.theme.Accent
import com.invoiceflow.ui.theme.Primary

enum class PlanTier(val label: String) {
    FREE("Free"),
    STARTER("Starter"),
    PRO("Pro"),
    ;

    companion object {
        fun from(value: String): PlanTier = entries
            .firstOrNull { it.name.equals(value, ignoreCase = true) }
            ?: FREE
    }
}

@Composable
fun PlanBadge(
    plan: PlanTier,
    modifier: Modifier = Modifier,
) {
    val (bg, fg, borderColor) = when (plan) {
        PlanTier.FREE -> Triple(
            Color.Transparent,
            MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
            MaterialTheme.colorScheme.outline,
        )
        PlanTier.STARTER -> Triple(
            Primary.copy(alpha = 0.12f),
            Primary,
            Color.Transparent,
        )
        PlanTier.PRO -> Triple(
            Accent.copy(alpha = 0.12f),
            Accent,
            Color.Transparent,
        )
    }

    Box(
        modifier = modifier
            .background(color = bg, shape = RoundedCornerShape(9999.dp))
            .then(
                if (borderColor != Color.Transparent)
                    Modifier.border(1.dp, borderColor, RoundedCornerShape(9999.dp))
                else Modifier
            )
            .padding(horizontal = 10.dp, vertical = 3.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = plan.label,
            color = fg,
            fontSize = 11.sp,
            fontWeight = FontWeight.SemiBold,
            letterSpacing = 0.4.sp,
        )
    }
}

@Composable
fun PlanBadge(
    planString: String,
    modifier: Modifier = Modifier,
) = PlanBadge(plan = PlanTier.from(planString), modifier = modifier)
