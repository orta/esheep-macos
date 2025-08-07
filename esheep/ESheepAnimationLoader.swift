//
//  ESheepAnimationLoader.swift
//  esheep
//
//  Loads and parses animation XML data
//

import Foundation
import Cocoa

class ESheepAnimationLoader: NSObject, XMLParserDelegate {
    
    // XML parsing state
    private var currentElement: String?
    private var currentAttributes: [String: String] = [:]
    private var currentCharacters = ""
    private var animations: [String: ESheepAnimation] = [:]
    private var spriteImage: NSImage?
    private var tilesX: Int = 1
    private var tilesY: Int = 1
    private var spawnData: [(x: String, y: String, nextAnimation: String, probability: Int)] = []
    
    func loadAnimations(completion: @escaping (Result<(animations: [String: ESheepAnimation], sprite: NSImage, tilesX: Int, tilesY: Int, spawns: [(x: String, y: String, nextAnimation: String, probability: Int)]), Error>) -> Void) {
        
        // Debug: List all resources in the bundle
        if let resourcePath = Bundle.main.resourcePath {
            do {
                let contents = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
                print("ESheep: Bundle contents: \(contents.filter { $0.contains("xml") })")
            } catch {
                print("ESheep: Could not list bundle contents: \(error)")
            }
        }
        
        // Try to load from bundle first
        let animationURL = Bundle.main.url(forResource: "animation", withExtension: "xml")
        let originalURL = Bundle.main.url(forResource: "original", withExtension: "xml")
        
        print("ESheep: Looking for animation.xml: \(animationURL?.path ?? "not found")")
        print("ESheep: Looking for original.xml: \(originalURL?.path ?? "not found")")
        
        guard let xmlURL = animationURL ?? originalURL else {
            completion(.failure(NSError(domain: "ESheep", code: 0, userInfo: [NSLocalizedDescriptionKey: "Animation XML not found in bundle"])))
            return
        }
        
        do {
            let data = try Data(contentsOf: xmlURL)
            self.parseAnimationXML(data: data, completion: completion)
        } catch {
            completion(.failure(error))
        }
    }
    
    private func parseAnimationXML(data: Data, completion: @escaping (Result<(animations: [String: ESheepAnimation], sprite: NSImage, tilesX: Int, tilesY: Int, spawns: [(x: String, y: String, nextAnimation: String, probability: Int)]), Error>) -> Void) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            
            let parser = XMLParser(data: data)
            parser.delegate = self
            
            if parser.parse() {
                if let sprite = self.spriteImage {
                    DispatchQueue.main.async {
                        completion(.success((self.animations, sprite, self.tilesX, self.tilesY, self.spawnData)))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(NSError(domain: "ESheep", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to load sprite image"])))
                    }
                }
            } else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "ESheep", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to parse XML"])))
                }
            }
        }
    }
    
    // For now, we'll create hardcoded animations based on the JavaScript version
    // In a full implementation, we'd parse the XML properly
    func loadDefaultAnimations() -> (animations: [String: ESheepAnimation], sprite: NSImage?, tilesX: Int, tilesY: Int) {
        // Reset state for fresh parsing
        spriteImage = nil
        tilesX = 16
        tilesY = 11
        
        // Try to load and decode the sprite from the XML file
        var sprite: NSImage? = loadSpriteFromXML()
        
        print("ESheep: loadDefaultAnimations - sprite loaded: \(sprite?.size ?? CGSize.zero)")
        
        // Fallback: try to load from web-esheep folder if available
        if sprite == nil {
            let spriteURL = URL(fileURLWithPath: "/Users/orta/dev/esheep/vendor/web-esheep/pets/esheep.png")
            if FileManager.default.fileExists(atPath: spriteURL.path) {
                sprite = NSImage(contentsOf: spriteURL)
            }
        }
        
        // Create some basic animations
        let walkAnimation = ESheepAnimation(
            id: "0",
            name: "walk",
            sequence: ESheepAnimationSequence(frames: [0, 1, 2, 3, 4, 5, 6, 7], repeatCount: 1, repeatFrom: 0),
            movement: ESheepMovement(startX: 3, startY: 0, endX: 3, endY: 0, startInterval: 0.2, endInterval: 0.2),
            transitions: [
                ESheepTransition(nextAnimationId: "0", probability: 50),
                ESheepTransition(nextAnimationId: "1", probability: 30),
                ESheepTransition(nextAnimationId: "2", probability: 20)
            ],
            hasBorder: true
        )
        
        let runAnimation = ESheepAnimation(
            id: "1",
            name: "run",
            sequence: ESheepAnimationSequence(frames: [8, 9, 10, 11, 12, 13], repeatCount: 2, repeatFrom: 0),
            movement: ESheepMovement(startX: 5, startY: 0, endX: 5, endY: 0, startInterval: 0.1, endInterval: 0.1),
            transitions: [
                ESheepTransition(nextAnimationId: "0", probability: 40),
                ESheepTransition(nextAnimationId: "1", probability: 30),
                ESheepTransition(nextAnimationId: "2", probability: 30)
            ],
            hasBorder: true
        )
        
        let idleAnimation = ESheepAnimation(
            id: "2",
            name: "idle",
            sequence: ESheepAnimationSequence(frames: [24, 25, 24, 25, 26, 27, 28, 29], repeatCount: 1, repeatFrom: 4),
            movement: ESheepMovement(startX: 0, startY: 0, endX: 0, endY: 0, startInterval: 0.5, endInterval: 0.5),
            transitions: [
                ESheepTransition(nextAnimationId: "0", probability: 60),
                ESheepTransition(nextAnimationId: "1", probability: 20),
                ESheepTransition(nextAnimationId: "3", probability: 20)
            ]
        )
        
        let fallAnimation = ESheepAnimation(
            id: "3",
            name: "fall",
            sequence: ESheepAnimationSequence(frames: [34, 35], repeatCount: 5, repeatFrom: 0),
            movement: ESheepMovement(startX: 0, startY: 3, endX: 0, endY: 5, startInterval: 0.1, endInterval: 0.1),
            transitions: [
                ESheepTransition(nextAnimationId: "0", probability: 100)
            ],
            hasGravity: true,
            hasBorder: true
        )
        
        animations["0"] = walkAnimation
        animations["1"] = runAnimation
        animations["2"] = idleAnimation
        animations["3"] = fallAnimation
        
        return (animations, sprite, tilesX, tilesY)
    }
    
    private func loadSpriteFromXML() -> NSImage? {
        // First try to load from the app bundle
        guard let xmlURL = Bundle.main.url(forResource: "animation", withExtension: "xml") ??
                            Bundle.main.url(forResource: "original", withExtension: "xml") else {
            print("ESheep: Animation XML file not found in app bundle")
            return nil
        }
        
        print("ESheep: Found XML file at: \(xmlURL.path)")
        
        do {
            let xmlData = try Data(contentsOf: xmlURL)
            
            // Create a separate sprite loader to avoid state conflicts
            let spriteLoader = XMLSpriteLoader()
            let parser = XMLParser(data: xmlData)
            parser.delegate = spriteLoader
            
            let parseResult = parser.parse()
            print("ESheep: XML parse result: \(parseResult)")
            
            // Even if parsing "fails", check if we got the sprite data we need
            if let sprite = spriteLoader.spriteImage {
                // Also update our own state
                self.tilesX = spriteLoader.tilesX
                self.tilesY = spriteLoader.tilesY
                print("ESheep: Successfully loaded sprite image: \(sprite.size), tiles: \(tilesX)x\(tilesY)")
                return sprite
            } else {
                print("ESheep: No sprite image found after parsing")
            }
        } catch {
            print("ESheep: Error loading XML: \(error)")
        }
        
        return nil
    }
    
    // MARK: - XMLParserDelegate Methods
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        currentAttributes = attributeDict
        currentCharacters = ""
        
        if elementName == "png" {
            // Will collect base64 data in foundCharacters
        } else if elementName == "image" {
            // Reset for new image data
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentCharacters += string.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        defer {
            currentElement = nil
            currentCharacters = ""
        }
        
        switch elementName {
        case "tilesx":
            if let value = Int(currentCharacters) {
                tilesX = value
            }
        case "tilesy":
            if let value = Int(currentCharacters) {
                tilesY = value
            }
        case "png":
            // Decode base64 PNG data
            print("ESheep: Found PNG data, length: \(currentCharacters.count)")
            if let imageData = Data(base64Encoded: currentCharacters) {
                print("ESheep: Successfully decoded base64 data, size: \(imageData.count) bytes")
                if let image = NSImage(data: imageData) {
                    spriteImage = image
                    print("ESheep: Successfully created NSImage: \(image.size)")
                } else {
                    print("ESheep: Failed to create NSImage from decoded data")
                }
            } else {
                print("ESheep: Failed to decode base64 PNG data")
            }
        default:
            break
        }
    }
}

// Separate class for just loading sprite data to avoid state conflicts
class XMLSpriteLoader: NSObject, XMLParserDelegate {
    var spriteImage: NSImage?
    var tilesX: Int = 16
    var tilesY: Int = 11
    private var currentElement: String?
    private var currentCharacters = ""
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        currentCharacters = ""
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentCharacters += string.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        defer {
            currentElement = nil
            currentCharacters = ""
        }
        
        switch elementName {
        case "tilesx":
            if let value = Int(currentCharacters) {
                tilesX = value
            }
        case "tilesy":
            if let value = Int(currentCharacters) {
                tilesY = value
            }
        case "png":
            // Decode base64 PNG data
            print("ESheep: XMLSpriteLoader found PNG data, length: \(currentCharacters.count)")
            if let imageData = Data(base64Encoded: currentCharacters) {
                print("ESheep: XMLSpriteLoader successfully decoded base64 data, size: \(imageData.count) bytes")
                if let image = NSImage(data: imageData) {
                    spriteImage = image
                    print("ESheep: XMLSpriteLoader successfully created NSImage: \(image.size)")
                } else {
                    print("ESheep: XMLSpriteLoader failed to create NSImage from decoded data")
                }
            } else {
                print("ESheep: XMLSpriteLoader failed to decode base64 PNG data")
            }
        default:
            break
        }
    }
}