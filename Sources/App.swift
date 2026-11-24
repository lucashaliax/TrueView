import SwiftUI
import AppKit
import ServiceManagement
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var updateTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            AutomationEngine.shared.start()
            WindowOpener.openSettings = { SettingsWindowController.shared.show() }
            StatusItemController.shared.setUp()
            startUpdateChecks()
            runTestArguments()
        }
    }

    /// Argumentos de teste: `-TrueViewShowPanel YES` abre o painel e `-TrueViewOpenSettings YES`
    /// abre as configurações logo depois de iniciar (para gravar a tela sem clicar).
    @MainActor private func runTestArguments() {
        let d = UserDefaults.standard
        if d.bool(forKey: "TrueViewShowPanel") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { StatusItemController.shared.togglePanel() }
        }
        if d.bool(forKey: "TrueViewOpenSettings") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { WindowOpener.openSettings?() }
        }
    }

    /// Procura atualizações uma vez por semana, se ligado (o timer só confere a data a cada 6 horas).
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
            guard AutomationEngine.shared.settings.autoCheckUpdates else { return }
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
        // O ícone, o painel (NSPopover, com a animação nativa) e a janela de configurações são
        // do AppKit: StatusItemController e SettingsWindowController. O SwiftUI exige uma cena.
        Settings { EmptyView() }
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

/// Janela de configurações criada pelo AppKit. O `openWindow` do SwiftUI não funciona a partir
/// do painel (NSPopover), que fica fora das cenas do SwiftUI.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    func show() {
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 520),
                             styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                             backing: .buffered, defer: false)
            w.title = "TrueView"
            w.titleVisibility = .hidden
            w.titlebarAppearsTransparent = true
            w.isMovableByWindowBackground = true
            w.isReleasedWhenClosed = false
            w.delegate = self
            // Fundo translúcido, como o `.containerBackground(.ultraThinMaterial, for: .window)`.
            let blur = NSVisualEffectView()
            blur.material = .underWindowBackground
            blur.blendingMode = .behindWindow
            blur.state = .active
            let host = NSHostingView(rootView: SettingsView().environmentObject(AutomationEngine.shared))
            host.translatesAutoresizingMaskIntoConstraints = false
            blur.addSubview(host)
            NSLayoutConstraint.activate([
                host.leadingAnchor.constraint(equalTo: blur.leadingAnchor),
                host.trailingAnchor.constraint(equalTo: blur.trailingAnchor),
                host.topAnchor.constraint(equalTo: blur.topAnchor),
                host.bottomAnchor.constraint(equalTo: blur.bottomAnchor),
            ])
            w.contentView = blur
            w.center()
            window = w
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()   // o macOS pode negar a ativação; a janela vem para frente mesmo assim
    }
}

/// Ícone da barra de menus com o painel num NSPopover (abre com a animação nativa do macOS,
/// que cresce a partir do ícone, e fecha com fade).
@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    static let shared = StatusItemController()

    private var item: NSStatusItem?
    private let popover = NSPopover()

    func setUp() {
        guard item == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = Self.icon
            button.target = self
            button.action = #selector(buttonClicked)
        }
        self.item = item

        let host = NSHostingController(rootView: MenuPanel().environmentObject(AutomationEngine.shared))
        host.sizingOptions = .preferredContentSize
        popover.contentViewController = host
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
    }

    @objc private func buttonClicked() { togglePanel() }

    func togglePanel() {
        guard let button = item?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            AutomationEngine.shared.refreshStatus()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func closePanel() {
        if popover.isShown { popover.performClose(nil) }
    }

    func popoverWillShow(_ notification: Notification) { item?.button?.highlight(true) }
    func popoverDidClose(_ notification: Notification) { item?.button?.highlight(false) }

    // Diafragma do ícone do app, em branco (template), no tamanho dos ícones do sistema.
    private static let icon: NSImage = {
        let config = NSImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        let image = NSImage(systemSymbolName: "camera.aperture", accessibilityDescription: "TrueView")?
            .withSymbolConfiguration(config) ?? NSImage()
        image.isTemplate = true
        return image
    }()
}
