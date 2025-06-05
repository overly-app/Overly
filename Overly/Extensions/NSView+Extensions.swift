//
//  NSView+Extensions.swift
//  Overly
//
//  Created by hypackel on 5/20/25.
//

import AppKit

extension NSView {
    func findSubview<T: NSView>(ofType type: T.Type) -> T? {
        for subview in subviews {
            if let found = subview as? T {
                return found
            }
            if let found = subview.findSubview(ofType: type) {
                return found
            }
        }
        return nil
    }
} 