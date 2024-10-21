import AVFoundation
import UIKit
import Vision

class CameraController: NSObject, ObservableObject {
    @Published var capturedImage: UIImage?
    @Published var isSessionRunning = false
    @Published var closestDepth: Float = Float.infinity
    @Published var errorMessage: String?
    @Published var objectsWithDepth: [ObjectWithDepth] = []

    private let captureSession = AVCaptureSession()
    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var depthDataOutput: AVCaptureDepthDataOutput?
    var detectionHandler = DetectionHandler()
    private var isDetectionEnabled = false
    
    private enum SetupError: Error {
        case cameraUnavailable
        case inputSetupFailed
        case outputSetupFailed
        case configurationFailed
    }
    
    override init() {
        super.init()
        do {
            try setupCaptureSession()
            setupDetectionHandler()
        } catch {
            handleSetupError(error)
        }
    }
    
    private func setupDetectionHandler() {
        detectionHandler.onDetectionsUpdate = { [weak self] detections in
            // Handle detection updates
            // Assuming there's a way to connect this to UI or further process
            print("Detections updated: \(detections)")
            // Add logic to update UI (like a bounding box view) here
        }
    }
    
    private func setupCaptureSession() throws {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        
        guard let device = AVCaptureDevice.default(.builtInLiDARDepthCamera, for: .video, position: .back) else {
            throw SetupError.cameraUnavailable
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard captureSession.canAddInput(input) else { throw SetupError.inputSetupFailed }
            captureSession.addInput(input)
            
            try configureCamera(device)
            try setupVideoDataOutput()
            try setupDepthDataOutput()
            
            captureSession.sessionPreset = .high
        } catch {
            throw SetupError.configurationFailed
        }
    }
    
    private func configureCamera(_ device: AVCaptureDevice) throws {
        do {
            try device.lockForConfiguration()
            device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30) // 30 fps
            device.focusMode = .continuousAutoFocus
            device.unlockForConfiguration()
        } catch {
            throw SetupError.configurationFailed
        }
    }
    
    private func setupVideoDataOutput() throws {
        videoDataOutput = AVCaptureVideoDataOutput()
        guard let videoDataOutput = videoDataOutput,
              captureSession.canAddOutput(videoDataOutput) else {
            throw SetupError.outputSetupFailed
        }
        
        captureSession.addOutput(videoDataOutput)
        videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        
        if let connection = videoDataOutput.connection(with: .video) {
            connection.videoRotationAngle = 90
            connection.isVideoMirrored = false
        }
    }
    
    private func setupDepthDataOutput() throws {
        depthDataOutput = AVCaptureDepthDataOutput()
        guard let depthDataOutput = depthDataOutput,
              captureSession.canAddOutput(depthDataOutput) else {
            throw SetupError.outputSetupFailed
        }
        
        captureSession.addOutput(depthDataOutput)
        depthDataOutput.setDelegate(self, callbackQueue: DispatchQueue(label: "depthQueue"))
        depthDataOutput.isFilteringEnabled = true
        
        if let connection = depthDataOutput.connection(with: .depthData) {
            connection.videoRotationAngle = 90
        }
    }
    
    private func handleSetupError(_ error: Error) {
        switch error {
        case SetupError.cameraUnavailable:
            errorMessage = "LiDAR camera unavailable"
        case SetupError.inputSetupFailed:
            errorMessage = "Failed to set up camera input"
        case SetupError.outputSetupFailed:
            errorMessage = "Failed to set up camera output"
        case SetupError.configurationFailed:
            errorMessage = "Failed to configure camera"
        default:
            errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
    
    func startSession() {
        guard !isSessionRunning else { return }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
            DispatchQueue.main.async {
                self?.isSessionRunning = self?.captureSession.isRunning ?? false
            }
        }
    }
    
    func stopSession() {
        guard isSessionRunning else { return }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.stopRunning()
            DispatchQueue.main.async {
                self?.isSessionRunning = false
                self?.closestDepth = Float.infinity
                self?.capturedImage = nil
            }
        }
    }
    
    // Computed property to expose isDetectionEnabled status
    public var detectionEnabled: Bool {
        return isDetectionEnabled
    }
    
    func enableDetections(_ enable: Bool) {
        isDetectionEnabled = enable
    }
}

extension CameraController: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureDepthDataOutputDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }

        let image = UIImage(cgImage: cgImage)

        DispatchQueue.main.async { [weak self] in
            self?.capturedImage = image
        }
        
        // Handle detection if enabled
        if isDetectionEnabled {
            detectionHandler.detectObjects(in: pixelBuffer)
        }
    }
    
    func depthDataOutput(_ output: AVCaptureDepthDataOutput, didOutput depthData: AVDepthData, timestamp: CMTime, connection: AVCaptureConnection) {
        let depthData = depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
        let pixelBuffer = depthData.depthDataMap
        
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        // Update depths for detected objects
        let updatedObjects = objectsWithDepth.map { objectWithDepth -> ObjectWithDepth in
            let centerX = Int(objectWithDepth.observation.boundingBox.midX * CGFloat(width))
            let centerY = Int(objectWithDepth.observation.boundingBox.midY * CGFloat(height))
            
            let offset = centerY * bytesPerRow + centerX * MemoryLayout<Float>.size
            let depth = baseAddress.load(fromByteOffset: offset, as: Float.self)
            
            return ObjectWithDepth(observation: objectWithDepth.observation, depth: depth > 0 ? depth : nil)
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.objectsWithDepth = updatedObjects
            self?.closestDepth = updatedObjects.compactMap { $0.depth }.min() ?? Float.infinity
            self?.detectionHandler.onDetectionsUpdate?(updatedObjects)
        }
    }
}

