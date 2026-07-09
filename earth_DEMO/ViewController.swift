//
//  ViewController.swift
//  earth_DEMO
//
//  Created by sy on 2026/7/8.
//

import UIKit
import SceneKit

class ViewController: UIViewController {

    // Scene graph hierarchy:
    // earthGroup         ← user pan rotates this (viewing angle)
    //   └── tiltNode     ← fixed 23.4° axis tilt (eulerAngles.z)
    //       └── earthNode ← auto-rotates around local Y; ellipsoid scale
    //           ├── cloudNode
    //           └── atmosphereNode

    private let scnView = SCNView()
    private let scene = SCNScene()
    private let earthGroup = SCNNode()
    private let tiltNode = SCNNode()
    private let earthNode = SCNNode()
    private let cloudNode = SCNNode()
    private let atmosphereNode = SCNNode()
    private var displayLink: CADisplayLink?
    private var isDragging = false
    private var resetTimer: Timer?
    private let coordLabel = UILabel()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupScene()
        setupCamera()
        setupLighting()
        setupEarth()
        setupClouds()
        setupAtmosphere()
        setupStarfield()
        setupCoordinateLabel()
        setupGestures()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startAutoRotation()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        displayLink?.invalidate()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
}

// MARK: - Scene Setup

extension ViewController {

    private func setupScene() {
        scnView.frame = view.bounds
        scnView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scnView.scene = scene
        scnView.backgroundColor = UIColor(red: 0.01, green: 0.01, blue: 0.04, alpha: 1)
        view.addSubview(scnView)
    }

    private func setupCamera() {
        let camera = SCNCamera()
        camera.zFar = 200
        camera.zNear = 0.1
        camera.fieldOfView = 45
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 5.5)
        scene.rootNode.addChildNode(cameraNode)
    }

    private func setupLighting() {
        // Simple directional light (sun)
        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light?.type = .directional
        sun.light?.color = UIColor(white: 0.95, alpha: 1)
        sun.light?.intensity = 1000
        sun.position = SCNVector3(8, 10, 8)
        scene.rootNode.addChildNode(sun)
    }
}

// MARK: - Earth

extension ViewController {

    private func setupEarth() {
        // Build hierarchy: scene → earthGroup (pan) → tiltNode (23.4°) → earthNode (rotate + ellipsoid)
        tiltNode.eulerAngles.z = Float(23.4 * .pi / 180)
        tiltNode.addChildNode(earthNode)
        earthGroup.addChildNode(tiltNode)
        scene.rootNode.addChildNode(earthGroup)

        // Geometry
        let sphere = SCNSphere(radius: 1.0)
        sphere.segmentCount = 96

        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = UIColor(red: 0.15, green: 0.3, blue: 0.6, alpha: 1)
        material.metalness.contents = 0.02
        material.roughness.contents = 0.6
        sphere.materials = [material]

        earthNode.geometry = sphere
        // Subtle ellipsoid (oblate spheroid) — visibly oval but natural
        earthNode.scale = SCNVector3(1.0, 1.0, 1.0)

        loadTexture(for: material)
    }

    private func loadTexture(for material: SCNMaterial) {
        let urlString = "https://www.solarsystemscope.com/textures/download/2k_earth_daymap.jpg"
        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { [weak material] data, _, error in
            guard let data = data, let image = UIImage(data: data), let material else { return }
            DispatchQueue.main.async {
                material.diffuse.contents = image
            }
        }.resume()
    }
}

// MARK: - Clouds & Atmosphere

extension ViewController {

    private func setupClouds() {
        let sphere = SCNSphere(radius: 1.012)
        sphere.segmentCount = 64

        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = UIColor(white: 1, alpha: 0.25)
        material.transparency = 0.25
        material.roughness.contents = 0.8
        material.metalness.contents = 0.0
        material.isDoubleSided = true
        sphere.materials = [material]

        cloudNode.geometry = sphere
        cloudNode.scale = earthNode.scale
        earthNode.addChildNode(cloudNode)

        let urlString = "https://www.solarsystemscope.com/textures/download/2k_earth_clouds.jpg"
        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { [weak material] data, _, error in
            guard let data = data, let image = UIImage(data: data), let material else { return }
            DispatchQueue.main.async {
                material.diffuse.contents = image
                material.transparency = 0.4
            }
        }.resume()
    }

    private func setupAtmosphere() {
        let sphere = SCNSphere(radius: 1.06)
        sphere.segmentCount = 48

        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = UIColor(red: 0.35, green: 0.6, blue: 1.0, alpha: 0.1)
        material.isDoubleSided = true
        sphere.materials = [material]

        atmosphereNode.geometry = sphere
        atmosphereNode.scale = earthNode.scale
        earthNode.addChildNode(atmosphereNode)
    }
}

// MARK: - Starfield

extension ViewController {

    private func setupStarfield() {
        for _ in 0..<600 {
            let star = SCNNode()
            let r = CGFloat.random(in: 0.008...0.04)
            star.geometry = SCNSphere(radius: r)
            let b = CGFloat.random(in: 0.5...1.0)
            let tint: CGFloat = .random(in: 0.85...1.0)
            let color = UIColor(red: tint, green: tint * 0.95, blue: 1.0, alpha: 1)
            star.geometry?.firstMaterial?.diffuse.contents = color
            star.geometry?.firstMaterial?.emission.contents = color.withAlphaComponent(0.5)

            let theta = Float.random(in: 0...(2 * .pi))
            let phi = Float.random(in: 0...(.pi))
            let radius = Float.random(in: 25...90)
            star.position = SCNVector3(
                radius * sin(phi) * cos(theta),
                radius * cos(phi),
                radius * sin(phi) * sin(theta)
            )
            scene.rootNode.addChildNode(star)
        }
    }
}

// MARK: - Coordinate Display

extension ViewController {

    private func setupCoordinateLabel() {
        coordLabel.textColor = UIColor.white
        coordLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 15, weight: .medium)
        coordLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        coordLabel.textAlignment = .center
        coordLabel.layer.cornerRadius = 8
        coordLabel.layer.masksToBounds = true
        coordLabel.text = "Tap the Earth"
        coordLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(coordLabel)

        NSLayoutConstraint.activate([
            coordLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            coordLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            coordLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),
            coordLabel.heightAnchor.constraint(equalToConstant: 40)
        ])
    }

    private func showCoordinate(lat: Double, lon: Double) {
        let latStr = String(format: "%.2f°%@", abs(lat), lat >= 0 ? "N" : "S")
        let lonStr = String(format: "%.2f°%@", abs(lon), lon >= 0 ? "E" : "W")

        let text = "\(latStr), \(lonStr)"
        coordLabel.text = text
        print("Tapped coordinate: \(latStr), \(lonStr)")
    }
}

// MARK: - Auto Rotation & Gestures

extension ViewController {

    private func startAutoRotation() {
        displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink?.add(to: .main, forMode: .common)
    }

    @objc private func tick() {
        guard !isDragging else { return }
        // Self-rotation around Earth's own axis (which is tilted 23.4° by tiltNode)
        earthNode.eulerAngles.y += 0.004
        // Clouds drift faster than surface
        cloudNode.eulerAngles.y += 0.0015
    }

    private func setupGestures() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        scnView.addGestureRecognizer(pan)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        scnView.addGestureRecognizer(tap)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: scnView)

        switch gesture.state {
        case .began:
            resetTimer?.invalidate()
            resetTimer = nil
            isDragging = true
        case .changed:
            let sensitivity: Float = 0.008
            // Rotate the entire earth group (changes viewing angle)
            earthGroup.eulerAngles.y += Float(translation.x) * sensitivity
            // Vertical rotation with constraint to avoid flipping
            let tilt = earthGroup.eulerAngles.x + Float(translation.y) * sensitivity * 0.4
            earthGroup.eulerAngles.x = max(-0.6, min(0.6, tilt))
            gesture.setTranslation(.zero, in: scnView)
        case .ended, .cancelled:
            isDragging = false
            // Start 3s timer to reset to original rotation
            resetTimer?.invalidate()
            resetTimer = Timer.scheduledTimer(timeInterval: 3.0, target: self, selector: #selector(resetRotation), userInfo: nil, repeats: false)
        default:
            break
        }
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: scnView)

        let hitResults = scnView.hitTest(location, options: [
            .rootNode: earthNode
        ])

        guard let hit = hitResults.first else { return }

        // Convert to earthNode's local coordinate space (accounts for tilt + rotation)
        let localPoint = earthNode.convertPosition(hit.worldCoordinates, from: nil)
        let radius = sqrt(localPoint.x * localPoint.x + localPoint.y * localPoint.y + localPoint.z * localPoint.z)
        let lat = asin(Double(localPoint.y / radius)) * 180 / .pi
        let lon = atan2(Double(localPoint.x), Double(localPoint.z)) * 180 / .pi

        showCoordinate(lat: lat, lon: lon)
    }

    @objc private func resetRotation() {
        resetTimer = nil
        // Animate earthGroup back to original orientation
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 1.2
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeOut)
        earthGroup.eulerAngles = SCNVector3(0, 0, 0)
        SCNTransaction.commit()
    }
}
