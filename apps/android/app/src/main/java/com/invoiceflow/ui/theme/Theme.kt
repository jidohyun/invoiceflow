package com.invoiceflow.ui.theme

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext

private val LightColorScheme = lightColorScheme(
    primary = Color(0xFF1A73E8),
    onPrimary = Color.White,
    primaryContainer = Color(0xFFD3E3FD),
    secondary = Color(0xFF34A853),
    onSecondary = Color.White,
    error = Color(0xFFEA4335),
    background = Color(0xFFF8F9FA),
    surface = Color.White,
    onBackground = Color(0xFF202124),
    onSurface = Color(0xFF202124),
)

private val DarkColorScheme = darkColorScheme(
    primary = Color(0xFF8AB4F8),
    onPrimary = Color(0xFF003258),
    primaryContainer = Color(0xFF004880),
    secondary = Color(0xFF81C995),
    onSecondary = Color(0xFF003913),
    error = Color(0xFFF28B82),
    background = Color(0xFF202124),
    surface = Color(0xFF303134),
    onBackground = Color(0xFFE8EAED),
    onSurface = Color(0xFFE8EAED),
)

@Composable
fun InvoiceFlowTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    dynamicColor: Boolean = true,
    content: @Composable () -> Unit
) {
    val colorScheme = when {
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            val context = LocalContext.current
            if (darkTheme) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        }
        darkTheme -> DarkColorScheme
        else -> LightColorScheme
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography,
        content = content
    )
}
