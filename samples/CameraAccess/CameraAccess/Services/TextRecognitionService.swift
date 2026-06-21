// Services/TextRecognitionService.swift
// On-device OCR using Apple's Vision framework. Deterministic and offline —
// works regardless of whether live video streaming to Gemini is enabled.

import Foundation
import Vision
import UIKit

enum TextRecognitionService {

  // Recognizes text in an image and returns it as newline-separated lines
  // (empty string if nothing legible was found).
  static func recognizeText(in image: UIImage) async -> String {
    guard let cgImage = image.cgImage else { return "" }

    return await withCheckedContinuation { continuation in
      DispatchQueue.global(qos: .userInitiated).async {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        do {
          try handler.perform([request])
          let observations = request.results ?? []
          let lines = observations.compactMap { $0.topCandidates(1).first?.string }
          continuation.resume(returning: lines.joined(separator: "\n"))
        } catch {
          continuation.resume(returning: "")
        }
      }
    }
  }
}
