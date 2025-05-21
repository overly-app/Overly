//
//  BorderlessWindow.swift
//  Overly
//
//  Created by your_name on date.
//

import AppKit

class BorderlessWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
} 