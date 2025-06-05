//
//  KeybindRecorderView.swift
//  Overly
//
//  Created by hypackel on 5/25/25.
//

import SwiftUI
import AppKit
import HotKey

struct KeybindRecorderView: View {
    @Binding var key: Key
    @Binding var modifiers: NSEvent.ModifierFlags
    @Binding var isRecording: Bool
    @State private var recordedText = ""
    @State private var eventMonitor: Any?
    var showLabel: Bool = true
    
    var body: some View {
        HStack {
            if showLabel {
                Text("Toggle Window Shortcut:")
            }
            
            Text(isRecording ? "Recording... (Press keys)" : displayText)
                .foregroundColor(isRecording ? .red : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isRecording ? Color.red.opacity(0.1) : Color.gray.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isRecording ? Color.red : Color.gray, lineWidth: 1)
                        )
                )
            
            if isRecording {
                Button("Cancel") {
                    isRecording = false
                }
                .foregroundColor(.secondary)
            }
        }
        .onAppear {
            updateDisplayText()
        }
        .onChange(of: isRecording) { _, newValue in
            if newValue {
                startRecording()
            } else {
                stopRecording()
            }
        }
        .onDisappear {
            if isRecording {
                stopRecording()
            }
        }
    }
    
    private var displayText: String {
        return recordedText.isEmpty ? modifierString + keyString : recordedText
    }
    
    private var modifierString: String {
        var parts: [String] = []
        if modifiers.contains(.command) { parts.append("⌘") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        return parts.joined()
    }
    
    private var keyString: String {
        // Convert Key to display string
        switch key {
        case .a: return "A"
        case .b: return "B"
        case .c: return "C"
        case .d: return "D"
        case .e: return "E"
        case .f: return "F"
        case .g: return "G"
        case .h: return "H"
        case .i: return "I"
        case .j: return "J"
        case .k: return "K"
        case .l: return "L"
        case .m: return "M"
        case .n: return "N"
        case .o: return "O"
        case .p: return "P"
        case .q: return "Q"
        case .r: return "R"
        case .s: return "S"
        case .t: return "T"
        case .u: return "U"
        case .v: return "V"
        case .w: return "W"
        case .x: return "X"
        case .y: return "Y"
        case .z: return "Z"
        case .zero: return "0"
        case .one: return "1"
        case .two: return "2"
        case .three: return "3"
        case .four: return "4"
        case .five: return "5"
        case .six: return "6"
        case .seven: return "7"
        case .eight: return "8"
        case .nine: return "9"
        case .space: return "Space"
        case .slash: return "/"
        case .backslash: return "\\"
        case .comma: return ","
        case .period: return "."
        case .semicolon: return ";"
        case .quote: return "'"
        case .leftBracket: return "["
        case .rightBracket: return "]"
        case .minus: return "-"
        case .equal: return "="
        case .grave: return "`"
        default: return "?"
        }
    }
    
    private func updateDisplayText() {
        recordedText = modifierString + keyString
    }
    
    private func startRecording() {
        guard isRecording else { return }

        recordedText = ""
        
        // Create a local event monitor to capture key events
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            if self.isRecording {
                self.handleKeyEvent(event)
                return nil // Consume the event
            }
            return event
        }
    }
    
    private func stopRecording() {
        guard !isRecording else { return }

        updateDisplayText()
        
        // Remove the event monitor
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) {
        guard isRecording else { return }

        let eventModifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        
        if event.type == .keyDown {
            // Check if we have at least one meta key
            guard !eventModifiers.isEmpty else {
                // Show error or ignore - need at least one meta key
                return
            }
            
            // Try to create a Key from the keyCode
            guard let newKey = Key(carbonKeyCode: UInt32(event.keyCode)) else {
                return
            }
            
            // Validate that it's a valid key (letters, numbers, or common symbols)
            if isValidKey(newKey) {
                key = newKey
                modifiers = eventModifiers
                isRecording = false

                // Update AppSettings
                AppSettings.shared.updateToggleHotkey(key: key, modifiers: modifiers)
            }
        }
    }
    
    private func isValidKey(_ key: Key) -> Bool {
        // Check if the key is a letter, number, or common symbol
        switch key {
        case .a, .b, .c, .d, .e, .f, .g, .h, .i, .j, .k, .l, .m, .n, .o, .p, .q, .r, .s, .t, .u, .v, .w, .x, .y, .z,
             .zero, .one, .two, .three, .four, .five, .six, .seven, .eight, .nine,
             .space, .slash, .backslash, .comma, .period, .semicolon, .quote, .leftBracket, .rightBracket, .minus, .equal, .grave:
            return true
        default:
            return false
        }
    }
}

#Preview {
    @Previewable @State var key: Key = .j
    @Previewable @State var modifiers: NSEvent.ModifierFlags = [.command]
    @Previewable @State var isRecording = false
    
    KeybindRecorderView(key: $key, modifiers: $modifiers, isRecording: $isRecording)
        .padding()
} 