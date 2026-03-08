package com.invoiceflow.navigation

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.invoiceflow.features.auth.ui.LoginScreen
import com.invoiceflow.features.auth.ui.RegisterScreen
import com.invoiceflow.features.auth.viewmodel.AuthViewModel
import com.invoiceflow.features.clients.ui.ClientListScreen
import com.invoiceflow.features.invoices.ui.InvoiceDetailScreen
import com.invoiceflow.features.invoices.ui.InvoiceListScreen

@Composable
fun InvoiceFlowNavHost(
    navController: NavHostController = rememberNavController(),
) {
    val authViewModel: AuthViewModel = hiltViewModel()
    val isLoggedIn by authViewModel.isLoggedIn.collectAsStateWithLifecycle()

    val startDestination = if (isLoggedIn) NavRoutes.InvoiceList.route else NavRoutes.Login.route

    NavHost(
        navController = navController,
        startDestination = startDestination,
    ) {
        // Auth
        composable(NavRoutes.Login.route) {
            LoginScreen(
                onLoginSuccess = {
                    navController.navigate(NavRoutes.InvoiceList.route) {
                        popUpTo(NavRoutes.Login.route) { inclusive = true }
                    }
                },
                onNavigateToRegister = {
                    navController.navigate(NavRoutes.Register.route)
                }
            )
        }

        composable(NavRoutes.Register.route) {
            RegisterScreen(
                onRegisterSuccess = {
                    navController.navigate(NavRoutes.InvoiceList.route) {
                        popUpTo(NavRoutes.Login.route) { inclusive = true }
                    }
                },
                onNavigateToLogin = {
                    navController.popBackStack()
                }
            )
        }

        // Invoices
        composable(NavRoutes.InvoiceList.route) {
            InvoiceListScreen(
                onNavigateToDetail = { invoiceId ->
                    navController.navigate(NavRoutes.InvoiceDetail.createRoute(invoiceId))
                },
                onNavigateToCreate = {
                    navController.navigate(NavRoutes.InvoiceCreate.route)
                }
            )
        }

        composable(
            route = NavRoutes.InvoiceDetail.route,
            arguments = listOf(navArgument("invoiceId") { type = NavType.StringType })
        ) { backStackEntry ->
            val invoiceId = backStackEntry.arguments?.getString("invoiceId") ?: return@composable
            InvoiceDetailScreen(
                invoiceId = invoiceId,
                onNavigateBack = { navController.popBackStack() }
            )
        }

        // Clients
        composable(NavRoutes.ClientList.route) {
            ClientListScreen(
                onNavigateToDetail = { clientId ->
                    navController.navigate(NavRoutes.ClientDetail.createRoute(clientId))
                }
            )
        }
    }
}
