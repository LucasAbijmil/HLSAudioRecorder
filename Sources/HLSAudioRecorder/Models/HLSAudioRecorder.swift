//
//  Copyright © 2023 Lucas Abijmil. All rights reserved.
//

import AVFoundation

public enum HLSAudioRecorder {

  public struct Segment {
    public let index: Int
    public let data: Data
    public let isInitializationSegment: Bool
    public let report: AVAssetSegmentReport?
  }

  public struct Configuration {
    static let outputContentType: AVFileType = .mp4
    static let outputFileTypeProfile: AVFileTypeProfile = .mpeg4AppleHLS
    let segmentDuration: Int
    let startTimeOffset: CMTime
    let shouldOptimizeForNetworkUse: Bool
    let outputSettings: [String: Any]?
    let preset: Preset

    public enum Preset {
      case high
      case medium
      case low

      var value: AVCaptureSession.Preset {
        switch self {
        case .high:
          return .high
        case .medium:
          return .medium
        case .low:
          return .low
        }
      }
    }

    public init(segmentDuration: Int, startTimeOffset: CMTime, shouldOptimizeForNetworkUse: Bool, outputSettings: [String : Any]?, preset: Preset) {
      self.segmentDuration = segmentDuration
      self.startTimeOffset = startTimeOffset
      self.shouldOptimizeForNetworkUse = shouldOptimizeForNetworkUse
      self.outputSettings = outputSettings
      self.preset = preset
    }
  }
}

public extension HLSAudioRecorder.Configuration {
  static let `default` = HLSAudioRecorder.Configuration(segmentDuration: 6,
                                                        startTimeOffset: CMTime(value: 10, timescale: 1),
                                                        shouldOptimizeForNetworkUse: true,
                                                        outputSettings: nil,
                                                        preset: .high)
}
