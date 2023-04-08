//
//  Copyright © 2023 Lucas Abijmil. All rights reserved.
//

import Foundation
import AVFoundation

public protocol HLSAudioRecorderService {
  var isRecording: Bool { get }
  var delegate: HLSAudioRecorderServiceDelegate? { get set }

  @discardableResult func requestRecordPermission() async -> Bool
  func start(with configuration: HLSAudioRecorder.Configuration) async throws
  func stop() async throws
}

public protocol HLSAudioRecorderServiceDelegate: AnyObject {
  func captureOutput(segment: HLSAudioRecorder.Segment)
  func captureOutput(error: any Error)
  func captureOutput(sampleBuffer: CMSampleBuffer)
  func captureOutput(peakHoldLevel: Float)
  func captureOutput(averagePowerLevel: Float)
}

public extension HLSAudioRecorderServiceDelegate {
  func captureOutput(sampleBuffer: CMSampleBuffer) {}
  func captureOutput(peakHoldLevel: Float) {}
  func captureOutput(averagePowerLevel: Float) {}
}
