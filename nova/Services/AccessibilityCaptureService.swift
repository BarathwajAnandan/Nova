//
//  AccessibilityCaptureService.swift
//  nova
//
//  Continuously captures accessible text from the frontmost app window.
//

import Foundation
import AppKit
import ApplicationServices

struct RecognizedApp {
    let name: String
    let icon: NSImage?
}

final class AccessibilityCaptureService {
    var onCapture: ((String) -> Void)?
    var onRecognizedAppChange: ((RecognizedApp?) -> Void)?

    private var timer: Timer?
    private var lastHash: Int?
    private let pollInterval: TimeInterval = 2.0
    private let maxChars: Int = 8000
    private var lastFrontmostBundleId: String?
    private var lastNonSelfAppBundleId: String?
    private var lastNonSelfAppPid: pid_t?
    private var lastNonSelfAppSnapshot: RecognizedApp?

    @discardableResult
    func start() -> Bool {
        guard isTrustedOrPrompt() else { return false }
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
        tick()
        return true
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        emitFrontmostAppIfChanged()
        guard let text = captureFrontmostWindowText(), text.isEmpty == false else { return }
        let clipped = String(text.prefix(maxChars))
        let hash = clipped.hashValue
        guard hash != lastHash else { return }
        lastHash = hash
        onCapture?(clipped)
    }

    private func isTrustedOrPrompt() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private func captureFrontmostWindowText() -> String? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }
        if let myBundle = Bundle.main.bundleIdentifier,
           let frontBundle = frontApp.bundleIdentifier,
           frontBundle == myBundle {
            // Avoid capturing our own app's UI (e.g., header label "Nova")
            return nil
        }
        let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)

        // Prefer the focused UI element (often the text editor in apps like Notes)
        var focusedRef: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedRef)
        var rootElement: AXUIElement?
        if focusedResult == .success, let focusedRef, CFGetTypeID(focusedRef) == AXUIElementGetTypeID() {
            rootElement = (focusedRef as! AXUIElement)
        } else {
            // Fallback to the focused window
            var windowRef: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowRef)
            if result == .success, let windowRef, CFGetTypeID(windowRef) == AXUIElementGetTypeID() {
                rootElement = (windowRef as! AXUIElement)
            }
        }
        guard let element = rootElement else { return nil }

        var visited = Set<UnsafeMutableRawPointer>()
        let text = collectText(from: element, visited: &visited)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func emitFrontmostAppIfChanged() {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            if lastFrontmostBundleId != nil {
                lastFrontmostBundleId = nil
                onRecognizedAppChange?(nil)
            }
            return
        }

        let bundleId = app.bundleIdentifier ?? String(app.processIdentifier)
        guard bundleId != lastFrontmostBundleId else { return }
        lastFrontmostBundleId = bundleId

        let myBundle = Bundle.main.bundleIdentifier
        let isSelf = (myBundle != nil && bundleId == myBundle)

        if isSelf {
            // When Nova is frontmost, continue showing the last non-self app snapshot (if any)
            if let snapshot = lastNonSelfAppSnapshot {
                onRecognizedAppChange?(snapshot)
            }
            return
        }

        let name = app.localizedName ?? bundleId
        var icon: NSImage? = nil
        if let url = app.bundleURL {
            icon = NSWorkspace.shared.icon(forFile: url.path)
        }

        let snapshot = RecognizedApp(name: name, icon: icon)
        lastNonSelfAppSnapshot = snapshot
        lastNonSelfAppBundleId = app.bundleIdentifier
        lastNonSelfAppPid = app.processIdentifier
        onRecognizedAppChange?(snapshot)
    }

    private func collectText(from element: AXUIElement, visited: inout Set<UnsafeMutableRawPointer>) -> String {
        let key = Unmanaged.passUnretained(element).toOpaque()
        if visited.contains(key) { return "" }
        visited.insert(key)

        func attribute(_ name: CFString) -> Any? {
            var value: CFTypeRef?
            let code = AXUIElementCopyAttributeValue(element, name, &value)
            return code == .success ? value : nil
        }
        func attribute(_ name: String) -> Any? {
            attribute(name as CFString)
        }

        // Skip secure/protected text fields
        if let isProtected = attribute("AXValueProtected") as? Bool, isProtected {
            return ""
        }
        if let role = attribute(kAXRoleAttribute) as? String, role == "AXSecureTextField" {
            return ""
        }

        // Try to pull full text using parameterized range if supported
        if let numChars = attribute(kAXNumberOfCharactersAttribute) as? NSNumber, numChars.intValue > 0 {
            var range = CFRange(location: 0, length: numChars.intValue)
            if let rangeValue = AXValueCreate(.cfRange, &range) {
                var out: CFTypeRef?
                let code = AXUIElementCopyParameterizedAttributeValue(element, kAXStringForRangeParameterizedAttribute as CFString, rangeValue, &out)
                if code == .success, let str = out as? String, str.isEmpty == false {
                    return str
                }
            }
        }

        // Prefer value attribute (works for text fields/areas/web areas)
        if let value = attribute(kAXValueAttribute) as? String {
            return value
        }
        if let attr = attribute(kAXValueAttribute) as? NSAttributedString {
            return attr.string
        }

        // Fallback to title for static text/buttons/etc.
        if let title = attribute(kAXTitleAttribute) as? String, title.isEmpty == false {
            return title
        }

        // Recurse into children
        var aggregate = ""
        // Prefer visible children if available
        let childrenList: [AXUIElement]? = (attribute(kAXVisibleChildrenAttribute) as? [AXUIElement]) ?? (attribute(kAXChildrenAttribute) as? [AXUIElement])
        if let children = childrenList {
            for child in children {
                let t = collectText(from: child, visited: &visited)
                if t.isEmpty == false {
                    aggregate += (aggregate.isEmpty ? "" : "\n") + t
                }
            }
        }
        return aggregate
    }
}



extension AccessibilityCaptureService {
    /// Capture the currently selected text from the focused UI element of the frontmost app.
    /// Falls back to selected range extraction when plain selected text is unavailable.
    /// Returns a clipped string (up to maxChars) or nil if not available/secure.
    func captureSelectedTextOnce() -> String? {
        guard isTrustedOrPrompt() else { return nil }
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }
        return captureSelectedText(appPid: frontApp.processIdentifier)
    }

    /// Capture selected text from the last non-self app (if known), even when Nova is frontmost.
    func captureSelectedTextFromLastAppOnce() -> String? {
        guard isTrustedOrPrompt() else { return nil }
        // Prefer PID for stability; if missing, try to resolve by bundle id
        var targetPid: pid_t?
        if let pid = lastNonSelfAppPid {
            targetPid = pid
        } else if let bid = lastNonSelfAppBundleId {
            if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bid }) {
                targetPid = app.processIdentifier
            }
        }
        guard let pid = targetPid else { return nil }
        return captureSelectedText(appPid: pid)
    }

    private func captureSelectedText(appPid: pid_t) -> String? {
        let appElement = AXUIElementCreateApplication(appPid)

        var focusedRef: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedRef)
        var focused: AXUIElement?
        if focusedResult == .success, let focusedRef, CFGetTypeID(focusedRef) == AXUIElementGetTypeID() {
            focused = (focusedRef as! AXUIElement)
        } else {
            // Fallback to focused window
            var windowRef: CFTypeRef?
            let windowResult = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowRef)
            if windowResult == .success, let windowRef, CFGetTypeID(windowRef) == AXUIElementGetTypeID() {
                focused = (windowRef as! AXUIElement)
            }
        }
        guard let focused else { return nil }

        func attribute(_ name: CFString) -> Any? {
            var value: CFTypeRef?
            let code = AXUIElementCopyAttributeValue(focused, name, &value)
            return code == .success ? value : nil
        }
        func attribute(_ name: String) -> Any? { attribute(name as CFString) }

        // Skip secure/protected fields
        if let isProtected = attribute("AXValueProtected") as? Bool, isProtected { return nil }
        if let role = attribute(kAXRoleAttribute) as? String, role == "AXSecureTextField" { return nil }

        // Prefer kAXSelectedTextAttribute when available
        if let selected = attribute(kAXSelectedTextAttribute) as? String, selected.isEmpty == false {
            return String(selected.prefix(maxChars))
        }

        // Fallback: derive from selected range
        if let rangeAny = attribute(kAXSelectedTextRangeAttribute) {
            let rangeCF = rangeAny as CFTypeRef
            if CFGetTypeID(rangeCF) == AXValueGetTypeID() {
                let rangeValue = rangeCF as! AXValue
                var range = CFRange()
                if AXValueGetType(rangeValue) == .cfRange, AXValueGetValue(rangeValue, .cfRange, &range) {
                    var out: CFTypeRef?
                    let code = AXUIElementCopyParameterizedAttributeValue(focused, kAXStringForRangeParameterizedAttribute as CFString, rangeValue, &out)
                    if code == .success, let str = out as? String, str.isEmpty == false {
                        return String(str.prefix(maxChars))
                    }
                }
            }
        }

        // As a final fallback, try the value attribute
        if let value = attribute(kAXValueAttribute) as? String, value.isEmpty == false {
            return String(value.prefix(maxChars))
        }
        if let attr = attribute(kAXValueAttribute) as? NSAttributedString, attr.string.isEmpty == false {
            return String(attr.string.prefix(maxChars))
        }
        return nil
    }
}

