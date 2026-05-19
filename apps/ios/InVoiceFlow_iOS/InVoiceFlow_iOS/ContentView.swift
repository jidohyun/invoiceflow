//
//  ContentView.swift
//  InVoiceFlow_iOS
//
//  Created by 하동건 on 3/11/26.
//

import SwiftUI

/// AMI-88 (iOS): root router. Reads `AuthViewModel.state` from the
/// environment and swaps between the login flow and the dashboard. No
/// NavigationStack here; each leaf owns its own navigation.
struct ContentView: View {
    @Environment(AuthViewModel.self) private var auth

    var body: some View {
        switch auth.state {
        case .checking:
            ProgressView().controlSize(.large)
        case .loggedOut:
            LoginView()
        case .loggedIn:
            DashboardView()
        }
    }
}

#Preview {
    ContentView()
        .environment(AuthViewModel())
}
