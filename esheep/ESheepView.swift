//
//  ESheepView.swift
//  esheep
//
//  View that displays and animates the sheep sprite
//

import Cocoa

class ESheepView: NSView {
    private var spriteImage: NSImage?
    private var currentFrame: Int = 0
    private var tilesX: Int = 16
    private var tilesY: Int = 11
    private var frameWidth: CGFloat = 0
    private var frameHeight: CGFloat = 0
    private var isFlippedImage: Bool = false
    private var isDragging: Bool = false
    private var dragOffset: NSPoint = .zero
    
    var onMouseDown: (() -> Void)?
    var onMouseDragged: ((NSPoint) -> Void)?
    var onMouseUp: (() -> Void)?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.masksToBounds = true
    }
    
    func setSpriteImage(_ image: NSImage, tilesX: Int, tilesY: Int) {
        self.spriteImage = image
        self.tilesX = tilesX
        self.tilesY = tilesY
        self.frameWidth = image.size.width / CGFloat(tilesX)
        self.frameHeight = image.size.height / CGFloat(tilesY)
        
        // Set the view size to match a single frame
        self.setFrameSize(NSSize(width: frameWidth, height: frameHeight))
        
        needsDisplay = true
    }
    
    func setFrame(_ frameIndex: Int) {
        self.currentFrame = frameIndex
        needsDisplay = true
    }
    
    func setFlipped(_ flipped: Bool) {
        self.isFlippedImage = flipped
        print("ESheepView: Set flipped to \(flipped)")
        needsDisplay = true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let sprite = spriteImage else { 
            print("ESheepView: No sprite image available for drawing")
            return 
        }
        
        // Only log occasionally to reduce console spam
        if currentFrame == 0 {
            print("ESheepView: Drawing with flip=\(isFlippedImage)")
        }
        
        let context = NSGraphicsContext.current?.cgContext
        context?.saveGState()
        
        // Apply horizontal flip transformation if needed
        if isFlippedImage {
            context?.translateBy(x: bounds.width, y: 0)
            context?.scaleBy(x: -1, y: 1)
        }
        
        // Calculate which part of the sprite sheet to draw
        let col = currentFrame % tilesX
        let row = currentFrame / tilesX
        
        // NSImage coordinate system: origin at bottom-left, so we need to flip the Y coordinate
        let sourceRect = NSRect(
            x: CGFloat(col) * frameWidth,
            y: sprite.size.height - CGFloat(row + 1) * frameHeight,
            width: frameWidth,
            height: frameHeight
        )
        
        // Draw the specific frame from the sprite sheet
        sprite.draw(in: bounds, from: sourceRect, operation: .sourceOver, fraction: 1.0)
        
        context?.restoreGState()
    }
    
    override func mouseDown(with event: NSEvent) {
        isDragging = true
        let locationInWindow = event.locationInWindow
        let locationInView = convert(locationInWindow, from: nil)
        dragOffset = locationInView
        onMouseDown?()
    }
    
    override func mouseDragged(with event: NSEvent) {
        if isDragging {
            let locationInScreen = NSEvent.mouseLocation
            onMouseDragged?(locationInScreen)
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        isDragging = false
        onMouseUp?()
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
}
