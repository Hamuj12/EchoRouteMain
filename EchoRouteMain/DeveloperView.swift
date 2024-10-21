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
    let objects: [VNRecognizedObjectObservation]

    var body: some View {
        ZStack {
            ForEach(objects, id: \.uuid) { object in
                GeometryReader { geometry in
                    let size = geometry.size
                    let boundingBox = object.boundingBox
                    let className = object.labels.first?.identifier ?? "Unknown"

                    // Get a unique color for the class name using ColorManager
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

                    // Display the label with the class name and confidence
                    Text("\(className): \(String(format: "%.2f", object.confidence))")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(color)
                        .position(x: rect.midX, y: rect.minY - 10) // Position the label above the bounding box
                }
            }
        }
    }
}


struct DeveloperView: View {
    @StateObject private var cameraController = CameraController()  // Use new CameraController instance
    @StateObject private var speechRecognizer = SpeechRecognizer()  // Speech recognizer instance
    @State private var isRecording = false  // Track recording state
    @State private var parsedText: String = ""  // Store parsed text
    @State private var isDepthEnabled = false  // Track LiDAR depth toggle
    @State private var detectedObjects: [VNRecognizedObjectObservation] = []
    private let modelHandler = ModelHandler()  // Instance of ModelHandler
    private let speechSynthesizer = AVSpeechSynthesizer()  // AVSpeechSynthesizer for TTS
    
    var body: some View {
        VStack (spacing: 10) {
            ZStack {
                // Display camera preview or a placeholder if session is not running
                if cameraController.isSessionRunning, let capturedImage = cameraController.capturedImage {
                    Image(uiImage: capturedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 475)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(radius: 5)
                } else {
                    Text("Camera is off")
                        .frame(height: 475)
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(12)
                        .shadow(radius: 5)
                }
                
                // Display bounding boxes for detected objects
                if cameraController.detectionEnabled {
                    BoundingBoxOverlay(objects: detectedObjects)
                        .frame(height: 475)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(radius: 5)
                }

                // Display a reticle if LiDAR is enabled
                if isDepthEnabled {
                    VStack {
                        Spacer()
                        Text("Depth: \(cameraController.closestDepth, specifier: "%.2f") meters")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(8)
                        Spacer()
                    }
                    .transition(.opacity)
                    .animation(.easeInOut, value: isDepthEnabled)
                }
            }

            HStack(spacing: 16) {
                Button(cameraController.isSessionRunning ? "Stop Camera Capture" : "Start Camera Capture") {
                    if cameraController.isSessionRunning {
                        cameraController.stopSession()
                    } else {
                        cameraController.startSession()
                    }
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle)
                .controlSize(.large)
                .background(cameraController.isSessionRunning ? Color.blue : Color.clear)
                .foregroundColor(cameraController.isSessionRunning ? Color.white : Color.blue)
                .cornerRadius(12)

                Button(isDepthEnabled ? "Disable LiDAR Depth" : "Enable LiDAR Depth") {
                    isDepthEnabled.toggle()
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle)
                .controlSize(.large)
                .background(isDepthEnabled ? Color.blue : Color.clear)
                .foregroundColor(isDepthEnabled ? Color.white : Color.blue)
                .cornerRadius(12)
            }
            .frame(maxWidth: .infinity)
            .padding()
            
            HStack {
                Button(action: {
                    cameraController.enableDetections(true)
                }) {
                    Text("Enable Detections")
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                Button(action: {
                    cameraController.enableDetections(false)
                }) {
                    Text("Disable Detections")
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            
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

                Button("Parse") {
                    parseText()
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
                detectedObjects = detections
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

    // Parse recorded text using ModelHandler and trigger TTS
    private func parseText() {
//        let recordedText = speechRecognizer.transcript
        let recordedText = "Find me somewhere to sit"
        let cleanedText = cleanText(recordedText)

        modelHandler.predictCompletion(for: cleanedText) { prediction, error in
            if let prediction = prediction {
                DispatchQueue.main.async {
                    self.parsedText = prediction
                    self.speakText(prediction)  // Call TTS function
                }
            } else if let error = error {
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





