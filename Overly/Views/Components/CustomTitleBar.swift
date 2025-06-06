//
//  CustomTitleBar.swift
//  Overly
//
//  Created by hypackel on 5/20/25.
//

import SwiftUI

struct CustomTitleBar: View {
    let window: NSWindow?
    @Binding var selectedProvider: ChatProvider?
    @ObservedObject var settings: AppSettings
    var windowManager: WindowManager?
    @Binding var useNativeChat: Bool
    @State private var showingDropdown = false
    @State private var isHoveringButton = false
    @State private var isHoveringDropdown = false
    @State private var closeDropdownWorkItem: DispatchWorkItem? = nil

    private let hoverDelay: Double = 0.1

    var body: some View {
        HStack {
            Text("Overly")
                .foregroundColor(.white)
                .font(.headline)
            
            Spacer()
            
            // Native Chat Toggle
            HStack(spacing: 8) {
                Button(action: { useNativeChat = false }) {
                    Image(systemName: "globe")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(useNativeChat ? .secondary : .white)
                }
                .buttonStyle(.plain)
                .help("Web Mode")
                
                Button(action: { useNativeChat = true }) {
                    Image(systemName: "brain")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(useNativeChat ? .white : .secondary)
                }
                .buttonStyle(.plain)
                .help("Native Chat")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.2))
            )
            
            Spacer()
            
            Button(action: {
                showingDropdown.toggle()
                closeDropdownWorkItem?.cancel()
            }) {
                if let provider = selectedProvider {
                    if let favicon = settings.faviconImage(for: provider) {
                        favicon
                             .resizable()
                             .aspectRatio(contentMode: .fit)
                             .frame(width: 20, height: 20)
                    } else if provider.isSystemImage {
                         Image(systemName: provider.iconName)
                              .resizable()
                              .frame(width: 20, height: 20)
                    } else {
                         Image(provider.iconName)
                              .resizable()
                              .frame(width: 20, height: 20)
                    }
                } else {
                    Image(systemName: "questionmark.circle")
                        .resizable()
                        .frame(width: 20, height: 20)
                }
            }
            .buttonStyle(.plain)
            .onHover { isHovering in
                isHoveringButton = isHovering
                if isHovering {
                    showingDropdown = true
                    closeDropdownWorkItem?.cancel()
                } else if !isHoveringDropdown {
                    startCloseDropdownDelay()
                }
            }
            .popover(isPresented: $showingDropdown, arrowEdge: .top) {
                ServiceDropdownView(
                    selectedProvider: $selectedProvider,
                    dismiss: {
                        showingDropdown = false
                        closeDropdownWorkItem?.cancel()
                    },
                    settings: settings,
                    windowManager: windowManager
                )
                .onHover { isHovering in
                    isHoveringDropdown = isHovering
                    if isHovering {
                        closeDropdownWorkItem?.cancel()
                    } else if !isHoveringButton {
                        startCloseDropdownDelay()
                    }
                }
            }
        }
        .padding(.horizontal)
        .frame(height: 30)
        .background(.thinMaterial)
        .gesture(TapGesture(count: 2).onEnded({
            handleDoubleClick()
        }))
    }
    
    private func startCloseDropdownDelay() {
        closeDropdownWorkItem?.cancel()
        let task = DispatchWorkItem {
            showingDropdown = false
        }
        closeDropdownWorkItem = task
        DispatchQueue.main.asyncAfter(deadline: .now() + hoverDelay, execute: task)
    }
    
    private func handleDoubleClick() {
        guard let window = window else { return }
        
        let screenFrame = NSScreen.main?.visibleFrame ?? NSScreen.main?.frame ?? .zero
        let windowFrame = window.frame
        let isMaximized = windowFrame.size.width >= screenFrame.size.width * 0.95 && windowFrame.size.height >= screenFrame.size.height * 0.95

        let targetFrame: NSRect
        if isMaximized {
            let initialWidth: CGFloat = 600
            let initialHeight: CGFloat = 500
            let newOriginX = screenFrame.midX - initialWidth / 2
            let newOriginY = screenFrame.midY - initialHeight / 2
            targetFrame = NSRect(x: newOriginX, y: newOriginY, width: initialWidth, height: initialHeight)
        } else {
            targetFrame = screenFrame
        }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(targetFrame, display: true)
        }, completionHandler: nil)
    }
} 