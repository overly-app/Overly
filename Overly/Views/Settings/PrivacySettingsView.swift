//
//  PrivacySettingsView.swift
//  Overly
//
//  Created by hypackel on 5/23/25.
//

import SwiftUI

struct PrivacySettingsView: View {
    @AppStorage("analyticsEnabled") var analyticsEnabled: Bool = false
    @AppStorage("crashReportingEnabled") var crashReportingEnabled: Bool = true
    @AppStorage("dataCollectionEnabled") var dataCollectionEnabled: Bool = false
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "hand.raised")
                            .foregroundColor(.blue)
                            .font(.system(size: 16))
                        
                        Text("Control what data is shared and how the app behaves:")
                            .font(.system(size: 14))
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $analyticsEnabled) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Analytics & Usage Data")
                                    .font(.system(size: 14, weight: .medium))
                                Text("Help improve Overly by sharing anonymous usage statistics")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                        
                        Divider()
                        
                        Toggle(isOn: $crashReportingEnabled) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Crash Reporting")
                                    .font(.system(size: 14, weight: .medium))
                                Text("Automatically send crash reports to help fix bugs")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                        
                        Divider()
                        
                        Toggle(isOn: $dataCollectionEnabled) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Data Collection")
                                    .font(.system(size: 14, weight: .medium))
                                Text("Allow collection of feature usage data for improvements")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
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
                Text("Data & Privacy")
                    .font(.headline)
                    .foregroundColor(.primary)
            } footer: {
                Text("All data collection is anonymous and helps improve the app experience.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: $launchAtLogin) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Launch at Login")
                                .font(.system(size: 14, weight: .medium))
                            Text("Automatically start Overly when you log in to your Mac")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                    .onChange(of: launchAtLogin) { _, newValue in
                        // Here you would integrate with LaunchAtLogin or similar
                        // For now, just store the preference
                        UserDefaults.standard.set(newValue, forKey: "launchAtLogin")
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
                Text("Launch at login makes Overly available immediately when you start your Mac.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "shield.checkered")
                            .foregroundColor(.green)
                            .font(.system(size: 16))
                        
                        Text("Your privacy is important:")
                            .font(.system(size: 14, weight: .medium))
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Text("No personal data is stored on external servers")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Text("All settings and data remain on your device")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Text("You can disable all data sharing at any time")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Text("Chat conversations are not monitored or stored")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
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
                Text("Privacy Commitment")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#Preview {
    PrivacySettingsView()
} 