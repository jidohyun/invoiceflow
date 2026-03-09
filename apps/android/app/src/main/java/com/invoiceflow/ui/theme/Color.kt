package com.invoiceflow.ui.theme

import androidx.compose.ui.graphics.Color

// ── Light Palette ──────────────────────────────────────────────
// oklch(49.69% 0.265 292.608) → violet
val Primary = Color(0xFF6917E6)
val PrimaryContent = Color(0xFFF8F5FF)

// oklch(55% 0.2 255) → blue
val Secondary = Color(0xFF3B5FE0)
val SecondaryContent = Color(0xFFF5F7FF)

// oklch(60% 0.15 250) → periwinkle
val Accent = Color(0xFF4B71CC)
val AccentContent = Color(0xFFFFFFFF)

val Base100 = Color(0xFFFAFAFA)
val Base200 = Color(0xFFFFFFFF)
val Base300 = Color(0xFFE8E9EF)
val BaseContent = Color(0xFF3D4266)

val Neutral = Color(0xFF1A1D35)
val NeutralContent = Color(0xFFF5F5FA)

// ── Dark Palette ────────────────────────────────────────────────
// oklch(62% 0.25 292) → lighter violet
val PrimaryDark = Color(0xFFA855F7)
val PrimaryContentDark = Color(0xFFF8F5FF)

val SecondaryDark = Color(0xFF5B7AEB)
val SecondaryContentDark = Color(0xFFF5F7FF)

val AccentDark = Color(0xFF6B86D6)
val AccentContentDark = Color(0xFFFFFFFF)

val Base100Dark = Color(0xFF151829)
val Base200Dark = Color(0xFF1E2235)
val Base300Dark = Color(0xFF2C3050)
val BaseContentDark = Color(0xFFC8CDE3)

val NeutralDark = Color(0xFFF5F5FA)
val NeutralContentDark = Color(0xFF151829)

// ── Semantic (shared light & dark) ─────────────────────────────
val Info = Color(0xFF2563EB)
val InfoContent = Color(0xFFEFF6FF)

val Success = Color(0xFF22C9A0)
val SuccessContent = Color(0xFFECFDF5)

val Warning = Color(0xFFD97706)
val WarningContent = Color(0xFFFFFBEB)

val AppError = Color(0xFFDC2626)
val AppErrorContent = Color(0xFFFEF2F2)

// ── Status Semantic ─────────────────────────────────────────────
val StatusPaid = Success
val StatusPaidBg = Color(0x1A22C9A0)       // success/10
val StatusSent = Info
val StatusSentBg = Color(0x1A2563EB)       // info/10
val StatusOverdue = AppError
val StatusOverdueBg = Color(0x1ADC2626)    // error/10
val StatusPartiallyPaid = Warning
val StatusPartiallyPaidBg = Color(0x1AD97706) // warning/10
val StatusDraftFg = Color(0x993D4266)       // base-content/60
val StatusDraftBg = Color(0x1A3D4266)      // base-content/10
val StatusCancelledFg = Color(0x663D4266)  // base-content/40
val StatusCancelledBg = Color(0x1A3D4266)  // base-content/10
