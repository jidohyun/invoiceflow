//
//  InVoiceFlow_iOSApp.swift
//  InVoiceFlow_iOS
//
//  Created by 하동건 on 3/11/26.
//

import SwiftUI

@main
struct InVoiceFlow_iOSApp: App {
    @State private var auth = AuthViewModel()

    init() {
        // Wire baseURL to a build setting if we're shipping; default for
        // the simulator is the Phoenix dev server.
        if let urlString = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
           let url = URL(string: urlString) {
            APIClient.shared.baseURL = url
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(auth)
                .task { auth.bootstrap() }
        }
    }
}
