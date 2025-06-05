//
//  ProgressBarView.swift
//  Overly
//
//  Created by hypackel on 5/20/25.
//

import SwiftUI

struct ProgressBarView: View {
    @Binding var isLoading: Bool
    @State private var progress: Double = 0.0
    @State private var animationTimer: Timer?
    @State private var isVisible: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 3)
                    
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: progress * geometry.size.width, height: 3)
                        .opacity(isVisible ? 1.0 : 0.0)
                        .animation(.easeInOut(duration: 0.2), value: isVisible)
                }
            }
        }
        .frame(height: 3)
        .onChange(of: isLoading) { oldValue, newValue in
            if newValue {
                startAnimation()
            } else {
                completeAnimation()
            }
        }
    }
    
    private func startAnimation() {
        progress = 0.0
        isVisible = true
        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if progress < 0.95 {
                let baseIncrement: Double = 0.015
                let accelerationFactor = 1.0 + (progress * 2.0)
                let increment = baseIncrement * accelerationFactor
                
                withAnimation(.linear(duration: 0.1)) {
                    progress += increment
                }
            }
        }
    }
    
    private func completeAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        
        withAnimation(.linear(duration: 0.8)) {
            progress = 1.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.1)) {
                isVisible = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                progress = 0.0
            }
        }
    }
} 