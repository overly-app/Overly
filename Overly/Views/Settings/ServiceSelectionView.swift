import SwiftUI
import Foundation // Import Foundation for URL

// Custom button style to ensure proper color handling
struct OnboardingButtonStyleServiceSelection: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(colorScheme == .dark ? Color.white : Color.black)
            .foregroundColor(colorScheme == .dark ? Color.black : Color.white)
            .cornerRadius(8)
    }
}

// Chip-style provider view with checkbox styling
struct ProviderChipView: View {
    @Environment(\.colorScheme) var colorScheme
    let provider: ChatProvider
    @ObservedObject var settings: AppSettings
    let onDelete: (String) -> Void

    var isSelected: Bool {
        settings.activeProviderIds.contains(provider.id)
    }

    var body: some View {
        Button(action: {
            settings.toggleActiveProvider(id: provider.id)
        }) {
            HStack(spacing: 8) {
                // Checkbox indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .font(.system(size: 14))
                
                // Service icon
                ServiceIconView(provider: provider, settings: settings)
                    .frame(width: 16, height: 16)
                
                // Service name
                Text(provider.name)
                    .foregroundColor(isSelected ? .white : .primary)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .font(.system(size: 14))

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
        .contextMenu {
            if settings.customProviders.contains(where: { $0.id == provider.id }) {
                Button("Delete", role: .destructive) {
                    onDelete(provider.id)
                }
            }
        }
        .onAppear {
            if provider.url != nil && settings.faviconCache[provider.id] == nil {
                Task {
                    await settings.fetchFavicon(for: provider)
                }
            }
        }
    }
}

// Helper view for wrapping layout
struct WrappingHStack<Content: View>: View {
    let content: () -> Content
    let spacing: CGFloat
    
    init(spacing: CGFloat = 8, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }
    
    var body: some View {
        GeometryReader { geometry in
            self.generateContent(in: geometry)
        }
    }
    
    private func generateContent(in geometry: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero
        
        return ZStack(alignment: .topLeading) {
            ForEach(Array(extractViews().enumerated()), id: \.offset) { index, view in
                view
                    .alignmentGuide(.leading, computeValue: { d in
                        if (abs(width - d.width) > geometry.size.width) {
                            width = 0
                            height -= d.height + spacing
                        }
                        let result = width
                        if index == extractViews().count - 1 {
                            width = 0
                        } else {
                            width -= d.width + spacing
                        }
                        return result
                    })
                    .alignmentGuide(.top, computeValue: { _ in
                        let result = height
                        if index == extractViews().count - 1 {
                            height = 0
                        }
                        return result
                    })
            }
        }
    }
    
    private func extractViews() -> [AnyView] {
        // This is a simplified version - in practice you'd need a more sophisticated approach
        // For now, we'll use the chip views directly in the parent
        return []
    }
}

struct ServiceSelectionView: View {
    let onCompletion: () -> Void
    @ObservedObject var settings = AppSettings.shared
    @State private var newCustomProviderName: String = ""
    @State private var newCustomProviderURLString: String = ""

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("Select Your Providers")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Choose which AI services you'd like to use with Overly")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 20)

            ScrollView {
                VStack(spacing: 20) {
                    // Built-in Providers Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Built-in Providers")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        
                        // Wrapping layout for chips
                        FlowLayout(spacing: 8) {
                            ForEach(settings.allBuiltInProviders.filter { $0.id != "Settings" }) { provider in
                                ProviderChipView(provider: provider, settings: settings, onDelete: deleteCustomProvider)
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

                    // Custom Providers Section
                    if !settings.customProviders.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Custom Providers")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            
                            FlowLayout(spacing: 8) {
                                ForEach(settings.customProviders) { provider in
                                    ProviderChipView(provider: provider, settings: settings, onDelete: deleteCustomProvider)
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

                    // Add Custom Provider Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Add Custom Provider")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        
                        HStack(spacing: 8) {
                            TextField("Provider Name", text: $newCustomProviderName)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: .infinity)
                            
                            TextField("Provider URL", text: $newCustomProviderURLString)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: .infinity)
                            
                            Button("Add") {
                                addCustomProvider()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(newCustomProviderName.isEmpty || newCustomProviderURLString.isEmpty)
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
                .padding(.horizontal, 20)
            }

            Spacer()

            // Continue Button
            Button("Finish Setup") {
                settings.saveSettings()
                onCompletion()
            }
            .buttonStyle(OnboardingButtonStyleServiceSelection())
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(width: 800, height: 500)
    }

    private func addCustomProvider() {
        guard !newCustomProviderName.isEmpty && !newCustomProviderURLString.isEmpty else { return }
        
        var urlString = newCustomProviderURLString
        if !urlString.contains("://") {
            urlString = "https://" + urlString
        }

        guard let url = URL(string: urlString) else { return }
        
        let newProvider = ChatProvider(
            id: UUID().uuidString,
            name: newCustomProviderName,
            url: url,
            iconName: "link",
            isSystemImage: true
        )
        
        settings.addCustomProvider(newProvider)
        
        Task {
            await settings.fetchFavicon(for: newProvider)
        }

        newCustomProviderName = ""
        newCustomProviderURLString = ""
    }

    func deleteCustomProvider(id: String) {
        settings.customProviders.removeAll { $0.id == id }
        settings.activeProviderIds.remove(id)
        settings.faviconCache.removeValue(forKey: id)
        settings.saveSettings()
    }
}

// FlowLayout for wrapping chips
struct FlowLayout: Layout {
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

// Helper view to display service icons based on type and cache
struct ServiceIconView: View {
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

#Preview {
    ServiceSelectionView(onCompletion: {
        print("Service Selection Finished!")
    })
} 