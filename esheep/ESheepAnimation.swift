//
//  ESheepAnimation.swift
//  esheep
//
//  Animation data structures and parsing
//

import Foundation

struct ESheepFrame {
    let index: Int
    let duration: TimeInterval
}

struct ESheepAnimationSequence {
    let frames: [Int]
    let repeatCount: Int
    let repeatFrom: Int
}

struct ESheepMovement {
    let startX: CGFloat
    let startY: CGFloat
    let endX: CGFloat
    let endY: CGFloat
    let startInterval: TimeInterval
    let endInterval: TimeInterval
}

struct ESheepTransition {
    let nextAnimationId: String
    let probability: Int
}

class ESheepAnimation {
    let id: String
    let name: String
    let sequence: ESheepAnimationSequence
    let movement: ESheepMovement
    let transitions: [ESheepTransition]
    let action: String?
    let hasGravity: Bool
    let hasBorder: Bool
    
    init(id: String,
         name: String,
         sequence: ESheepAnimationSequence,
         movement: ESheepMovement,
         transitions: [ESheepTransition],
         action: String? = nil,
         hasGravity: Bool = false,
         hasBorder: Bool = false) {
        self.id = id
        self.name = name
        self.sequence = sequence
        self.movement = movement
        self.transitions = transitions
        self.action = action
        self.hasGravity = hasGravity
        self.hasBorder = hasBorder
    }
    
    func getNextAnimation() -> String? {
        if transitions.isEmpty {
            return nil
        }
        
        let totalProbability = transitions.reduce(0) { $0 + $1.probability }
        let random = Int.random(in: 0..<totalProbability)
        
        var accumulated = 0
        for transition in transitions {
            accumulated += transition.probability
            if random < accumulated {
                return transition.nextAnimationId
            }
        }
        
        return transitions.last?.nextAnimationId
    }
    
    func getFrameAtStep(_ step: Int) -> Int {
        let totalFrames = sequence.frames.count
        let extendedSteps = totalFrames + (totalFrames - sequence.repeatFrom) * sequence.repeatCount
        
        if step < totalFrames {
            return sequence.frames[step]
        } else if sequence.repeatFrom == 0 {
            return sequence.frames[step % totalFrames]
        } else {
            let adjustedStep = (step - sequence.repeatFrom) % (totalFrames - sequence.repeatFrom)
            return sequence.frames[sequence.repeatFrom + adjustedStep]
        }
    }
    
    func getTotalSteps() -> Int {
        return sequence.frames.count + (sequence.frames.count - sequence.repeatFrom) * sequence.repeatCount
    }
}