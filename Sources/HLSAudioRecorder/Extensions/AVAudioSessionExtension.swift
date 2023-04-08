//
//  Copyright © 2023 Lucas Abijmil. All rights reserved.
//

import AVFoundation

extension AVAudioSession {

  func requestRecordPermission() async -> Bool {
    return await withUnsafeContinuation { continuation in
      requestRecordPermission(continuation.resume)
    }
  }
}
