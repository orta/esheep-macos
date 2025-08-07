//
//  ESheep.swift
//  esheep
//
//  Main sheep controller class
//

import Cocoa

class ESheep {
    private var window: ESheepWindow!
    private var sheepView: ESheepView!
    private var animations: [String: ESheepAnimation] = [:]
    private var currentAnimation: ESheepAnimation?
    private var currentAnimationStep: Int = 0
    private var animationTimer: Timer?
    private static var platformRefreshTimer: Timer?
    
    private var position: NSPoint = NSPoint(x: 100, y: 300)  // Start higher up
    private var isFlipped: Bool = true  // Start flipped since default movement is rightward
    private var isDragging: Bool = false
    
    private var tilesX: Int = 16
    private var tilesY: Int = 11
    private var frameWidth: CGFloat = 40
    private var frameHeight: CGFloat = 40
    
    // Physics properties
    private var velocityY: CGFloat = 0
    private let gravity: CGFloat = 0.5
    private let maxFallSpeed: CGFloat = 10
    private var isOnPlatform: Bool = false
    private var currentPlatform: ESheepPlatform?
    
    // Edge behavior properties
    private var isConfused: Bool = false
    private var confusedStartTime: TimeInterval = 0
    private let confusedDuration: TimeInterval = 2.0 // 2 seconds of confusion
    private var isAtEdge: Bool = false
    
    // Bottom teleport properties
    private var timeAtBottom: TimeInterval = 0
    private var isAtBottom: Bool = false
    private let bottomTeleportDelay: TimeInterval = 30.0 // 30 seconds
    
    // Platform manager - shared across all sheep instances
    private static let sharedPlatformManager = ESheepPlatformManager()
    private var platformManager: ESheepPlatformManager {
        return ESheep.sharedPlatformManager
    }
    
    // Shared settings
    private static var showPlatforms: Bool = true
    private static var frontmostAppOnly: Bool = false
    
    init() {
        setupWindow()
        setupView()
        loadAnimations()
    }
    
    private func setupWindow() {
        let frame = NSRect(x: position.x, y: position.y, width: frameWidth, height: frameHeight)
        window = ESheepWindow(contentRect: frame)
        window.contentView = NSView(frame: NSRect(origin: .zero, size: frame.size))
    }
    
    private func setupView() {
        sheepView = ESheepView(frame: NSRect(x: 0, y: 0, width: frameWidth, height: frameHeight))
        
        sheepView.onMouseDown = { [weak self] in
            self?.handleMouseDown()
        }
        
        sheepView.onMouseDragged = { [weak self] screenLocation in
            self?.handleMouseDragged(to: screenLocation)
        }
        
        sheepView.onMouseUp = { [weak self] in
            self?.handleMouseUp()
        }
        
        window.contentView?.addSubview(sheepView)
    }
    
    private func loadAnimations() {
        let loader = ESheepAnimationLoader()
        
        // Try to load from XML first
        loader.loadAnimations { [weak self] result in
            switch result {
            case .success(let data):
                print("ESheep: Successfully loaded XML data")
                self?.setupWithLoadedData(animations: [:], sprite: data.sprite, tilesX: data.tilesX, tilesY: data.tilesY)
            case .failure(let error):
                print("ESheep: Failed to load XML: \(error.localizedDescription)")
                // Fall back to default animations
                let fallbackResult = loader.loadDefaultAnimations()
                print("ESheep: Using fallback animations")
                self?.setupWithLoadedData(animations: fallbackResult.animations, sprite: fallbackResult.sprite, tilesX: fallbackResult.tilesX, tilesY: fallbackResult.tilesY)
            }
        }
    }
    
    private func setupWithLoadedData(animations: [String: ESheepAnimation], sprite: NSImage?, tilesX: Int, tilesY: Int) {
        print("ESheep: Setting up with sprite: \(sprite?.size ?? CGSize.zero), tiles: \(tilesX)x\(tilesY)")
        
        self.animations = animations
        self.tilesX = tilesX
        self.tilesY = tilesY
        
        if let sprite = sprite {
            print("ESheep: Using loaded sprite image")
            sheepView.setSpriteImage(sprite, tilesX: tilesX, tilesY: tilesY)
            frameWidth = sprite.size.width / CGFloat(tilesX)
            frameHeight = sprite.size.height / CGFloat(tilesY)
            
            print("ESheep: Frame size: \(frameWidth)x\(frameHeight)")
            
            // Update window and view size
            window.setContentSize(NSSize(width: frameWidth, height: frameHeight))
            sheepView.setFrameSize(NSSize(width: frameWidth, height: frameHeight))
        } else {
            print("ESheep: No sprite available, creating placeholder")
            // Create a placeholder image if sprite is not available
            createPlaceholderSprite()
        }
        
        // Start with walk animation (use default if no animations loaded from XML)
        let animationId = animations.isEmpty ? "0" : animations.keys.first ?? "0"
        print("ESheep: Starting animation with ID: \(animationId)")
        
        // Apply initial flip state (facing right)
        sheepView.setFlipped(isFlipped)
        
        startAnimation(withId: animationId)
    }
    
    private func createPlaceholderSprite() {
        print("ESheep: Creating placeholder sprite")
        // Create a simple colored rectangle as placeholder
        let image = NSImage(size: NSSize(width: 640, height: 440))
        image.lockFocus()
        
        // Fill with a bright background so we can see it
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 640, height: 440).fill()
        
        for row in 0..<tilesY {
            for col in 0..<tilesX {
                let rect = NSRect(x: CGFloat(col) * 40, y: CGFloat(row) * 40, width: 40, height: 40)
                let hue = CGFloat(row * tilesX + col) / CGFloat(tilesX * tilesY)
                NSColor(hue: hue, saturation: 0.7, brightness: 0.8, alpha: 1.0).setFill()
                rect.fill()
                
                NSColor.white.setStroke()
                let path = NSBezierPath(rect: rect)
                path.lineWidth = 2
                path.stroke()
            }
        }
        
        image.unlockFocus()
        print("ESheep: Placeholder created with size: \(image.size)")
        sheepView.setSpriteImage(image, tilesX: tilesX, tilesY: tilesY)
        
        // Make sure the frame dimensions are calculated
        frameWidth = 40
        frameHeight = 40
        window.setContentSize(NSSize(width: frameWidth, height: frameHeight))
        sheepView.setFrameSize(NSSize(width: frameWidth, height: frameHeight))
    }
    
    func start() {
        // Create platforms based on actual windows (only if not already initialized)
        if platformManager.allPlatforms.isEmpty {
            platformManager.createWindowPlatforms()
        }
        
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        
        // Position at random location on screen (start higher up)
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            position.x = CGFloat.random(in: 0...(screenFrame.width - frameWidth))
            position.y = CGFloat.random(in: screenFrame.height/2...(screenFrame.height - frameHeight))
            updateWindowPosition()
        }
        
        // Start platform refresh timer to update window positions periodically (only once)
        if ESheep.platformRefreshTimer == nil {
            ESheep.platformRefreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                ESheep.sharedPlatformManager.createWindowPlatforms()
            }
        }
    }
    
    private func startAnimation(withId animationId: String) {
        guard let animation = animations[animationId] else {
            print("Animation \(animationId) not found")
            return
        }
        
        currentAnimation = animation
        currentAnimationStep = 0
        
        // Start animation timer
        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateAnimation()
        }
    }
    
    private func updateAnimation() {
        guard let animation = currentAnimation else { return }
        
        if isDragging {
            // Show drag animation frame
            sheepView.setFrame(2)
            return
        }
        
        // Get current frame
        let frameIndex = animation.getFrameAtStep(currentAnimationStep)
        sheepView.setFrame(frameIndex)
        
        // Check for platform collision
        let sheepFrame = NSRect(x: position.x, y: position.y, width: frameWidth, height: frameHeight)
        let platformBelow = platformManager.getPlatformUnderSheep(sheepFrame: sheepFrame)
        
        // Apply gravity if not on a platform
        if platformBelow == nil {
            // Check if there's a platform we could fall onto
            let platformTarget = platformManager.getPlatformBelow(position: NSPoint(x: position.x + frameWidth/2, y: position.y))
            
            if platformTarget != nil || position.y > 0 {
                // Apply gravity - we're falling
                velocityY -= gravity
                velocityY = max(velocityY, -maxFallSpeed)
                position.y += velocityY
                
                // Check if we've landed on a platform
                if let platform = platformTarget {
                    if position.y <= platform.top {
                        position.y = platform.top
                        velocityY = 0
                        isOnPlatform = true
                        currentPlatform = platform
                        
                        // Switch to walk animation when landing
                        if animation.name == "fall" {
                            startAnimation(withId: "0")
                            return
                        }
                    }
                }
                
                // Check if we hit the ground
                if position.y <= 0 {
                    position.y = 0
                    velocityY = 0
                    isOnPlatform = false
                    currentPlatform = nil
                }
            }
        } else {
            // We're on a platform
            isOnPlatform = true
            currentPlatform = platformBelow
            velocityY = 0
        }
        
        // Update horizontal position based on movement
        let progress = CGFloat(currentAnimationStep) / CGFloat(animation.getTotalSteps())
        let moveX = animation.movement.startX + (animation.movement.endX - animation.movement.startX) * progress
        let moveY = animation.movement.startY + (animation.movement.endY - animation.movement.startY) * progress
        
        if !isDragging && velocityY == 0 {  // Only move horizontally if not falling
            if isFlipped {
                position.x += moveX  // When flipped (facing right), move right
            } else {
                position.x -= moveX  // When not flipped (facing left), move left
            }
            // Only apply vertical movement if we're on solid ground
            if isOnPlatform || position.y <= 0 {
                position.y += moveY
            }
            
            // Check if sheep is at the edge of a platform
            if isOnPlatform && currentPlatform != nil {
                let sheepCenter = position.x + frameWidth / 2
                let platformLeft = currentPlatform!.frame.minX
                let platformRight = currentPlatform!.frame.maxX
                let edgeThreshold: CGFloat = 20 // How close to edge before getting confused
                
                let nearLeftEdge = sheepCenter < platformLeft + edgeThreshold
                let nearRightEdge = sheepCenter > platformRight - edgeThreshold
                let atEdge = nearLeftEdge || nearRightEdge
                
                if atEdge && !isAtEdge && !isConfused {
                    // Just reached edge - start confusion
                    isAtEdge = true
                    isConfused = true
                    confusedStartTime = CFAbsoluteTimeGetCurrent()
                    print("ESheep: Sheep confused at platform edge")
                    
                    // Switch to a stationary animation (or create a confused animation)
                    // For now, we'll keep the current frame static
                    return
                } else if !atEdge {
                    isAtEdge = false
                }
                
                // Handle confusion timeout
                if isConfused {
                    let currentTime = CFAbsoluteTimeGetCurrent()
                    if currentTime - confusedStartTime >= confusedDuration {
                        // End confusion - make decision
                        isConfused = false
                        isAtEdge = false
                        
                        let shouldJump = Bool.random() // 50% chance to jump, 50% to turn around
                        
                        if shouldJump {
                            // Jump down
                            print("ESheep: Sheep decides to jump down")
                            isOnPlatform = false
                            currentPlatform = nil
                            velocityY = -1 // Small initial downward velocity
                            startAnimation(withId: "3") // Fall animation
                            return
                        } else {
                            // Turn around
                            print("ESheep: Sheep decides to turn around")
                            handleFlip()
                            // Continue with walk animation
                        }
                    } else {
                        // Still confused - don't move
                        return
                    }
                }
                
                // Check if sheep actually walked off the platform (past the edge threshold)
                if sheepCenter < platformLeft - 5 || sheepCenter > platformRight + 5 {
                    // Walked too far off - force fall
                    isOnPlatform = false
                    currentPlatform = nil
                    isConfused = false
                    isAtEdge = false
                    velocityY = 0
                    
                    // Switch to fall animation
                    startAnimation(withId: "3")
                    return
                }
            }
            
            // Check screen boundaries
            if let screen = NSScreen.main {
                let screenFrame = screen.visibleFrame
                
                // Handle screen edges
                if position.x <= 0 || position.x >= screenFrame.width - frameWidth {
                    // At horizontal edge - get confused like platform edges
                    if !isConfused && !isAtEdge {
                        isAtEdge = true
                        isConfused = true
                        confusedStartTime = CFAbsoluteTimeGetCurrent()
                        print("ESheep: Sheep confused at screen edge")
                        return
                    }
                    
                    // If confusion ended or forced movement
                    if !isConfused {
                        handleFlip()
                        position.x = max(0, min(position.x, screenFrame.width - frameWidth))
                    }
                }
                
                if position.y >= screenFrame.height - frameHeight {
                    position.y = screenFrame.height - frameHeight
                }
                
                // Handle bottom teleport
                let bottomThreshold: CGFloat = 50 // Consider "at bottom" if within 50 pixels of ground
                if position.y <= bottomThreshold && !isOnPlatform {
                    if !isAtBottom {
                        // Just reached bottom
                        isAtBottom = true
                        timeAtBottom = CFAbsoluteTimeGetCurrent()
                        print("ESheep: Sheep reached bottom, starting timer")
                    } else {
                        // Check if time to teleport
                        let currentTime = CFAbsoluteTimeGetCurrent()
                        if currentTime - timeAtBottom >= bottomTeleportDelay {
                            // Teleport to random position near top
                            position.x = CGFloat.random(in: 0...(screenFrame.width - frameWidth))
                            position.y = screenFrame.height * 0.8 // 80% up the screen
                            velocityY = 0
                            isAtBottom = false
                            print("ESheep: Teleporting sheep from bottom to top at x=\(position.x)")
                        }
                    }
                } else if position.y > bottomThreshold {
                    // No longer at bottom
                    isAtBottom = false
                }
            }
        }
        
        updateWindowPosition()
        
        // Move to next step
        currentAnimationStep += 1
        
        // Check if animation is complete
        if currentAnimationStep >= animation.getTotalSteps() {
            // Handle animation action if any
            if let action = animation.action {
                switch action {
                case "flip":
                    handleFlip()
                default:
                    break
                }
            }
            
            // Transition to next animation
            if let nextAnimationId = animation.getNextAnimation() {
                startAnimation(withId: nextAnimationId)
            } else {
                // Restart from beginning
                startAnimation(withId: "0")
            }
        }
    }
    
    private func handleFlip() {
        isFlipped = !isFlipped
        sheepView.setFlipped(isFlipped)
        print("ESheep: Flipped to \(isFlipped ? "right" : "left")")
    }
    
    private func updateWindowPosition() {
        window.setFrameOrigin(position)
    }
    
    private func handleMouseDown() {
        isDragging = true
        animationTimer?.invalidate()
    }
    
    private func handleMouseDragged(to screenLocation: NSPoint) {
        if isDragging {
            position = NSPoint(
                x: screenLocation.x - frameWidth / 2,
                y: screenLocation.y - frameHeight / 2
            )
            updateWindowPosition()
        }
    }
    
    private func handleMouseUp() {
        isDragging = false
        velocityY = 0  // Reset velocity after dragging
        
        // Check if we're on a platform
        let sheepFrame = NSRect(x: position.x, y: position.y, width: frameWidth, height: frameHeight)
        let platformBelow = platformManager.getPlatformUnderSheep(sheepFrame: sheepFrame)
        
        if platformBelow != nil {
            // On a platform - start walking
            isOnPlatform = true
            currentPlatform = platformBelow
            startAnimation(withId: "0")
        } else if position.y > 0 {
            // Not on platform and not on ground - start falling
            isOnPlatform = false
            currentPlatform = nil
            startAnimation(withId: "3")
        } else {
            // On ground - start walking
            isOnPlatform = false
            currentPlatform = nil
            startAnimation(withId: "0")
        }
    }
    
    func stop() {
        animationTimer?.invalidate()
        animationTimer = nil
        window.close()
    }
    
    static func stopAllSharedResources() {
        platformRefreshTimer?.invalidate()
        platformRefreshTimer = nil
    }
    
    static func setPlatformVisibility(_ visible: Bool) {
        showPlatforms = visible
        sharedPlatformManager.setPlatformVisibility(visible)
    }
    
    static func setFrontmostAppOnly(_ frontmostOnly: Bool) {
        frontmostAppOnly = frontmostOnly
        sharedPlatformManager.setFrontmostAppOnly(frontmostOnly)
        // Refresh platforms with new setting
        sharedPlatformManager.createWindowPlatforms()
    }
}