//
//  CameraSwift.swift
//  EchoRouteMain
//
//  Created by Hamza Mujtaba on 10/15/24.
//

import SwiftUI
import AVFoundation

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


struct DeveloperView: View {
    @StateObject private var cameraController = CameraController()  // Use new CameraController instance
    @StateObject private var speechRecognizer = SpeechRecognizer()  // Speech recognizer instance
    @State private var isRecording = false  // Track recording state
    @State private var parsedText: String = ""  // Store parsed text
    @State private var isDepthEnabled = false  // Track LiDAR depth toggle

    private let modelHandler = ModelHandler()  // Instance of ModelHandler

    var body: some View {
        VStack (spacing: 10){
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
//                .frame(width: 120, height: 100) // Static width and height
                .background(cameraController.isSessionRunning ? Color.blue : Color.clear)
                .foregroundColor(cameraController.isSessionRunning ? Color.white : Color.blue)
                .cornerRadius(12)

                Button(isDepthEnabled ? "Disable LiDAR Depth" : "Enable LiDAR Depth") {
                    isDepthEnabled.toggle()
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle)
                .controlSize(.large)
//                .frame(width: 120, height: 100) // Static width and height
                .background(isDepthEnabled ? Color.blue : Color.clear)
                .foregroundColor(isDepthEnabled ? Color.white : Color.blue)
                .cornerRadius(12)
            }
            .frame(maxWidth: .infinity)
            .padding()



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

    // Parse recorded text using ModelHandler
    private func parseText() {
        let recordedText = "/Find me somewhere to sit/"  // Example input for testing
        let cleanedText = cleanText(recordedText)

        modelHandler.predictCompletion(for: cleanedText) { prediction, error in
            if let prediction = prediction {
                DispatchQueue.main.async {
                    self.parsedText = prediction
                }
            } else if let error = error {
                print("Error parsing text: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    DeveloperView()
}




