import AVFoundation
import CoreImage
import UIKit
import os.log
import Combine

class LiDARDepth: NSObject, ObservableObject {
    private var captureSession: AVCaptureSession  // Shared session
    private var depthOutput: AVCaptureDepthDataOutput!
    private var videoOutput: AVCaptureVideoDataOutput!
    private var outputSynchronizer: AVCaptureDataOutputSynchronizer!

    private let sessionQueue = DispatchQueue(label: "LiDARDepthSessionQueue")
    
    @Published var distanceToCenter: Float?  // Distance in meters to the center object
    @Published var isRunning: Bool = false  // Track session state

    // Initialize with a shared AVCaptureSession
    init(session: AVCaptureSession) {
        self.captureSession = session
        super.init()
        initialize()
    }

    private func initialize() {
        sessionQueue.async { [self] in
            configureSession()
        }
    }

    private func configureSession() {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        guard let device = AVCaptureDevice.default(.builtInLiDARDepthCamera, for: .video, position: .back) else {
            logger.error("LiDAR device unavailable.")
            return
        }

        do {
            let deviceInput = try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(deviceInput) {
                captureSession.addInput(deviceInput)
                logger.debug("LiDAR device input added.")
            }

            // Configure video output
            videoOutput = AVCaptureVideoDataOutput()
            videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
            if captureSession.canAddOutput(videoOutput) {
                captureSession.addOutput(videoOutput)
                logger.debug("Video output added.")
            }

            // Configure depth output
            depthOutput = AVCaptureDepthDataOutput()
            depthOutput.setDelegate(self, callbackQueue: sessionQueue)
            depthOutput.isFilteringEnabled = true  // Optional filtering
            if captureSession.canAddOutput(depthOutput) {
                captureSession.addOutput(depthOutput)
                logger.debug("Depth output added.")
            }

            // Synchronize video and depth data
            outputSynchronizer = AVCaptureDataOutputSynchronizer(dataOutputs: [videoOutput, depthOutput])
            outputSynchronizer.setDelegate(self, queue: sessionQueue)
            logger.debug("Output synchronizer configured.")
        } catch {
            logger.error("Error configuring session: \(error.localizedDescription)")
        }
    }

    func start() async {
        sessionQueue.async { [self] in
            if !captureSession.isRunning {
                captureSession.startRunning()
                DispatchQueue.main.async {
                    self.isRunning = true
                }
            }
        }
    }

    func stop() {
        sessionQueue.async { [self] in
            if captureSession.isRunning {
                captureSession.stopRunning()
                DispatchQueue.main.async {
                    self.isRunning = false
                }
            }
        }
    }

    private func updateDistance(with depthData: AVDepthData) {
        let depthMap = depthData.depthDataMap

        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)

        // Center pixel coordinates
        let centerX = width / 2
        let centerY = height / 2

        // Lock the pixel buffer and access the base address
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        guard let pointer = CVPixelBufferGetBaseAddress(depthMap)?.assumingMemoryBound(to: Float32.self) else {
            logger.error("Failed to get base address.")
            return
        }

        // Get the distance at the center pixel
        let distance = pointer[centerY * width + centerX]

        // Update the published distance on the main thread
        DispatchQueue.main.async {
            self.distanceToCenter = distance > 0 ? distance : nil  // Ignore invalid distances
        }
    }
}

// MARK: - AVCaptureDepthDataOutputDelegate
extension LiDARDepth: AVCaptureDepthDataOutputDelegate {
    func depthDataOutput(_ output: AVCaptureDepthDataOutput, didOutput depthData: AVDepthData, timestamp: CMTime) {
        updateDistance(with: depthData)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension LiDARDepth: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Required to trigger the synchronized delegate
    }
}

// MARK: - AVCaptureDataOutputSynchronizerDelegate
extension LiDARDepth: AVCaptureDataOutputSynchronizerDelegate {
    func dataOutputSynchronizer(_ synchronizer: AVCaptureDataOutputSynchronizer, didOutput synchronizedDataCollection: AVCaptureSynchronizedDataCollection) {
        guard let syncedDepthData = synchronizedDataCollection.synchronizedData(for: depthOutput) as? AVCaptureSynchronizedDepthData else { return }
        updateDistance(with: syncedDepthData.depthData)
    }
}

// MARK: - Logger
fileprivate let logger = Logger(subsystem: "com.example.lidardepth", category: "LiDARDepth")
