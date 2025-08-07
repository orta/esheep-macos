//
//  ESheepWindow.swift
//  esheep
//
//  Transparent overlay window for displaying the sheep
//

import Cocoa

class ESheepWindow: NSWindow {
    
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect,
                   styleMask: [.borderless],
                   backing: .buffered,
                   defer: false)
        
        // Make window transparent and click-through
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        
        // Float above all other windows
        self.level = .floating
        
        // Allow window to be moved anywhere on screen
        self.isMovableByWindowBackground = false
        
        // Ignore mouse events except when clicking on the sheep
        self.ignoresMouseEvents = false
        
        // Don't show in mission control or app switcher
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        
        // Make sure window stays visible
        self.orderFrontRegardless()
    }
    
    override var canBecomeKey: Bool {
        return false
    }
    
    override var canBecomeMain: Bool {
        return false
    }
}