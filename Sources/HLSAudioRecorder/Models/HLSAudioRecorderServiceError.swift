//
//  Copyright © 2023 Lucas Abijmil. All rights reserved.
//

public enum HLSAudioRecorderServiceError {

  public enum Session: Error {
    case shouldRequestRecordPermission
    case recordPermissionIsDenied
    case microphoneDeviceNotFound
    case cannotAddMicrophoneInput
    case cannotAddAudioDataOutput
  }

  public enum AssetWriter: Error {
    case cannotAddWriterInput
    case cannotStartWriting
    case runtimeError
    case finishWritingWithError
  }
}
