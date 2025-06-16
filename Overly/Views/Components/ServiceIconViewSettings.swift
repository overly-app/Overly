//
//  ServiceIconViewSettings.swift
//  Overly
//
//  Created by AI Assistant on 1/27/25.
//

import SwiftUI

// Helper view to display service icons (same as ServiceSelectionView)
struct ServiceIconViewSettings: View {
    let provider: ChatProvider
    @ObservedObject var settings: AppSettings
    let size: CGFloat
    
    init(provider: ChatProvider, settings: AppSettings, size: CGFloat = 16) {
        self.provider = provider
        self.settings = settings
        self.size = size
    }
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.clear)
                .frame(width: size, height: size)
            
            Group {
                if let favicon = settings.faviconImage(for: provider) {
                    favicon
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else if provider.isSystemImage {
                     Image(systemName: provider.iconName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                     Image(provider.iconName)
                         .resizable()
                         .aspectRatio(contentMode: .fit)
                         .onAppear {
                             if provider.url != nil && settings.faviconCache[provider.id] == nil && settings.customProviders.contains(where: { $0.id == provider.id }) {
                                 Task {
                                     await settings.fetchFavicon(for: provider)
                                 }
                             }
                         }
                }
            }
            .frame(maxWidth: size, maxHeight: size)
        }
        .frame(width: size, height: size)
        .clipped()
    }
} 