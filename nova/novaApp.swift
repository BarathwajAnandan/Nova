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

                Divider()

                Button("Toggle Nova") {
                    AppVisibilityController.shared.toggle()
                }
                .keyboardShortcut("n", modifiers: [.command, .option])
            }
        }

        Settings {
            SettingsView()
        }
    }
}
