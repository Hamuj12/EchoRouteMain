//
//  BoundingBoxView.swift
//  EchoRouteMain
//
//  Created by Hamza Mujtaba on 10/20/24.
//


import UIKit
import Vision

class BoundingBoxView: UIView {
    private var boundingBoxes: [UIView] = []
    
    func showBoundingBoxes(for objects: [VNRecognizedObjectObservation]) {
        // Clear previous boxes
        for box in boundingBoxes {
            box.removeFromSuperview()
        }
        boundingBoxes.removeAll()
        
        for object in objects {
            let boundingBox = UIView(frame: VNImageRectForNormalizedRect(object.boundingBox, Int(bounds.width), Int(bounds.height)))
            boundingBox.layer.borderColor = UIColor.red.cgColor
            boundingBox.layer.borderWidth = 2.0
            
            let label = UILabel(frame: CGRect(x: boundingBox.frame.origin.x, y: boundingBox.frame.origin.y - 20, width: 100, height: 20))
            label.text = "\(object.labels.first?.identifier ?? "Unknown"): \(String(format: "%.2f", object.confidence))"
            label.textColor = .red
            label.font = UIFont.boldSystemFont(ofSize: 12)
            
            addSubview(boundingBox)
            addSubview(label)
            boundingBoxes.append(boundingBox)
        }
    }
}
