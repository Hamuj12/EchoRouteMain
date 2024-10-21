//
//  CameraSwift.swift
//  EchoRouteMain
//
//  Created by Hamza Mujtaba on 10/15/24.
//

import SwiftUI
import AVFoundation
import Vision

// UIViewRepresentable to wrap AVCaptureVideoPreviewLayer
struct CameraPreview: UIViewRepresentable {
    class CameraPreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        var previewLayer: AVCaptureVideoPreviewLayer {
            return layer as! AVCaptureVideoPreviewLayer
        }
    }

    @ObservedObject var camera: Camera

    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        view.previewLayer.session = camera.session
        view.previewLayer.videoGravity = .resizeAspectFill

        return view
    }

    func updateUIView(_ uiView: CameraPreviewView, context: Context) {}
}

class ColorManager {
    static private var colorMap: [String: Color] = [:]
    static private let predefinedColors: [Color] = [
        .red, .blue, .green, .orange, .purple, .pink, .yellow, .cyan
    ]
    
    static func getColor(for className: String) -> Color {
        if let color = colorMap[className] {
            return color
        } else {
            let newColor = predefinedColors[colorMap.count % predefinedColors.count]
            colorMap[className] = newColor
            return newColor
        }
    }
}

struct BoundingBoxOverlay: View {
    let objects: [ObjectWithDepth]
    let isDepthEnabled: Bool

    var body: some View {
        ZStack {
            ForEach(objects, id: \.observation.uuid) { object in
                GeometryReader { geometry in
                    let size = geometry.size
                    let boundingBox = object.observation.boundingBox
                    let className = object.observation.labels.first?.identifier ?? "Unknown"
                    let color = ColorManager.getColor(for: className)

                    let rect = CGRect(
                        x: boundingBox.origin.x * size.width,
                        y: (1 - boundingBox.maxY) * size.height,
                        width: boundingBox.width * size.width,
                        height: boundingBox.height * size.height
                    )

                    Path { path in
                        path.addRect(rect)
                    }
                    .stroke(color, lineWidth: 2)

                    VStack {
                        Text("\(className): \(String(format: "%.2f", object.observation.confidence))")
                        if isDepthEnabled, let depth = object.depth {
                            Text("Depth: \(String(format: "%.2f", depth)) m")
                        }
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(color)
                    .position(x: rect.midX, y: rect.minY - 20)
                }
            }
        }
    }
}

// Create a new struct to hold object and depth information
struct ObjectWithDepth {
    let observation: VNRecognizedObjectObservation
    let depth: Float?
}

struct DeveloperView: View {
    @StateObject private var cameraController = CameraController()  // Use new CameraController instance
    @StateObject private var speechRecognizer = SpeechRecognizer()  // Speech recognizer instance
    @State private var isRecording = false  // Track recording state
    @State private var parsedText: String = ""  // Store parsed text
    @State private var isDepthEnabled = false  // Track LiDAR depth toggle
    @State private var detectedObjects: [VNRecognizedObjectObservation] = []
    @State private var filterKeyword: String? = nil
    @State private var isParsing = false  // Track if parsing is in progress
    @State private var isFiltering = false  // Track if filtering is in progress
    
    private let modelHandler = ModelHandler()  // Instance of ModelHandler
    private let speechSynthesizer = AVSpeechSynthesizer()  // AVSpeechSynthesizer for TTS
    
    var body: some View {
        VStack (spacing: 10) {
            ZStack {
                // Display camera preview or a placeholder if session is not running
                if cameraController.isSessionRunning, let capturedImage = cameraController.capturedImage {
                    Image(uiImage: capturedImage)
                        .resizable()
                        .frame(height: 450)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(radius: 5)
                } else {
                    Text("Camera is off")
                        .frame(height: 450)
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(12)
                        .shadow(radius: 5)
                }
                
                // Display bounding boxes for detected objects
                if cameraController.detectionEnabled {
                    BoundingBoxOverlay(objects: cameraController.objectsWithDepth, isDepthEnabled: isDepthEnabled)
                        .frame(height: 450)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(radius: 5)
                }

                // Display a reticle if LiDAR is enabled
//                if isDepthEnabled {
//                    VStack {
//                        Spacer()
//                        Text("Depth: \(cameraController.closestDepth, specifier: "%.2f") meters")
//                            .font(.headline)
//                            .foregroundColor(.white)
//                            .padding(8)
//                            .background(Color.black.opacity(0.7))
//                            .cornerRadius(8)
//                        Spacer()
//                    }
//                    .transition(.opacity)
//                    .animation(.easeInOut, value: isDepthEnabled)
//                }
            }

            VStack(spacing: 16) {
                Toggle(isOn: Binding(
                    get: { cameraController.isSessionRunning },
                    set: { newValue in
                        if newValue {
                            cameraController.startSession()
                        } else {
                            cameraController.stopSession()
                        }
                    }
                )) {
                    Text("Enable Camera")
                }
                .toggleStyle(SwitchToggleStyle())

                Toggle(isOn: Binding(
                    get: { isDepthEnabled },
                    set: { newValue in
                        if newValue {
                            isDepthEnabled = true
                        } else {
                            isDepthEnabled = false
                        }
                    }
                )) {
                    Text("Enable Depth")
                }
                .toggleStyle(SwitchToggleStyle())
                
                Toggle(isOn: Binding(
                    get: { cameraController.detectionEnabled },
                    set : { newValue in
                        if newValue {
                            cameraController.enableDetections(true)
                        } else {
                            cameraController.enableDetections(false)
                        }
                    }
                )) {
                    Text("Enable Detection")
                }
                .toggleStyle(SwitchToggleStyle())
            }
            .frame(maxWidth: .infinity)
            
            // Display transcribed and parsed text
            ScrollView {
                VStack(alignment: .leading) {
                    Text(speechRecognizer.transcript)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if !parsedText.isEmpty {
                        Text(parsedText)
                            .bold()
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(minHeight: 20, maxHeight: 20)
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(12)

            HStack {
                Button(isRecording ? "Stop Recording" : "Record Audio") {
                    toggleRecording()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .buttonBorderShape(.roundedRectangle)
                .background(isRecording ? Color.red : Color.clear)
                .foregroundColor(isRecording ? Color.white : Color.blue)
                .cornerRadius(12)

                Button(action: {
                    isParsing = true
                    Task {
                        do {
                            let prediction = try await modelHandler.predictCompletion(for: cleanText(speechRecognizer.transcript))
                            self.parsedText = prediction
                            speakText(prediction)
                        } catch {
                            print("Error parsing text: \(error.localizedDescription)")
                        }
                        isParsing = false
                    }
                }) {
                    if isParsing {
                        ProgressView()
                    } else {
                        Text("Parse")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .buttonBorderShape(.roundedRectangle)

                Button(action: {
                    isFiltering = true
                    Task {
                        do {
                            let prediction = try await modelHandler.predictCompletion(for: cleanText(speechRecognizer.transcript))
                            filterKeyword = prediction
                            applyFilter()
                        } catch {
                            print("Error parsing text: \(error.localizedDescription)")
                        }
                        isFiltering = false
                    }
                }) {
                    if isFiltering {
                        ProgressView()
                    } else {
                        Text("Filter")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .buttonBorderShape(.roundedRectangle)
            }
            .padding()

        }
        .padding()
        .onAppear {
            // Ensure session is properly stopped when first loading the view
            if !cameraController.isSessionRunning {
                cameraController.stopSession()
            }
            
            cameraController.detectionHandler.onDetectionsUpdate = { detections in
                if let filterKeyword = filterKeyword {
                    // Apply filter
                    self.cameraController.objectsWithDepth = detections.filter { object in
                        guard let className = object.observation.labels.first?.identifier else { return false }
                        return className.lowercased() == filterKeyword.lowercased()
                    }
                } else {
                    // Update objectsWithDepth normally
                    self.cameraController.objectsWithDepth = detections
                }
            }
        }
        .onDisappear {
            cameraController.stopSession()  // Stop session when leaving the view
        }
    }

    // Toggle recording state
    private func toggleRecording() {
        if isRecording {
            speechRecognizer.stopTranscribing()
        } else {
            speechRecognizer.startTranscribing()
        }
        isRecording.toggle()
    }

    // Clean and format recorded text
    private func cleanText(_ text: String) -> String {
        let allowedCharacters = CharacterSet.letters.union(.whitespaces)
        return text
            .components(separatedBy: allowedCharacters.inverted)
            .joined()
            .lowercased()
    }
    
    private func applyFilter() {
        // Ensure camera session is running and detection is enabled
        guard cameraController.isSessionRunning, cameraController.detectionEnabled else {
            print("Camera session or detection is not active.")
            return
        }

        // Ensure we have a valid filter keyword
        guard let keyword = filterKeyword else {
            print("No valid filter keyword.")
            return
        }

        // Filter detected objects based on the predicted class name
        detectedObjects = detectedObjects.filter { object in
            guard let className = object.labels.first?.identifier else { return false }
            return className.lowercased() == keyword.lowercased()
        }

        print("Filtered objects: \(detectedObjects.map { $0.labels.first?.identifier ?? "Unknown" })")
    }


    // Parse recorded text using ModelHandler and trigger TTS
    private func parseText() {
        let recordedText = speechRecognizer.transcript
        let cleanedText = cleanText(recordedText)

        Task {
            do {
                let prediction = try await modelHandler.predictCompletion(for: cleanedText)
                self.parsedText = prediction
                speakText(prediction)
            } catch {
                print("Error parsing text: \(error.localizedDescription)")
            }
        }
    }


    // Text-to-Speech function
    private func speakText(_ text: String) {
        let utterance = AVSpeechUtterance(string: "Let's find you a \(text).")
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")  // Set the language
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate  // Set the speed of speech
        speechSynthesizer.speak(utterance)
    }
}

#Preview {
    DeveloperView()
}





