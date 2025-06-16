//
//  ProviderSettingsView.swift
//  Overly
//
//  Created by hypackel on 5/23/25.
//

import SwiftUI

struct ProviderSettingsView: View {
     @ObservedObject var settings = AppSettings.shared
     @State private var newProviderName: String = ""
     @State private var newProviderURLString: String = ""

     var body: some View {
         VStack(alignment: .leading, spacing: 20) {
             // Default Provider Section
             VStack(alignment: .leading, spacing: 12) {
                 Text("Default Provider")
                     .font(.headline)
                     .foregroundColor(.primary)
                 
                 VStack(alignment: .leading, spacing: 12) {
                     HStack {
                         Image(systemName: "star.fill")
                             .foregroundColor(.yellow)
                             .font(.system(size: 16))
                         
                         Text("Choose which provider loads when the app starts:")
                             .font(.system(size: 14))
                     }
                     
                     HStack {
                         Text("Default Startup Service:")
                             .font(.system(size: 14))
                             .foregroundColor(.secondary)
                         
                         CustomProviderDropdown(
                             title: "Default Provider", 
                             selectedProviderId: Binding(
                                 get: { settings.defaultProviderId ?? "none" },
                                 set: { newValue in
                                     if newValue == "none" {
                                         settings.setDefaultProvider(nil)
                                     } else {
                                         if let provider = settings.activeProviders.first(where: { $0.id == newValue }) {
                                             settings.setDefaultProvider(provider)
                                         }
                                     }
                                 }
                             ), 
                             providers: settings.activeProviders.filter { $0.url != nil }, 
                             settings: settings
                         )
                         
                         Spacer()
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
             }
             
             // Built-in Providers Section
             VStack(alignment: .leading, spacing: 12) {
                 Text("Built-in Providers")
                     .font(.headline)
                     .foregroundColor(.primary)
                 
                 FlowLayoutSettings(spacing: 8) {
                     ForEach(settings.allBuiltInProviders.filter { $0.url != nil }) { provider in
                         ProviderChipViewSettings(provider: provider, settings: settings, onDelete: deleteCustomProvider)
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
             }

             // Custom Providers Section
             if !settings.customProviders.isEmpty {
                 VStack(alignment: .leading, spacing: 12) {
                     Text("Custom Providers")
                         .font(.headline)
                         .foregroundColor(.primary)
                     
                     FlowLayoutSettings(spacing: 8) {
                         ForEach(settings.customProviders) { provider in
                             ProviderChipViewSettings(provider: provider, settings: settings, onDelete: deleteCustomProvider)
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
                 }
             }

             // Add Custom Provider Section
             VStack(alignment: .leading, spacing: 12) {
                 Text("Add Custom Provider")
                     .font(.headline)
                     .foregroundColor(.primary)
                     
                 VStack(spacing: 12) {
                     HStack(spacing: 8) {
                         TextField("Provider Name", text: $newProviderName)
                             .textFieldStyle(.roundedBorder)
                             .frame(maxWidth: .infinity)
                         
                         TextField("Provider URL", text: $newProviderURLString)
                             .textFieldStyle(.roundedBorder)
                             .frame(maxWidth: .infinity)
                         
                         Button("Add") {
                             addCustomProvider()
                         }
                         .buttonStyle(.borderedProminent)
                         .disabled(newProviderName.isEmpty || newProviderURLString.isEmpty)
                     }
                     .padding(.horizontal, 8)
                     .padding(.vertical, 8)
                 }
                 .frame(maxWidth: .infinity, alignment: .leading)
                 .background(Color(NSColor.controlBackgroundColor))
                 .cornerRadius(8)
                 .overlay(
                     RoundedRectangle(cornerRadius: 8)
                         .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                 )
             }
             
             Spacer()
         }
         .padding(20)
         .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
     }

     private func addCustomProvider() {
         guard !newProviderName.isEmpty && !newProviderURLString.isEmpty else { return }
         
         var urlString = newProviderURLString
         if !urlString.contains("://") {
             urlString = "https://" + urlString
         }

         guard let url = URL(string: urlString) else { return }
         
         let newProvider = ChatProvider(
             id: UUID().uuidString,
             name: newProviderName,
             url: url,
             iconName: "link",
             isSystemImage: true
         )
         
         settings.addCustomProvider(newProvider)
         
         Task {
             await settings.fetchFavicon(for: newProvider)
         }

         newProviderName = ""
         newProviderURLString = ""
     }

     func deleteCustomProvider(id: String) {
         settings.removeCustomProvider(id: id)
     }
}

#Preview {
    ProviderSettingsView()
}