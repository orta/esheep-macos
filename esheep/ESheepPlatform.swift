//
//  ESheepPlatform.swift
//  esheep
//
//  Platform windows that the sheep can walk on
//

import Cocoa

class ESheepPlatform {
    private let window: NSWindow
    private let view: NSView
    let frame: NSRect
    
    init(frame: NSRect) {
        self.frame = frame
        
        // Create a borderless window
        window = NSWindow(contentRect: frame,
                         styleMask: [.borderless],
                         backing: .buffered,
                         defer: false)
        
        // Configure window
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        
        // Create the view with more visible visualization for debugging
        view = NSView(frame: NSRect(origin: .zero, size: frame.size))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.green.withAlphaComponent(0.3).cgColor
        view.layer?.borderColor = NSColor.green.cgColor
        view.layer?.borderWidth = 2.0
        
        window.contentView = view
        window.orderFrontRegardless()
    }
    
    func show() {
        window.orderFrontRegardless()
    }
    
    func hide() {
        window.orderOut(nil)
    }
    
    // Check if a point is on top of this platform
    func isPointOnPlatform(_ point: NSPoint, margin: CGFloat = 5) -> Bool {
        // Check if the point is within the horizontal bounds
        if point.x >= frame.minX && point.x <= frame.maxX {
            // Check if the point is near the top of the platform (within margin)
            let platformTop = frame.maxY
            return abs(point.y - platformTop) <= margin
        }
        return false
    }
    
    // Check if a rectangle (the sheep) is standing on this platform
    func isSheepOnPlatform(sheepFrame: NSRect, margin: CGFloat = 5) -> Bool {
        // Check if sheep's bottom is near the platform's top
        let sheepBottom = sheepFrame.minY
        let platformTop = frame.maxY
        
        // Check vertical alignment (sheep is on or very close to platform top)
        if abs(sheepBottom - platformTop) <= margin {
            // Check horizontal overlap
            let sheepLeft = sheepFrame.minX
            let sheepRight = sheepFrame.maxX
            let platformLeft = frame.minX
            let platformRight = frame.maxX
            
            // Check if there's any horizontal overlap
            return !(sheepRight < platformLeft || sheepLeft > platformRight)
        }
        return false
    }
    
    // Get the Y position of the platform top
    var top: CGFloat {
        return frame.maxY
    }
}

// Manager class for all platforms
class ESheepPlatformManager {
    private var platforms: [ESheepPlatform] = []
    private var showPlatforms: Bool = true
    private var frontmostAppOnly: Bool = false
    
    func createRandomPlatforms(count: Int = 5) {
        // Clear existing platforms
        platforms.forEach { $0.hide() }
        platforms.removeAll()
        
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        
        for _ in 0..<count {
            // Random size
            let width = CGFloat.random(in: 100...300)
            let height = CGFloat(20) // Thin platforms
            
            // Random position
            let x = CGFloat.random(in: 0...(screenFrame.width - width))
            let y = CGFloat.random(in: 100...(screenFrame.height - 200)) // Keep away from very top and bottom
            
            let platformFrame = NSRect(x: x, y: y, width: width, height: height)
            let platform = ESheepPlatform(frame: platformFrame)
            platforms.append(platform)
        }
        
        print("ESheep: Created \(platforms.count) platforms")
    }
    
    func createWindowPlatforms() {
        // Clear existing platforms
        platforms.forEach { $0.hide() }
        platforms.removeAll()
        
        // Get list of all windows using Core Graphics
        // Try a different approach - get ALL windows including those we might not normally be able to read
        let listOptions: CGWindowListOption = [.optionOnScreenOnly]
        guard let windowList = CGWindowListCopyWindowInfo(listOptions, kCGNullWindowID) as? [[String: AnyObject]] else {
            print("ESheep: Failed to get window list")
            return
        }
        
        print("ESheep: Found \(windowList.count) total windows from system")
        var windowCount = 0
        
        // Get frontmost application if in frontmost app only mode
        var frontmostAppNames: Set<String> = []
        if frontmostAppOnly {
            if let frontmostApp = NSWorkspace.shared.frontmostApplication {
                if let appName = frontmostApp.localizedName {
                    frontmostAppNames.insert(appName)
                    
                    // Add common name variations based on bundle ID
                    if let bundleId = frontmostApp.bundleIdentifier {
                        switch bundleId {
                        case "com.microsoft.VSCode":
                            frontmostAppNames.insert("Visual Studio Code")
                        case "com.googlecode.iterm2":
                            frontmostAppNames.insert("iTerm")
                        default:
                            break
                        }
                    }
                    
                    print("ESheep: Frontmost app: \(appName) - looking for windows with names: \(frontmostAppNames.sorted())")
                } else {
                    print("ESheep: No frontmost application found")
                }
            } else {
                print("ESheep: Unable to get frontmost application")
            }
        }
        
        print("ESheep: Processing windows (frontmost app only: \(frontmostAppOnly))")
        
        for (index, windowInfo) in windowList.enumerated() {
            let appName = windowInfo[kCGWindowOwnerName as String] as? String ?? "Unknown"
            let windowName = windowInfo[kCGWindowName as String] as? String ?? ""
            let windowLayer = windowInfo[kCGWindowLayer as String] as? Int ?? 0
            
            print("ESheep: Processing window \(index + 1)/\(windowList.count): \(appName) - '\(windowName)' (layer: \(windowLayer))")
            
            // Skip system apps and UI elements
            let systemApps = ["Window Server", "Dock", "SystemUIServer", "ControlCenter", "NotificationCenter", "Spotlight"]
            if systemApps.contains(appName) {
                print("ESheep: Skipping system app: \(appName)")
                continue
            }
            
            // Skip our own control window
            if appName == "esheep" {
                print("ESheep: Skipping our own window")
                continue
            }
            
            // In frontmost app only mode, only show windows from the frontmost application
            if frontmostAppOnly {
                if !frontmostAppNames.contains(appName) {
                    print("ESheep: Skipping \(appName) - not the frontmost app")
                    continue
                }
                
                // Allow all layers for frontmost app (including menus if needed)
                print("ESheep: Accepting window from frontmost app \(appName) (named: '\(windowName)' layer: \(windowLayer))")
            }
            
            // Get window bounds
            if let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: AnyObject] {
                var windowBounds = CGRect.zero
                if CGRectMakeWithDictionaryRepresentation(boundsDict as CFDictionary, &windowBounds) {
                    print("ESheep: Window \(index + 1) - bounds: \(windowBounds)")
                    
                    // Use standard size filtering
                    let minSize: CGFloat = 50
                    if windowBounds.width >= minSize && windowBounds.height >= minSize {
                        print("ESheep: Window \(index + 1) - passed size filter (min: \(minSize))")
                        
                        // Convert from Quartz coordinates to AppKit screen coordinates
                        guard let screen = NSScreen.main else { continue }
                        let screenHeight = screen.frame.height
                        
                        // Convert window bounds to AppKit coordinates
                        let platformHeight: CGFloat = 10
                        let appKitWindowTop = screenHeight - windowBounds.maxY
                        let platformY = appKitWindowTop + windowBounds.height - platformHeight
                        
                        let platformFrame = NSRect(
                            x: windowBounds.minX,
                            y: platformY,
                            width: windowBounds.width,
                            height: platformHeight
                        )
                        
                        print("ESheep: Creating platform at \(platformFrame) for \(appName) window '\(windowName)'")
                        
                        let platform = ESheepPlatform(frame: platformFrame)
                        platforms.append(platform)
                        windowCount += 1
                    } else {
                        print("ESheep: Window \(index + 1) - filtered out (too small: \(windowBounds.width)x\(windowBounds.height), min: \(minSize))")
                    }
                } else {
                    print("ESheep: Window \(index + 1) - failed to parse bounds")
                }
            } else {
                print("ESheep: Window \(index + 1) - no bounds dictionary")
            }
        }
        
        print("ESheep: Created \(platforms.count) window platforms from \(windowCount) windows")
        
        // Update visibility based on current setting
        updatePlatformVisibility()
    }
    
    func setPlatformVisibility(_ visible: Bool) {
        showPlatforms = visible
        updatePlatformVisibility()
    }
    
    func setFrontmostAppOnly(_ frontmostOnly: Bool) {
        frontmostAppOnly = frontmostOnly
    }
    
    private func updatePlatformVisibility() {
        for platform in platforms {
            if showPlatforms {
                platform.show()
            } else {
                platform.hide()
            }
        }
    }
    
    // Check if sheep is on any platform
    func getPlatformUnderSheep(sheepFrame: NSRect) -> ESheepPlatform? {
        for platform in platforms {
            if platform.isSheepOnPlatform(sheepFrame: sheepFrame) {
                return platform
            }
        }
        return nil
    }
    
    // Check if there's a platform below the sheep (for gravity)
    func getPlatformBelow(position: NSPoint, within maxDistance: CGFloat = 1000) -> ESheepPlatform? {
        var closestPlatform: ESheepPlatform?
        var closestDistance: CGFloat = maxDistance
        
        for platform in platforms {
            // Check if platform is below this position
            if platform.frame.minX <= position.x && platform.frame.maxX >= position.x {
                let platformTop = platform.top
                if platformTop < position.y {
                    let distance = position.y - platformTop
                    if distance < closestDistance {
                        closestDistance = distance
                        closestPlatform = platform
                    }
                }
            }
        }
        
        return closestPlatform
    }
    
    // Get all platforms for collision checking
    var allPlatforms: [ESheepPlatform] {
        return platforms
    }
}