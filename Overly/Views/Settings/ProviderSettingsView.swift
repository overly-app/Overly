//
//  ProviderSettingsView.swift
//  Overly
//
//  Created by hypackel on 5/23/25.
//

import SwiftUI

// Chip-style provider view for settings (similar to ServiceSelectionView)
struct ProviderChipViewSettings: View {
    @Environment(\.colorScheme) var colorScheme
    let provider: ChatProvider
    @ObservedObject var settings: AppSettings
    let onDelete: (String) -> Void
    @State private var isRenaming: Bool = false
    @State private var newProviderName: String = ""

    var isSelected: Bool {
        settings.activeProviderIds.contains(provider.id)
    }
    
    var isDefaultProvider: Bool {
        settings.defaultProviderId == provider.id
    }

    var body: some View {
        Button(action: {
            if provider.url != nil {
                settings.toggleActiveProvider(id: provider.id)
            }
        }) {
            HStack(spacing: 8) {
                // Checkbox indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .font(.system(size: 14))
                
                // Service icon
                ServiceIconViewSettings(provider: provider, settings: settings)
                    .frame(width: 16, height: 16)
                
                // Service name (editable for custom providers)
                if isRenaming && settings.customProviders.contains(where: { $0.id == provider.id }) {
                    TextField("Provider Name", text: $newProviderName, onCommit: {
                        settings.updateCustomProviderName(id: provider.id, newName: newProviderName)
                        isRenaming = false
                    })
                    .textFieldStyle(.plain)
                    .foregroundColor(.primary)
                    .font(.system(size: 14))
                    .onAppear {
                        newProviderName = provider.name
                    }
                } else {
                    Text(provider.name)
                        .foregroundColor(isSelected ? .white : .primary)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .font(.system(size: 14))
                        .onTapGesture(count: 2) {
                            if settings.customProviders.contains(where: { $0.id == provider.id }) {
                                isRenaming = true
                                newProviderName = provider.name
                            }
                        }
                }
                
                // Default provider indicator
                if isDefaultProvider {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 12))
                }
                
                // Delete button for custom providers
                if settings.customProviders.contains(where: { $0.id == provider.id }) {
                    Button(action: {
                        onDelete(provider.id)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            .foregroundColor(.primary)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? .white : Color(NSColor.separatorColor), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(provider.url == nil) // Disable for settings provider
        .contextMenu {
            if settings.customProviders.contains(where: { $0.id == provider.id }) {
                Button("Delete", role: .destructive) {
                    onDelete(provider.id)
                }
                Button("Rename") {
                    isRenaming = true
                    newProviderName = provider.name
                }
            }
            if isSelected && provider.url != nil {
                if isDefaultProvider {
                    Button("Remove as Default") {
                        settings.setDefaultProvider(nil)
                    }
                } else {
                    Button("Set as Default") {
                        settings.setDefaultProvider(provider)
                    }
                }
            }
        }
    }
}

// Helper view to display service icons (same as ServiceSelectionView)
struct ServiceIconViewSettings: View {
    let provider: ChatProvider
    @ObservedObject var settings: AppSettings
    
    var body: some View {
        Group {
            if let favicon = settings.faviconImage(for: provider) {
                favicon
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
            } else if provider.isSystemImage {
                 Image(systemName: provider.iconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
            } else {
                 Image(provider.iconName)
                     .resizable()
                     .aspectRatio(contentMode: .fit)
                     .frame(width: 20, height: 20)
                     .onAppear {
                         if provider.url != nil && settings.faviconCache[provider.id] == nil && settings.customProviders.contains(where: { $0.id == provider.id }) {
                             Task {
                                 await settings.fetchFavicon(for: provider)
                             }
                         }
                     }
            }
        }
    }
}

// FlowLayout for wrapping chips (same as ServiceSelectionView)
struct FlowLayoutSettings: Layout {
    var spacing: CGFloat
    
    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        return layout(sizes: sizes, proposal: proposal).size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let offsets = layout(sizes: sizes, proposal: proposal).offsets
        
        for (offset, subview) in zip(offsets, subviews) {
            subview.place(at: CGPoint(x: bounds.minX + offset.x, y: bounds.minY + offset.y), proposal: .unspecified)
        }
    }
    
    private func layout(sizes: [CGSize], proposal: ProposedViewSize) -> (offsets: [CGPoint], size: CGSize) {
        let containerWidth = proposal.width ?? .infinity
        var offsets: [CGPoint] = []
        var currentPosition = CGPoint.zero
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0
        var maxY: CGFloat = 0
        
        for size in sizes {
            if currentPosition.x + size.width > containerWidth && currentPosition.x > 0 {
                // Move to next line
                currentPosition.x = 0
                currentPosition.y += lineHeight + spacing
                lineHeight = 0
            }
            
            offsets.append(currentPosition)
            lineHeight = max(lineHeight, size.height)
            currentPosition.x += size.width + spacing
            maxX = max(maxX, currentPosition.x - spacing)
            maxY = max(maxY, currentPosition.y + size.height)
        }
        
        return (offsets, CGSize(width: maxX, height: maxY))
    }
}

struct ProviderSettingsView: View {
     @ObservedObject var settings = AppSettings.shared
     @State private var newProviderName: String = ""
     @State private var newProviderURLString: String = ""

     var body: some View {
         Form {
             Section(header: Text("Default Provider")) {
                 VStack(alignment: .leading, spacing: 8) {
                     HStack {
                         Image(systemName: "star.fill")
                             .foregroundColor(.yellow)
                             .font(.system(size: 16))
                         
                         if let defaultProvider = settings.defaultProvider {
                             Text("**\(defaultProvider.name)** will load when the app starts")
                                 .font(.system(size: 14))
                         } else {
                             Text("No default provider set - first active provider will load")
                                 .font(.system(size: 14))
                                 .foregroundColor(.secondary)
                         }
                     }
                     
                     Text("Right-click on any active provider below to set it as default, or look for the ⭐ star indicator.")
                         .font(.system(size: 12))
                         .foregroundColor(.secondary)
                 }
                 .padding(.horizontal, 16)
                 .padding(.vertical, 12)
                 .background(Color(NSColor.controlBackgroundColor))
                 .cornerRadius(8)
                 .overlay(
                     RoundedRectangle(cornerRadius: 8)
                         .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                 )
             }
             .frame(maxWidth: .infinity)
             
             Section(header: Text("Built-in Providers")) {
                 FlowLayoutSettings(spacing: 8) {
                     ForEach(settings.allBuiltInProviders.filter { $0.url != nil }) { provider in
                         ProviderChipViewSettings(provider: provider, settings: settings, onDelete: deleteCustomProvider)
                     }
                 }
                 .padding(.horizontal, 16)
                 .padding(.vertical, 12)
                 .background(Color(NSColor.controlBackgroundColor))
                 .cornerRadius(8)
                 .overlay(
                     RoundedRectangle(cornerRadius: 8)
                         .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                 )
             }
             .frame(maxWidth: .infinity)

             if !settings.customProviders.isEmpty {
                 Section(header: Text("Custom Providers")) {
                     FlowLayoutSettings(spacing: 8) {
                         ForEach(settings.customProviders) { provider in
                             ProviderChipViewSettings(provider: provider, settings: settings, onDelete: deleteCustomProvider)
                         }
                     }
                     .padding(.horizontal, 16)
                     .padding(.vertical, 12)
                     .background(Color(NSColor.controlBackgroundColor))
                     .cornerRadius(8)
                     .overlay(
                         RoundedRectangle(cornerRadius: 8)
                             .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                     )
                 }
                 .frame(maxWidth: .infinity)
             }

             Section(header: Text("Add Custom Provider")) {
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
                 .background(Color(NSColor.controlBackgroundColor))
                 .cornerRadius(8)
                 .overlay(
                     RoundedRectangle(cornerRadius: 8)
                         .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                 )
             }
             .frame(maxWidth: .infinity)
         }
         .padding()
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