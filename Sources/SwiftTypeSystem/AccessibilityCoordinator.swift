import Foundation
import AppKit
import ApplicationServices
import SwiftTypeCore

/// Coordinates Accessibility API permissions and instantaneous text replacement across macOS applications.
public final class AccessibilityCoordinator: @unchecked Sendable {
    public static let shared = AccessibilityCoordinator()
    private let lock = NSLock()

    public init() {}

    /// Checks if the application currently holds macOS Accessibility permissions.
    public var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Prompts the user for Accessibility permissions and optionally opens System Settings.
    public func requestPermissions(openSystemSettings: Bool = true) -> Bool {
        let promptKey = "AXTrustedCheckOptionPrompt" as CFString
        let options = [promptKey: kCFBooleanTrue!] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        if !trusted && openSystemSettings {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
        return trusted
    }

    /// Attempts to replace the just-completed word (`originalLength` characters before `completionChar`)
    /// with `correctedWord` instantaneously while preserving the cursor position and completion trigger.
    public func replaceWordInstantaneous(originalLength: Int, correctedWord: String, completionChar: String, useSimulatedKeystrokes: Bool = true) -> Bool {
        guard isTrusted else { return false }

        // Try direct AXUIElement text replacement if supported by the active application
        if tryDirectAXReplacement(originalLength: originalLength, correctedWord: correctedWord, completionChar: completionChar) {
            return true
        }

        // Fallback to high-speed Quartz CGEvent backspace and string posting
        if useSimulatedKeystrokes {
            return replaceViaSimulatedKeystrokes(originalLength: originalLength, correctedWord: correctedWord, completionChar: completionChar)
        }
        return false
    }

    // MARK: - Direct AXUIElement Replacement
    private func tryDirectAXReplacement(originalLength: Int, correctedWord: String, completionChar: String) -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        guard status == .success, let element = focusedElement else { return false }
        let axElement = element as! AXUIElement

        // Verify element is a text area/field
        var role: CFTypeRef?
        if AXUIElementCopyAttributeValue(axElement, kAXRoleAttribute as CFString, &role) == .success, let roleStr = role as? String {
            if roleStr != (kAXTextAreaRole as String) && roleStr != (kAXTextFieldRole as String) {
                return false
            }
        } else {
            return false
        }

        // Check if value attribute is settable and obtain current value & selected range
        var selectedRangeValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(axElement, kAXSelectedTextRangeAttribute as CFString, &selectedRangeValue) == .success,
           let rawRangeValue = selectedRangeValue, CFGetTypeID(rawRangeValue) == AXValueGetTypeID() {
            let rangeValue = rawRangeValue as! AXValue
            var range = CFRange()
            if let rangeType = AXValueType(rawValue: kAXValueCFRangeType), AXValueGetValue(rangeValue, rangeType, &range) {
                // If cursor is right after the completion char (range.location >= originalLength + completionChar.count)
                let totalRemove = originalLength + completionChar.count
                if range.location >= totalRemove {
                    var valueRef: CFTypeRef?
                    if AXUIElementCopyAttributeValue(axElement, kAXValueAttribute as CFString, &valueRef) == .success,
                       let fullText = valueRef as? String {
                        let nsText = fullText as NSString
                        let targetStart = range.location - totalRemove
                        if targetStart >= 0 && targetStart + totalRemove <= nsText.length {
                            let newText = nsText.replacingCharacters(in: NSRange(location: targetStart, length: totalRemove), with: correctedWord + completionChar)
                            
                            let setStatus = AXUIElementSetAttributeValue(axElement, kAXValueAttribute as CFString, newText as CFTypeRef)
                            if setStatus == .success {
                                // Restore caret right after the completion character
                                var newRange = CFRange(location: targetStart + correctedWord.count + completionChar.count, length: 0)
                                if let newRangeValue = AXValueCreate(rangeType, &newRange) {
                                    AXUIElementSetAttributeValue(axElement, kAXSelectedTextRangeAttribute as CFString, newRangeValue)
                                }
                                return true
                            }
                        }
                    }
                }
            }
        }
        return false
    }

    // MARK: - Quartz Simulated Keystroke Replacement
    private func replaceViaSimulatedKeystrokes(originalLength: Int, correctedWord: String, completionChar: String) -> Bool {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return false }

        // We need to backspace: originalLength + completionChar.count times
        let backspacesNeeded = originalLength + completionChar.count
        for _ in 0..<backspacesNeeded {
            // kVK_Delete = 0x33
            if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x33, keyDown: true),
               let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x33, keyDown: false) {
                keyDown.post(tap: .cghidEventTap)
                keyUp.post(tap: .cghidEventTap)
            }
        }

        // Post the corrected string + completion character
        let replacementString = correctedWord + completionChar
        let utf16Chars = Array(replacementString.utf16)
        
        if let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) {
            event.keyboardSetUnicodeString(stringLength: utf16Chars.count, unicodeString: utf16Chars)
            event.post(tap: .cghidEventTap)
        }
        if let eventUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
            eventUp.keyboardSetUnicodeString(stringLength: utf16Chars.count, unicodeString: utf16Chars)
            eventUp.post(tap: .cghidEventTap)
        }

        return true
    }
}
