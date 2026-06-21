// Services/LatestFrameStore.swift
// Thread-safe cache of the most recent camera frame, so features like the
// parking logger can grab a photo on demand without threading the frame through
// every call site. Updated from GeminiSessionViewModel's frame pipeline.

import UIKit

final class LatestFrameStore {
  static let shared = LatestFrameStore()

  private let queue = DispatchQueue(label: "com.visionclaw.latestframe")
  private var _image: UIImage?

  var image: UIImage? {
    get { queue.sync { _image } }
    set { queue.sync { _image = newValue } }
  }

  private init() {}
}
