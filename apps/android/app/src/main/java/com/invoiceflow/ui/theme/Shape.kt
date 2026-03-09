package com.invoiceflow.ui.theme

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Shapes
import androidx.compose.ui.unit.dp

// Design token → borderRadius mapping
// selector: 0.5rem = 8dp
// field:    0.375rem = 6dp
// box/card: 0.75rem = 12dp
// button:   0.5rem = 8dp
// full/badge: 9999px

val InvoiceFlowShapes = Shapes(
    extraSmall = RoundedCornerShape(6.dp),   // field
    small = RoundedCornerShape(8.dp),         // selector / button
    medium = RoundedCornerShape(12.dp),       // box / card
    large = RoundedCornerShape(12.dp),        // card
    extraLarge = RoundedCornerShape(9999.dp), // full / badge
)
