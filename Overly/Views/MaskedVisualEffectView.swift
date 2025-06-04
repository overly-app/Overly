//
//  MaskedVisualEffectView.swift
//  Overly
//
//  Created by hypackel on 5/20/25.
//

import AppKit

// Custom NSVisualEffectView subclass to handle masking for rounded corners
class MaskedVisualEffectView: NSVisualEffectView {
    override func layout() {
        super.layout()
        applyCustomShapeMask()
    }

    // Method to apply the custom shape mask
    func applyCustomShapeMask() {
        let layer = CAShapeLayer()
        let bounds = self.bounds
        let cornerRadius: CGFloat = 12.0 // Define the corner radius to match macOS default

        // Create a path with rounded corners for all corners
        let path = NSBezierPath(roundedRect: bounds, xRadius: cornerRadius, yRadius: cornerRadius)

        layer.path = path.cgPath // Set the path
        self.layer?.mask = layer // Apply the mask to the view's layer

        // Configure the layer for proper border handling
        self.layer?.cornerRadius = cornerRadius
        self.layer?.masksToBounds = true
    }

    // Ensure the mask is updated when the view's bounds change
    override var bounds: NSRect {
        didSet {
            applyCustomShapeMask()
        }
    }
} 