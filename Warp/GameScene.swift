//
//  GameScene.swift
//  Warp
//
//  Created by Mark McArthey on 2/19/17.
//  Copyright © 2017 Mark McArthey. All rights reserved.
//

import SpriteKit
import GameplayKit
import CoreMotion

// Declare `-` operator overload function
//func -(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
//    return CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
//}

class GameScene: SKScene, SKPhysicsContactDelegate {
    
    let debug = true
    
    struct DebugLines {
        var lines = [SKShapeNode]()
        mutating func push(_ item: SKShapeNode) {
            lines.append(item)
        }
        mutating func pop() -> SKShapeNode? {
            if lines.count > 0 {
                return lines.removeLast()
            }
            return nil
        }
    }
    
    var contentCreated = false
    var debugLines = DebugLines()
    
    let BorderCategory: UInt32 = 0x1 << 0
    let ShipCategory: UInt32 = 0x1 << 1
    
    private var lastUpdateTime : TimeInterval = 0
    private var warpNode : SKShapeNode?
    private var ship : SKSpriteNode?
    
    // Accelerometer Data
    let motionManager = CMMotionManager()
    
    override func sceneDidLoad() {
        
        self.lastUpdateTime = 0
        
        let joystick = AnalogJoystick(diameters: (100, 50))
        
        let borderBody = SKPhysicsBody(edgeLoopFrom: self.frame)
        borderBody.friction = 1
        borderBody.categoryBitMask = BorderCategory
        
        self.physicsBody = borderBody
        physicsWorld.gravity = CGVector(dx: 0.0, dy: 0.0)
        physicsWorld.speed = 0.5
        let gravity = SKFieldNode.radialGravityField()
        gravity.strength = 8
        gravity.falloff = 0.5
        gravity.animationSpeed = 0.5
        gravity.region = SKRegion(radius: 100.0)
        
        physicsWorld.contactDelegate = self
        
        let label = SKLabelNode(text: "Warp")
        label.fontSize = 60
        label.fontColor = SKColor.lightText
        label.position = CGPoint(x: frame.size.width/2-label.fontSize/2, y: frame.size.height/2)
        
        label.alpha = 0.0
        label.run(SKAction.fadeIn(withDuration: 2.0))
        
        let w = (self.size.height + self.size.width) * 0.05
        self.warpNode = SKShapeNode.init(rectOf: CGSize.init(width: w, height: w), cornerRadius: w * 0.4)
        
        if let warpNode = self.warpNode {

            warpNode.lineWidth = 2.5
            warpNode.position = CGPoint(x: frame.size.width/2, y: frame.size.height/2)
            warpNode.addChild(gravity)
            
            let rotate = SKAction.rotate(byAngle: CGFloat(M_PI), duration: 1)
            let pulseUp = SKAction.scale(to: 1.02, duration: 0.2)
            let pulseDown = SKAction.scale(to: 0.98, duration: 0.2)
            
            warpNode.run(SKAction.repeatForever(
                SKAction.group([rotate, SKAction.sequence([pulseUp, pulseDown])])))
        }
    }
    func createContent() {
        self.ship = SKSpriteNode(color: SKColor.green, size: CGSize(width: frame.size.width*0.03, height: frame.size.height*0.04))
        if let ship = self.ship {
            ship.name = "ship"
            ship.physicsBody = SKPhysicsBody(rectangleOf: ship.frame.size)
            ship.physicsBody!.mass = 0.02
            ship.physicsBody!.linearDamping = 0.25
            ship.physicsBody!.angularDamping = 0.25
            ship.physicsBody!.isDynamic = true
            ship.physicsBody!.restitution = 0
            ship.physicsBody!.usesPreciseCollisionDetection = true
            
            ship.physicsBody!.categoryBitMask = ShipCategory
            ship.physicsBody!.contactTestBitMask = BorderCategory
            
            ship.position = CGPoint(x: 100, y: 100)
        }
    }
    
    override func didMove(to view: SKView) {
        super.didMove(to: view)
        
        if (!self.contentCreated) {
            
            self.createContent()
            self.contentCreated = true
            
            self.addChild(self.warpNode!)
            self.addChild(self.ship!)
            
            motionManager.startAccelerometerUpdates()
        }
    }
    
    func applyGravity(forUpdate currentTime: CFTimeInterval) {
        
        let shipPosition = ship!.position
        let warpPosition = warpNode!.position
        
        // Calculate distance to warp and resultant gravitational strength
        var warpPull = CGVector.init(dx: shipPosition.x - warpPosition.x, dy: shipPosition.y - warpPosition.y)
        let vLength = warpPull.length()
        let strength = vLength*0.1 > 10 ? 0 : 10-vLength*0.1
        let forceVector = warpPull.normalize() * strength
        let impulseVector = forceVector * -1.0
        
        //ship?.physicsBody!.applyForce(impulseVector)
        physicsWorld.gravity = impulseVector
        //ship?.physicsBody!.applyImpulse(CGVector(dx: 3, dy: 1)) // TESTING
        
        if debug {
            //print("Ship position: \(shipPosition)")
            //print("Warp position: \(warpPosition)")
            //print("Warp Vector: \(warpPull)")
            print("Vector length: \(vLength)")
            print("strength: \(strength)")
            print("Force Vector: \(forceVector)")
        }
        self.lastUpdateTime = currentTime
    }
    
    func debugDrawLines(from source: CGPoint, to target: CGPoint) {
        let pathToDraw:CGMutablePath = CGMutablePath()
        pathToDraw.move(to: source)
        pathToDraw.addLine(to: target)
        
        let line = SKShapeNode()
        line.path = pathToDraw
        line.strokeColor = SKColor.red
        line.lineWidth = 2
        
        // remove the old line before drawing the new
        let previousLine = debugLines.pop()
        previousLine?.removeFromParent()
        
        debugLines.push(line)
        self.addChild(line)
    }
    
    func didBegin(_ contact: SKPhysicsContact) {
        var firstBody: SKPhysicsBody
        var secondBody: SKPhysicsBody
        
        if contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask {
            firstBody = contact.bodyA
            secondBody = contact.bodyB
        } else {
            firstBody = contact.bodyB
            secondBody = contact.bodyA
        }
        
        // apply a small vector force in the opposite direction to avoid items getting "stuck" against the wall due to rounding errors in the native physics engine
        if firstBody.categoryBitMask == ShipCategory && secondBody.categoryBitMask == BorderCategory {
            let strengthY = 1.0 * ((firstBody.node?.position.y)! < self.frame.height / 2 ? 1 : -1)
            let strengthX = 1.0 * ((firstBody.node?.position.x)! < self.frame.width / 2 ? 1 : -1)
            let body = firstBody.node?.physicsBody!
            body?.applyImpulse(CGVector(dx: strengthX, dy: strengthY))
        }
    }
    
    func processUserMotion(forUpdate currentTime: CFTimeInterval) {
        
        // Only if the loop value is of type SKSpriteNode is it bound to the constant
        if let ship = childNode(withName: "ship") as? SKSpriteNode {
            if let data = motionManager.accelerometerData {
                // probably reversed because of landscape mode
                if fabs(data.acceleration.x) > 0.2 || fabs(data.acceleration.y) > 0.2{
                    ship.physicsBody!.applyForce(CGVector(dx: 20*CGFloat(data.acceleration.x), dy: 20*CGFloat(data.acceleration.y)))
                    if debug {
                        print("Acceleration X: \(data.acceleration.x)")
                        print("Acceleration Y: \(data.acceleration.y)")
                    }
                }
            }
            if debug {
                debugDrawLines(from: ship.position, to: (warpNode?.position)!)
            }
        }
        
    }
    
    override func update(_ currentTime: TimeInterval) {
        if (self.lastUpdateTime == 0) {
            self.lastUpdateTime = currentTime
        }
        
        // Calculate time since last update
        let dt = currentTime - self.lastUpdateTime
        
//        if (dt > 0.2) { // apply gravity less often
//            applyGravity(forUpdate: currentTime)
//        }
        if (dt > 0.05) { // allow user to have more control than the gravity effect is applied
            processUserMotion(forUpdate: currentTime)
        }
    }
}
