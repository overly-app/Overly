//
//  SettingsWindowView.swift
//  Overly
//
//  Created by hypackel on 5/23/25.
//

import SwiftUI

struct SettingsWindowView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = "General"
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: $selectedTab) {
                NavigationLink(value: "General") {
                    Label("General", systemImage: "gearshape")
                }
                .tag("General")
                
                NavigationLink(value: "Providers") {
                    Label("Providers", systemImage: "puzzlepiece")
                }
                .tag("Providers")
                
                NavigationLink(value: "API") {
                    Label("API Keys", systemImage: "key")
                }
                .tag("API")
                
                NavigationLink(value: "Appearance") {
                    Label("Appearance", systemImage: "eye")
                }
                .tag("Appearance")
                
                NavigationLink(value: "Shortcuts") {
                    Label("Shortcuts", systemImage: "keyboard")
                }
                .tag("Shortcuts")
                
                NavigationLink(value: "About") {
                    Label("About", systemImage: "info.circle")
                }
                .tag("About")
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            .listStyle(.sidebar)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            Group {
                switch selectedTab {
                case "General":
                    GeneralSettingsView()
                case "Providers":
                    ProviderSettingsView()
                case "API":
                    APISettingsView()
                case "Appearance":
                    AppearanceSettingsView()
                case "Shortcuts":
                    ShortcutsSettingsView()
                case "About":
                    AboutSettingsView()
                default:
                    GeneralSettingsView()
                }
            }
            .navigationTitle(selectedTab)
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button(action: {
                        withAnimation {
                            columnVisibility = columnVisibility == .all ? .detailOnly : .all
                        }
                    }) {
                        Image(systemName: "sidebar.left")
                    }
                }
            }
            .frame(minWidth: 500, minHeight: 400)
        }
        .frame(width: 700, height: 500)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { _ in
            NSApp.setActivationPolicy(.accessory)
            NSApp.deactivate()
        }
    }
}

#Preview {
    SettingsWindowView()
} 