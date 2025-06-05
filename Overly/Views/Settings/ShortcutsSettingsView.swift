//
//  ShortcutsSettingsView.swift
//  Overly
//
//  Created by hypackel on 5/23/25.
//

import SwiftUI
import HotKey

struct ShortcutsSettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            keyboardShortcutsSection
            tipsSection
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    
    private var keyboardShortcutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Keyboard Shortcuts")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 16) {
                headerView
                shortcutsListView
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
            )
            
            Text("Click on a shortcut field to record a new key combination. Press Escape to clear.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }
    
    private var headerView: some View {
        HStack {
            Image(systemName: "keyboard")
                .foregroundColor(.blue)
                .font(.system(size: 16))
            
            Text("Configure keyboard shortcuts for quick access:")
                .font(.system(size: 14))
        }
    }
    
    private var shortcutsListView: some View {
        VStack(alignment: .leading, spacing: 12) {
            toggleOverlyRow
            Divider()
            openSettingsRow
            Divider()
            quitApplicationRow
        }
    }
    
    private var toggleOverlyRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Toggle Overly")
                    .font(.system(size: 14, weight: .medium))
                Text("Show or hide the main window")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            KeybindRecorderView(
                key: $settings.toggleHotkeyKey,
                modifiers: $settings.toggleHotkeyModifiers,
                isRecording: .constant(false),
                showLabel: false
            )
        }
    }
    
    private var openSettingsRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Open Settings")
                    .font(.system(size: 14, weight: .medium))
                Text("Quickly access settings window")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            shortcutBadge(text: "⌘,")
        }
    }
    
    private var quitApplicationRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Quit Application")
                    .font(.system(size: 14, weight: .medium))
                Text("Exit the application")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            shortcutBadge(text: "⌘Q")
        }
    }
    
    private func shortcutBadge(text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .medium, design: .monospaced))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
            )
    }
    
    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tips")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 12) {
                tipsHeaderView
                tipsListView
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
            )
        }
    }
    
    private var tipsHeaderView: some View {
        HStack {
            Image(systemName: "info.circle")
                .foregroundColor(.orange)
                .font(.system(size: 16))
            
            Text("Tips for better shortcuts:")
                .font(.system(size: 14, weight: .medium))
        }
    }
    
    private var tipsListView: some View {
        VStack(alignment: .leading, spacing: 8) {
            tipRow(text: "Use modifier keys (⌘, ⌥, ⌃, ⇧) to avoid conflicts")
            tipRow(text: "Avoid system shortcuts like ⌘Space or ⌘Tab")
            tipRow(text: "Function keys (F1-F12) work well for global shortcuts")
        }
    }
    
    private func tipRow(text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    ShortcutsSettingsView()
} 