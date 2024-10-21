//
//  DetectionHandler.swift
//  EchoRouteMain
//
//  Created by Hamza Mujtaba on 10/20/24.
//


import Foundation
import CoreML
import Vision

class DetectionHandler {
    var onDetectionsUpdate: (([ObjectWithDepth]) -> Void)?
    private(set) var detectedObjects: [VNRecognizedObjectObservation] = []
    private var model: VNCoreMLModel?
    private var detectionRequests: [VNCoreMLRequest] = []
    init() {
        loadModel()
    }
    
    private func loadModel() {
        guard let yoloModel = try? yolov8m(configuration: MLModelConfiguration()).model else {
                    print("Failed to load YOLOv8 model.")
                    return
                }
        do {
            self.model = try VNCoreMLModel(for: yoloModel)
            
            let request = VNCoreMLRequest(model: self.model!) { request, error in
                if let error = error {
                    print("Error during detection: \(error)")
                    return
                }
                self.handleDetectionResults(request)
            }
            detectionRequests = [request]
        } catch {
            print("Error loading YOLOv8 model: \(error)")
        }
    }
    
    func detectObjects(in frame: CVPixelBuffer) {
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: frame, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try requestHandler.perform(self.detectionRequests)
            } catch {
                print("Failed to perform detection request: \(error)")
            }
        }
    }
    
    private func handleDetectionResults(_ request: VNRequest) {
        guard let results = request.results as? [VNRecognizedObjectObservation] else {
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.detectedObjects = results
            let objectsWithDepth = results.map { ObjectWithDepth(observation: $0, depth: nil) }
            self?.onDetectionsUpdate?(objectsWithDepth)
        }
    }
}
