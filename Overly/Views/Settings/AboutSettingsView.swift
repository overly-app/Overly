//
//  AboutSettingsView.swift
//  Overly
//
//  Created by hypackel on 5/23/25.
//

import SwiftUI

struct AboutSettingsView: View {
    @State private var appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    @State private var buildNumber: String = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .center, spacing: 16) {
                    // App Icon
                    if let appIcon = NSApp.applicationIconImage {
                        Image(nsImage: appIcon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .cornerRadius(16)
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.blue.gradient)
                            .frame(width: 80, height: 80)
                            .overlay(
                                Text("O")
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundColor(.white)
                            )
                    }
                    
                    VStack(spacing: 8) {
                        Text("Overly")
                            .font(.system(size: 24, weight: .bold))
                        
                        Text("AI Chat Interface for macOS")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        
                        Text("Version \(appVersion) (\(buildNumber))")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "person.circle")
                            .foregroundColor(.blue)
                            .font(.system(size: 16))
                        
                        Text("Created by hypackel")
                            .font(.system(size: 14, weight: .medium))
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Button(action: {
                            if let url = URL(string: "https://github.com/hypackel") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            HStack {
                                Image(systemName: "link")
                                    .font(.system(size: 12))
                                Text("GitHub Profile")
                                    .font(.system(size: 12))
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            if let url = URL(string: "mailto:support@overly.app") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            HStack {
                                Image(systemName: "envelope")
                                    .font(.system(size: 12))
                                Text("Contact Support")
                                    .font(.system(size: 12))
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
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
                Text("Developer")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(.blue)
                            .font(.system(size: 16))
                        
                        Text("Legal & Licensing:")
                            .font(.system(size: 14, weight: .medium))
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Button(action: {
                            // Open privacy policy
                            if let url = URL(string: "https://overly.app/privacy") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            HStack {
                                Text("Privacy Policy")
                                    .font(.system(size: 12))
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            // Open terms of service
                            if let url = URL(string: "https://overly.app/terms") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            HStack {
                                Text("Terms of Service")
                                    .font(.system(size: 12))
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            // Open licenses
                            if let url = URL(string: "https://overly.app/licenses") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            HStack {
                                Text("Open Source Licenses")
                                    .font(.system(size: 12))
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
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
                Text("Legal")
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
    AboutSettingsView()
} 