//
//  ServiceDropdownView.swift
//  Overly
//
//  Created by hypackel on 5/20/25.
//

import SwiftUI
import SettingsKit

struct ServiceDropdownView: View {
    @Binding var selectedProvider: ChatProvider?
    var dismiss: () -> Void
    @ObservedObject var settings: AppSettings
    var windowManager: WindowManager?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(settings.activeProviders.filter { $0.url != nil }) { provider in
                Button(action: {
                    selectedProvider = provider
                    dismiss()
                }) {
                    HStack {
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
                        Text(provider.name)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(selectedProvider?.id == provider.id ? Color.accentColor.opacity(0.2) : Color.clear)
                .cornerRadius(4)
                .onAppear {
                    if provider.url != nil && settings.faviconCache[provider.id] == nil {
                        Task {
                            await settings.fetchFavicon(for: provider)
                        }
                    }
                }
            }
            
            SettingsLink {
                HStack {
                    Image(systemName: "gearshape")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                    Text("Settings")
                    Spacer()
                }
                .contentShape(Rectangle())
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.clear)
                .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .onTapGesture {
                windowManager?.hideCustomWindow()
                dismiss()
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
        .shadow(radius: 5)
    }
} 