//
//  novaApp.swift
//  nova
//
//  Created by Rohith Gandhi  on 10/18/25.
//

import SwiftUI

@main
struct novaApp: App {
    @StateObject private var vm = ChatViewModel()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vm)
        }
        .windowStyle(.automatic)
        .commands {
            CommandMenu("Nova") {
                Button("Capture Selection") {
                    vm.captureSelection()
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
        }
    }
}
