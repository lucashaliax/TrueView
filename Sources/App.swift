import SwiftUI
import AppKit
import ServiceManagement
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var updateTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            AutomationEngine.shared.start()
            startUpdateChecks()
        }
    }

    /// Procura atualizações uma vez por dia (o timer só confere a data a cada 6 horas).
    @MainActor private func startUpdateChecks() {
        UNUserNotificationCenter.current().delegate = self
        // `open -a TrueView --args -TrueViewRunUpdate YES` procura e instala a última versão
        // sem perguntar (para testar atualizações).
        if UserDefaults.standard.bool(forKey: "TrueViewRunUpdate") {
            Task {
                if let release = await Updater.shared.check() { Updater.shared.install(release) }
            }
            return
        }
        let tick = {
            guard AutomationEngine.shared.settings.checkForUpdates else { return }
            Updater.shared.checkInBackgroundIfDue()
        }
        tick()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { _ in
            MainActor.assumeIsolated { tick() }
        }
        updateTimer?.tolerance = 600
    }

    /// Clicar na notificação de nova versão abre as configurações no Sobre.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        let isUpdate = response.notification.request.identifier.hasPrefix("update-")
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                if isUpdate {
                    SettingsNavigation.shared.tab = .about
                    NSApp.activate()
                    WindowOpener.openSettings?()
                }
            }
            completionHandler()
        }
    }

    /// Mostra as notificações do TrueView mesmo com o app em primeiro plano.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list])
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
            MenuBarLabel()
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

/// Guarda a ação de abrir a janela de configurações, para quem não é uma view (notificações).
@MainActor
enum WindowOpener {
    static var openSettings: (() -> Void)?
}

/// Ícone da barra de menus. Como está sempre na tela, é daqui que se captura o `openWindow`.
struct MenuBarLabel: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        // Diafragma do ícone do app, em branco (template) para ficar legível na barra.
        Image(systemName: "camera.aperture")
            .font(.system(size: 15, weight: .medium))
            .onAppear { WindowOpener.openSettings = { openWindow(id: "settings") } }
    }
}
