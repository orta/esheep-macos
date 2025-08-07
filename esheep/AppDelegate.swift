//
//  AppDelegate.swift
//  esheep
//
//  Created by Orta Therox on 06/08/2025.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    private var sheep: [ESheep] = []
    private var controlWindow: NSWindow?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        
        // Create control window
        setupControlWindow()
        
        // Start the first sheep
        addSheep()
    }
    
    private func setupControlWindow() {
        let contentRect = NSRect(x: 100, y: 100, width: 250, height: 150)
        controlWindow = NSWindow(contentRect: contentRect,
                                styleMask: [.titled, .closable, .miniaturizable],
                                backing: .buffered,
                                defer: false)
        
        controlWindow?.title = "eSheep Control"
        controlWindow?.level = .floating
        
        // Create "Add Sheep" button
        let addButton = NSButton(frame: NSRect(x: 75, y: 110, width: 100, height: 30))
        addButton.title = "Add Sheep"
        addButton.bezelStyle = .rounded
        addButton.target = self
        addButton.action = #selector(addSheepPressed)
        
        // Create "Show Window Platforms" toggle
        let showPlatformsToggle = NSButton(frame: NSRect(x: 20, y: 80, width: 180, height: 20))
        showPlatformsToggle.setButtonType(.switch)
        showPlatformsToggle.title = "Show Window Platforms"
        showPlatformsToggle.state = .on // Default to showing platforms
        showPlatformsToggle.target = self
        showPlatformsToggle.action = #selector(showPlatformsToggled)
        
        // Create "Only Frontmost App" toggle
        let frontmostAppOnlyToggle = NSButton(frame: NSRect(x: 20, y: 50, width: 180, height: 20))
        frontmostAppOnlyToggle.setButtonType(.switch)
        frontmostAppOnlyToggle.title = "Only Frontmost App"
        frontmostAppOnlyToggle.state = .off // Default to all windows
        frontmostAppOnlyToggle.target = self
        frontmostAppOnlyToggle.action = #selector(frontmostAppOnlyToggled)
        
        controlWindow?.contentView?.addSubview(addButton)
        controlWindow?.contentView?.addSubview(showPlatformsToggle)
        controlWindow?.contentView?.addSubview(frontmostAppOnlyToggle)
        controlWindow?.makeKeyAndOrderFront(nil)
    }
    
    @objc private func addSheepPressed() {
        addSheep()
    }
    
    @objc private func showPlatformsToggled(_ sender: NSButton) {
        let showPlatforms = sender.state == .on
        ESheep.setPlatformVisibility(showPlatforms)
        print("ESheep: Platform visibility set to \(showPlatforms)")
    }
    
    @objc private func frontmostAppOnlyToggled(_ sender: NSButton) {
        let frontmostAppOnly = sender.state == .on
        ESheep.setFrontmostAppOnly(frontmostAppOnly)
        print("ESheep: Frontmost app only mode set to \(frontmostAppOnly)")
    }
    
    private func addSheep() {
        let newSheep = ESheep()
        sheep.append(newSheep)
        newSheep.start()
        print("ESheep: Added sheep #\(sheep.count)")
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
        sheep.forEach { $0.stop() }
        ESheep.stopAllSharedResources()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }


}

