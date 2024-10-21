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
    private var model: VNCoreMLModel?
    private var detectionRequests: [VNCoreMLRequest] = []
    var onDetectionsUpdate: (([VNRecognizedObjectObservation]) -> Void)? // Callback to update the UI
    
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
        
        DispatchQueue.main.async {
            // Pass the detections to a view or controller for rendering
            for result in results {
                print("Detected object: \(result.labels.first?.identifier ?? "unknown") with confidence \(result.confidence)")
            }
            self.onDetectionsUpdate?(results)
        }
    }
}
