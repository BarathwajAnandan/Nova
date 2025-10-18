import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure the floating icon exists and start according to settings (default collapsed)
        AppVisibilityController.shared.ensureIconWindow()
        // Defer to next runloop to allow SwiftUI to create the main window before changing state
        DispatchQueue.main.async {
            AppVisibilityController.shared.startupRespectingSettings()
        }
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleScreenConfigChanged),
                                               name: NSApplication.didChangeScreenParametersNotification,
                                               object: nil)
    }

    @objc private func handleScreenConfigChanged() {
        // Nudge the icon back into a visible frame if displays change
        AppVisibilityController.shared.ensureIconWindow()
    }
}


