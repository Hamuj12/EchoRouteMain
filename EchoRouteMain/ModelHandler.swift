//
//  ModelHandler.swift
//  llmtest
//
//  Created by Hamza Mujtaba on 4/21/24.
//

import CoreML
import NaturalLanguage

class ModelHandler {
    private let tokenizer = BertTokenizer()
    
    func predictCompletion(for objects: String) async throws -> String {
        let prompt = "\(objects). the user is looking for a [MASK]."
        return try await predictMaskedToken(in: prompt)
    }
    
    private func predictMaskedToken(in text: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            predictMaskedToken(in: text) { prediction, error in
                if let prediction = prediction {
                    continuation.resume(returning: prediction)
                } else if let error = error {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func predictMaskedToken(in text: String, completion: @escaping (String?, Error?) -> Void) {
        do {
            // Tokenize the input and generate the mask
            // Tokenize the input
            var tokens = tokenizer.tokenize(text: text)

            // Iterate over the tokens and trim whitespace around the [MASK] token
            tokens = tokens.map { token in
                if token.trimmingCharacters(in: .whitespaces) == "[MASK]" {
                    return "[MASK]" // Ensure [MASK] token is standardized without whitespace
                }
                return token
            }
            
            tokens.insert("[CLS]", at: 0)
            tokens.append("[SEP]")

            // Initialize MLMultiArrays for input IDs and attention mask
            let inputIDs = try MLMultiArray(shape: [1, tokens.count as NSNumber], dataType: .int32)
            let attentionMask = try MLMultiArray(shape: [1, tokens.count as NSNumber], dataType: .int32)

            // Fill in the input IDs and attention mask
            var maskIndex: Int?
            for (index, token) in tokens.enumerated() {
                let tokenId = tokenizer.tokenToId(token: token)
                inputIDs[index] = NSNumber(value: tokenId)
                attentionMask[index] = NSNumber(value: 1)
                if token == "[MASK]" {
                    maskIndex = index // Capture the index of the [MASK] token
                }
            }
            
            // Verify that a [MASK] token is present
            guard let maskPosition = maskIndex else {
                completion(nil, NSError(domain: "ModelHandlerError", code: -1, userInfo: [NSLocalizedDescriptionKey: "The input text does not contain a [MASK] token."]))
                return
            }
            
            // Load your Core ML model
            let coreMLModel = try float32_model(configuration: MLModelConfiguration())
            
            // Perform the prediction
            let predictionOutput = try coreMLModel.prediction(input_ids: inputIDs, attention_mask: attentionMask)
            
            // Extract logits for the [MASK] position and get top k predictions
            let logits = predictionOutput.token_scores
            let logitsForMaskPosition = try extractLogits(logits: logits, forPosition: maskPosition)
            let topKPredictions = Math.topK(logitsForMaskPosition, k: 5)
            let topKTokens = topKPredictions.map { (index, probability) in
                (tokenizer.ids_to_tokens[index] ?? "[UNKNOWN]", probability)
            }

            // You can return the top k predictions here
            // For simplicity, let's just return the most probable token
            if let (predictedToken, _) = topKTokens.first {
                completion(predictedToken, nil)
            } else {
                completion("[UNKNOWN]", nil)
            }
        } catch {
            completion(nil, error)
        }
    }
    
    private func extractLogits(logits: MLMultiArray, forPosition position: Int) throws -> [Float] {
        // Assuming logits is of shape [1, sequence_length, vocab_size]
        let vocabSize = logits.shape[2].intValue
        var logitsForPosition = [Float](repeating: 0.0, count: vocabSize)
        
        let basePointer = logits.dataPointer.assumingMemoryBound(to: Float.self)
        
        for i in 0..<vocabSize {
            // Calculate the index for the [MASK] token logits
            let index = (position * vocabSize) + i
            logitsForPosition[i] = basePointer[index]
        }
        
        return logitsForPosition
    }

}







