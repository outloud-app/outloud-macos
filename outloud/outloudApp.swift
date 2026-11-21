//
//  outloudApp.swift
//  outloud
//
//  Created by wire-j on 29/10/2026.
//

import SwiftUI

extension Notification.Name {
    static let outloudCloseProject = Notification.Name("OutloudCloseProject")
    static let outloudNewProject = Notification.Name("OutloudNewProject")
    static let outloudShowSettings = Notification.Name("OutloudShowSettings")
    static let outloudWorkspaceAction = Notification.Name("OutloudWorkspaceAction")
    static let outloudExitFullScreen = Notification.Name("OutloudExitFullScreen")
}

struct WorkspaceProjectFocusKey: FocusedValueKey { typealias Value = Bool }
extension FocusedValues {
    var outloudHasProject: Bool? {
        get { self[WorkspaceProjectFocusKey.self] }
        set { self[WorkspaceProjectFocusKey.self] = newValue }
    }
}

@main
struct outloudApp: App {
    @FocusedValue(\.outloudHasProject) private var hasProject
    init() {
        AppFont.register()
        _ = AppUpdater.shared
    }
    #if DEBUG
    @NSApplicationDelegateAdaptor(PreviewCaptureDelegate.self) private var previewCapture
    #endif
    var body: some Scene {
        Window("Outloud", id: "workspace") {
            #if DEBUG
            if ProcessInfo.processInfo.environment["OUTLOUD_TEST_LICENSING"] == "1" {
                EarlyAccessRootView()
            } else { ContentView() }
            #else
            EarlyAccessRootView()
            #endif
        }
        .defaultSize(width: 1080, height: 760)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Project…") { NotificationCenter.default.post(name: .outloudNewProject, object: nil) }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                Button("Close Project") { NotificationCenter.default.post(name: .outloudCloseProject, object: nil) }
                    .keyboardShortcut("w", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") { NotificationCenter.default.post(name: .outloudShowSettings, object: nil) }
                    .keyboardShortcut(",", modifiers: .command).disabled(hasProject != true)
            }
            CommandGroup(replacing: .help) {
                Button("Outloud Help") { NSWorkspace.shared.open(URL(string: "mailto:support@tryoutloud.xyz?subject=Outloud%20help")!) }
                Button("About Outloud") { NSApp.orderFrontStandardAboutPanel(nil) }
            }
            CommandGroup(after: .newItem) {
                Group {
                Button("Add Reference…") { action("reference") }.keyboardShortcut("i", modifiers: [.command, .shift])
                Button("Add Account or Topic…") { action("source") }
                }.disabled(hasProject != true)
            }
            CommandGroup(before: .toolbar) {
                Group {
                Button("Home") { action("home") }.keyboardShortcut("1", modifiers: .command)
                Button("Discover") { action("Discover") }.keyboardShortcut("2", modifiers: .command)
                Button("Conversations") { action("Conversations") }.keyboardShortcut("3", modifiers: .command)
                Button("Saved") { action("Saved") }.keyboardShortcut("4", modifiers: .command)
                Divider()
                Button("Search Project…") { action("search") }
                Button("Refresh Research") { action("refresh") }.keyboardShortcut("r", modifiers: .command)
                }.disabled(hasProject != true)
            }
            #if !DEBUG
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") { AppUpdater.shared.check() }
            }
            #endif
        }

    }
    private func action(_ name: String) {
        NotificationCenter.default.post(name: .outloudWorkspaceAction, object: name)
    }
}
