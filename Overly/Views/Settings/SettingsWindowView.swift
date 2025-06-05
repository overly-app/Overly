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
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                NavigationLink(value: "General") {
                    Label("General", systemImage: "gearshape")
                }
                .tag("General")
                
                NavigationLink(value: "Providers") {
                    Label("Providers", systemImage: "puzzlepiece")
                }
                .tag("Providers")
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            .listStyle(.sidebar)
        } detail: {
            Group {
                switch selectedTab {
                case "General":
                    GeneralSettingsView()
                case "Providers":
                    ProviderSettingsView()
                default:
                    GeneralSettingsView()
                }
            }
            .frame(minWidth: 500, minHeight: 400)
        }
        .frame(minWidth: 700, minHeight: 500)
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