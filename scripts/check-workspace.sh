#!/bin/zsh
set -eu
cd "$(dirname "$0")/.."
task_dir=$(mktemp -d /tmp/outloud-workspace-checks.XXXXXX)
trap 'rm -rf "$task_dir"' EXIT
# Compile the real models/client/store. Auth is fail-closed here: these checks
# cannot read Keychain, activate a license, or make research requests.
cat > "$task_dir/Support.swift" <<'SWIFT'
import SwiftUI
import Foundation
extension Color {
    init(hex: UInt32) { self.init(red: Double((hex >> 16) & 255)/255, green: Double((hex >> 8) & 255)/255, blue: Double(hex & 255)/255) }
}
@MainActor final class LicenseController {
    static let shared = LicenseController()
    func authorizeResearch(_ request: inout URLRequest) throws { throw ResearchError.activation }
}
@MainActor enum ProjectWindowMorph {
    static var isTransitioning = false
    static func begin(fromStarter: Bool) {}
    static func prepareReturn() {}
}
SWIFT
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc -parse-as-library \
    outloud/PlatformMediaEmbed.swift outloud/WorkspaceModels.swift outloud/ResearchClient.swift outloud/ProjectIconAsset.swift outloud/WorkspaceStore.swift \
    scripts/WorkspaceChecks.swift "$task_dir/Support.swift" -o "$task_dir/checks"
"$task_dir/checks"
