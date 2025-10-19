import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    // Shared ChatViewModel so auxiliary windows can share the same environment object
    var sharedViewModel: ChatViewModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure the floating icon exists and start according to settings (default collapsed)
        Task { @MainActor in
            AppVisibilityController.shared.ensureIconWindow()
            // Defer to next runloop to allow SwiftUI to create the main window before changing state
            AppVisibilityController.shared.startupRespectingSettings()
        }

        Task(priority: .userInitiated) {
            do {
                try await BackendClient.ensureSession()
            } catch {
                print("Failed to create backend session on launch: \(error.localizedDescription)")
            }
        }
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleScreenConfigChanged),
                                               name: NSApplication.didChangeScreenParametersNotification,
                                               object: nil)
    }

    @objc private func handleScreenConfigChanged() {
        // Nudge the icon back into a visible frame if displays change
        Task { @MainActor in
            AppVisibilityController.shared.ensureIconWindow()
        }
    }
}


