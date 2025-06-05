//
//  AppearanceSettingsView.swift
//  Overly
//
//  Created by hypackel on 5/23/25.
//

import SwiftUI

struct AppearanceSettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @AppStorage("windowOpacity") var windowOpacity: Double = 0.95
    @AppStorage("cornerRadius") var cornerRadius: Double = 12.0
    @AppStorage("showInDock") var showInDock: Bool = false
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "paintbrush")
                            .foregroundColor(.blue)
                            .font(.system(size: 16))
                        
                        Text("Choose your preferred appearance theme:")
                            .font(.system(size: 14))
                    }
                    
                    Picker("Appearance", selection: Binding(
                        get: { 
                            let appearance = NSApp.effectiveAppearance.name
                            return appearance == .darkAqua ? "dark" : "light"
                        },
                        set: { newValue in
                            switch newValue {
                            case "light":
                                NSApp.appearance = NSAppearance(named: .aqua)
                            case "dark":
                                NSApp.appearance = NSAppearance(named: .darkAqua)
                            default:
                                NSApp.appearance = nil
                            }
                        }
                    )) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(.segmented)
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
            } header: {
                Text("Theme")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Window Opacity:")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("\(Int(windowOpacity * 100))%")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        
                        Slider(value: $windowOpacity, in: 0.5...1.0, step: 0.05)
                            .accentColor(.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Corner Radius:")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("\(Int(cornerRadius))px")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        
                        Slider(value: $cornerRadius, in: 0...20, step: 1)
                            .accentColor(.blue)
                    }
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
            } header: {
                Text("Window Appearance")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: $showInDock) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Show in Dock")
                                .font(.system(size: 14, weight: .medium))
                            Text("Display the app icon in the Dock")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                    .onChange(of: showInDock) { _, newValue in
                        NSApp.setActivationPolicy(newValue ? .regular : .accessory)
                    }
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
            } header: {
                Text("System Integration")
                    .font(.headline)
                    .foregroundColor(.primary)
            } footer: {
                Text("Changes to Dock visibility will take effect immediately.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#Preview {
    AppearanceSettingsView()
} 