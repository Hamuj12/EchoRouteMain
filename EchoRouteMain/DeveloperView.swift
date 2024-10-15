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
    @StateObject private var camera = Camera()  // Camera instance
    @StateObject private var speechRecognizer = SpeechRecognizer()  // Speech recognizer instance
    @State private var isRecording = false  // Track recording state
    @State private var isCameraRunning = false  // Track if the camera is running
    @State private var parsedText: String = ""  // Store the predicted text

    private let modelHandler = ModelHandler()  // Instance of ModelHandler

    var body: some View {
        VStack {
            ZStack {
                if isCameraRunning {
                    CameraPreview(camera: camera)
                        .frame(height: 500)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(radius: 5)
                } else {
                    Text("Camera is off")
                        .frame(height: 500)
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(12)
                        .shadow(radius: 5)
                }
            }
            
            HStack(spacing: 20) {
                Button("Start Capture") {
                    Task {
                        await camera.start()
                        isCameraRunning = true
                    }
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle)
                .controlSize(.large)

                Button("Stop Capture") {
                    camera.stop()
                    isCameraRunning = false
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle)
                .controlSize(.large)
            }

            VStack {
                // Display transcribed and parsed text
                ScrollView {
                    VStack(alignment: .leading) {
                        Text(speechRecognizer.transcript)  // Original transcript
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if !parsedText.isEmpty {
                            Text(parsedText)  // Parsed text in bold and blue
                                .bold()
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .frame(minHeight: 20)
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(12)
                .padding(.horizontal)

                // Record and Parse Buttons
                HStack {
                    Button(isRecording ? "Stop Recording" : "Record Audio") {
                        toggleRecording()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button("Parse") {
                        parseText()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
        }
        .padding()
        .onDisappear {
            camera.stop()
            isCameraRunning = false
        }
    }

    // Toggle the recording state
    private func toggleRecording() {
        if isRecording {
            speechRecognizer.stopTranscribing()
        } else {
            speechRecognizer.startTranscribing()
        }
        isRecording.toggle()
    }

    // Helper function to clean and format text
    private func cleanText(_ text: String) -> String {
        let allowedCharacters = CharacterSet.letters.union(.whitespaces)
        let cleanedText = text
            .components(separatedBy: allowedCharacters.inverted)  // Remove non-letter characters
            .joined()  // Join the parts without separators
            .lowercased()  // Convert to lowercase

        return cleanedText
    }

    // Parse the recorded text using ModelHandler
    private func parseText() {
//        let recordedText = speechRecognizer.transcript
        let recordedText = "/Find me somewhere to sit/" // test input without recording
        let cleanedText = cleanText(recordedText)  // Clean the recorded text

        modelHandler.predictCompletion(for: cleanedText) { prediction, error in
            if let prediction = prediction {
                DispatchQueue.main.async {
                    self.parsedText = prediction  // Update the parsed text
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




