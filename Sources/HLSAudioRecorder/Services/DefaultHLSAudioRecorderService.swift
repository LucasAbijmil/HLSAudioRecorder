//
//  Copyright © 2023 Lucas Abijmil. All rights reserved.
//

import AVFoundation

public final class DefaultHLSAudioRecorderService: NSObject, HLSAudioRecorderService {

  public var delegate: HLSAudioRecorderServiceDelegate?
  public var isRecording: Bool {
    return captureSession?.isRunning == true && assetWriter?.status == .writing
  }
  private let audioSession: AVAudioSession
  private var segmentIndex = 0
  private var captureSession: AVCaptureSession?
  private var audioDataOutput: AVCaptureAudioDataOutput?
  private var assetWriter: AVAssetWriter?
  private var writerInput: AVAssetWriterInput?

  public init(audioSession: AVAudioSession) {
    self.audioSession = audioSession
  }

  @discardableResult public func requestRecordPermission() async -> Bool {
    return await audioSession.requestRecordPermission()
  }

  public func start(with configuration: HLSAudioRecorder.Configuration) async throws {
    guard audioSession.recordPermission == .granted else {
      throw audioSession.recordPermission == .undetermined ? HLSAudioRecorderServiceError.Session.shouldRequestRecordPermission : HLSAudioRecorderServiceError.Session.recordPermissionIsDenied
    }

    let captureSession = AVCaptureSession()
    let sessionPreset = configuration.preset.value
    if captureSession.canSetSessionPreset(sessionPreset) {
      captureSession.sessionPreset = sessionPreset
    }

    guard let microphone = AVCaptureDevice.default(.builtInMicrophone, for: .audio, position: .unspecified) else {
      throw HLSAudioRecorderServiceError.Session.microphoneDeviceNotFound
    }
    let microphoneInput = try AVCaptureDeviceInput(device: microphone)
    guard captureSession.canAddInput(microphoneInput) else {
      throw HLSAudioRecorderServiceError.Session.cannotAddMicrophoneInput
    }
    captureSession.addInput(microphoneInput)
    let audioDataOutput = AVCaptureAudioDataOutput()
    audioDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "HLSAudioRecorderService.audioQueue"))
    guard captureSession.canAddOutput(audioDataOutput) else {
      throw HLSAudioRecorderServiceError.Session.cannotAddAudioDataOutput
    }
    captureSession.addOutput(audioDataOutput)

    let writerInput = AVAssetWriterInput(mediaType: .audio, outputSettings: configuration.outputSettings ?? audioDataOutput.recommendedAudioSettingsForAssetWriter(writingTo: .mp4))
    writerInput.expectsMediaDataInRealTime = true
    let assetWriter = AVAssetWriter(contentType: UTType(HLSAudioRecorder.Configuration.outputContentType.rawValue)!)
    guard assetWriter.canAdd(writerInput) else {
      throw HLSAudioRecorderServiceError.AssetWriter.cannotAddWriterInput
    }
    assetWriter.add(writerInput)
    assetWriter.outputFileTypeProfile = HLSAudioRecorder.Configuration.outputFileTypeProfile
    assetWriter.preferredOutputSegmentInterval = CMTime(seconds: Double(configuration.segmentDuration), preferredTimescale: 1)
    assetWriter.initialSegmentStartTime = configuration.startTimeOffset
    assetWriter.shouldOptimizeForNetworkUse = configuration.shouldOptimizeForNetworkUse
    assetWriter.delegate = self

    guard assetWriter.startWriting() else {
      throw assetWriter.error ?? HLSAudioRecorderServiceError.AssetWriter.cannotStartWriting
    }
    assetWriter.startSession(atSourceTime: configuration.startTimeOffset)
    captureSession.startRunning()

    self.captureSession = captureSession
    self.audioDataOutput = audioDataOutput
    self.assetWriter = assetWriter
    self.writerInput = writerInput
  }

  public func stop() async throws {
    guard isRecording else { return }
    defer { reset() }
    captureSession?.stopRunning()
    writerInput?.markAsFinished()
    await assetWriter?.finishWriting()
    guard assetWriter?.status == .completed else {
      assetWriter?.cancelWriting()
      throw assetWriter?.error ?? HLSAudioRecorderServiceError.AssetWriter.finishWritingWithError
    }
  }

  private func reset() {
    segmentIndex = 0
    captureSession = nil
    audioDataOutput = nil
    assetWriter = nil
    writerInput = nil
  }
}

extension DefaultHLSAudioRecorderService: AVCaptureAudioDataOutputSampleBufferDelegate {

  public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    guard audioDataOutput?.connection(with: .audio) == connection, writerInput?.isReadyForMoreMediaData == true, writerInput?.append(sampleBuffer) == true else {
      delegate?.captureOutput(error: assetWriter?.error ?? HLSAudioRecorderServiceError.AssetWriter.runtimeError)
      captureSession?.stopRunning()
      reset()
      return
    }
    delegate?.captureOutput(sampleBuffer: sampleBuffer)
    delegate?.captureOutput(peakHoldLevel: connection.audioChannels.reduce(0, { $0 + $1.peakHoldLevel }))
    delegate?.captureOutput(averagePowerLevel: connection.audioChannels.reduce(0, { $0 + $1.averagePowerLevel }))
  }
}

extension DefaultHLSAudioRecorderService: AVAssetWriterDelegate {

  public func assetWriter(_ writer: AVAssetWriter, didOutputSegmentData segmentData: Data, segmentType: AVAssetSegmentType, segmentReport: AVAssetSegmentReport?) {
    let isInitializationSegment: Bool
    switch segmentType {
    case .initialization:
      isInitializationSegment = true
    case .separable:
      isInitializationSegment = false
    @unknown default:
      return
    }

    let segment = HLSAudioRecorder.Segment(index: segmentIndex, data: segmentData, isInitializationSegment: isInitializationSegment, report: segmentReport)
    segmentIndex += 1
    delegate?.captureOutput(segment: segment)
  }
}
