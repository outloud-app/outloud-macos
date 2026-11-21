import Sparkle
import SwiftUI

/// Development builds must never replace themselves with a published release.
@MainActor final class AppUpdater {
    static let shared = AppUpdater()
    #if !DEBUG
    let controller: SPUStandardUpdaterController
    #endif
    private init() {
        #if !DEBUG
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        #endif
    }
    func check() {
        #if !DEBUG
        controller.checkForUpdates(nil)
        #endif
    }
}
