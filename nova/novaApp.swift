//
//  novaApp.swift
//  nova
//
//  Created by Rohith Gandhi  on 10/18/25.
//

import SwiftUI

@main
struct novaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appDelegate.sharedViewModel)
        }
        .windowStyle(.automatic)
        .commands {
            CommandMenu("Nova") {
                Button("Capture Selection") {
                    appDelegate.sharedViewModel.captureSelection()
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])

                Button("Start Voice Capture") {
                    appDelegate.sharedViewModel.handleGlobalHotkeyPress()
                }
                .keyboardShortcut("x", modifiers: [.option])

                Divider()

                Button("Toggle Nova Visibility") {
                    AppVisibilityController.shared.toggle()
                }
                .keyboardShortcut("m", modifiers: [.command, .option])
            }
        }

        Settings {
            SettingsView()
                .environmentObject(appDelegate.sharedViewModel)
        }
    }
}
