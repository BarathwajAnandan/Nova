//
//  novaApp.swift
//  nova
//
//  Created by Rohith Gandhi  on 10/18/25.
//

import SwiftUI

@main
struct novaApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.automatic)

        Settings {
            SettingsView()
        }
    }
}
