package com.invoiceflow.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val LightColorScheme = lightColorScheme(
    primary = Primary,
    onPrimary = PrimaryContent,
    primaryContainer = Color(0xFFEDE9FE),
    onPrimaryContainer = Color(0xFF3B0764),
    secondary = Secondary,
    onSecondary = SecondaryContent,
    secondaryContainer = Color(0xFFDBE4FF),
    onSecondaryContainer = Color(0xFF1A2F6E),
    tertiary = Accent,
    onTertiary = AccentContent,
    background = Base100,
    onBackground = BaseContent,
    surface = Base200,
    onSurface = BaseContent,
    surfaceVariant = Base300,
    onSurfaceVariant = BaseContent,
    outline = Base300,
    error = AppError,
    onError = AppErrorContent,
    inverseSurface = Neutral,
    inverseOnSurface = NeutralContent,
)

private val DarkColorScheme = darkColorScheme(
    primary = PrimaryDark,
    onPrimary = PrimaryContentDark,
    primaryContainer = Color(0xFF3B0764),
    onPrimaryContainer = Color(0xFFEDE9FE),
    secondary = SecondaryDark,
    onSecondary = SecondaryContentDark,
    secondaryContainer = Color(0xFF1A2F6E),
    onSecondaryContainer = Color(0xFFDBE4FF),
    tertiary = AccentDark,
    onTertiary = AccentContentDark,
    background = Base100Dark,
    onBackground = BaseContentDark,
    surface = Base200Dark,
    onSurface = BaseContentDark,
    surfaceVariant = Base300Dark,
    onSurfaceVariant = BaseContentDark,
    outline = Base300Dark,
    error = AppError,
    onError = AppErrorContent,
    inverseSurface = NeutralDark,
    inverseOnSurface = NeutralContentDark,
)

@Composable
fun InvoiceFlowTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    MaterialTheme(
        colorScheme = if (darkTheme) DarkColorScheme else LightColorScheme,
        typography = Typography,
        shapes = InvoiceFlowShapes,
        content = content,
    )
}
