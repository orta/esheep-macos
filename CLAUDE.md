# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a macOS application project called "esheep" written in Swift. It's an Xcode project that implements a desktop pet sheep application, similar to the classic eSheep from the 1990s. The project includes a web-esheep submodule as a reference implementation and ports the JavaScript functionality to native Swift/Cocoa.

## Architecture

### Main Application (macOS/Swift)
- **esheep.xcodeproj**: Xcode project configuration
- **esheep/AppDelegate.swift**: Main application delegate that launches the sheep
- **esheep/ESheep.swift**: Main sheep controller managing animation and movement
- **esheep/ESheepWindow.swift**: Transparent overlay window for desktop display
- **esheep/ESheepView.swift**: Custom view handling sprite rendering and mouse interaction
- **esheep/ESheepAnimation.swift**: Animation data structures and frame management
- **esheep/ESheepAnimationLoader.swift**: XML parsing and sprite loading from base64 data
- **esheep/ViewController.swift**: Primary view controller (currently minimal)
- **esheep/Base.lproj/Main.storyboard**: UI layout using Interface Builder

### Submodule: web-esheep
Located in `vendor/web-esheep/`, this is a JavaScript implementation of the eSheep desktop pet that runs in web browsers. It serves as a reference for the behavior and animations.

## Development Commands

### Building the macOS App
- Open in Xcode: `open esheep.xcodeproj`
- Build: Use Xcode's build command (⌘B) or `xcodebuild` from command line
- Run: Use Xcode's run command (⌘R)

### Working with the web-esheep submodule
```bash
# Build the JavaScript version (requires yarn)
cd vendor/web-esheep
yarn install --dev
yarn build
```

## Key Development Notes

- The project targets macOS 15.0 (Sequoia) and uses Swift 5.0
- Code signing is configured with automatic signing
- The app uses the hardened runtime for macOS security
- Bundle identifier: `orta.io.esheep`
- Animation XML files (animation.xml, original.xml) should be included in the app bundle
- The app loads sprite images by decoding base64 PNG data from the XML at runtime

## Project Structure

- Swift source files use standard UIKit/AppKit patterns for macOS development
- The project follows MVC architecture with storyboard-based UI
- Assets are managed through Assets.xcassets
- Entitlements are configured in esheep.entitlements

## Git Submodules

The project includes web-esheep as a git submodule. When cloning or pulling:
```bash
git submodule update --init --recursive
```