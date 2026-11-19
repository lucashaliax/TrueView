import SwiftUI
import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated { AutomationEngine.shared.start() }
    }
    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated { AutomationEngine.shared.shutdown() }
    }
}

@main
struct TrueViewApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var engine = AutomationEngine.shared

    var body: some Scene {
        MenuBarExtra {
            MenuPanel().environmentObject(engine)
        } label: {
            // Diafragma do ícone do app, em branco (template) para ficar legível na barra.
            Image(systemName: "camera.aperture")
                .font(.system(size: 15, weight: .medium))
        }
        .menuBarExtraStyle(.window)

        Window("TrueView", id: "settings") {
            SettingsView().environmentObject(engine)
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
    }
}

enum LaunchAtLogin {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }
    static func set(_ on: Bool) throws {
        if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
    }
}
