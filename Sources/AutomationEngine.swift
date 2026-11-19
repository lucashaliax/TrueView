import Foundation
import AppKit
import Combine
import UserNotifications

@MainActor
final class AutomationEngine: ObservableObject {
    static let shared = AutomationEngine()

    @Published var settings: AppSettings {
        didSet {
            guard settings != oldValue else { return }
            settings.save()
            settingsChanged(from: oldValue)
        }
    }

    /// Pausa a automação (não reage a apps).
    @Published var paused = false { didSet { evaluate() } }
    /// Liga o modo edição manualmente, independente de apps.
    @Published var manualOverride = false { didSet { evaluate() } }
    /// Desligado à mão com app de edição aberto: ignora os apps até todos fecharem.
    private var snoozed = false
    private var restoreNow = false

    /// Toggle "Modo edição" do menu: reflete o estado real e permite ligar/desligar na hora.
    var editModeToggle: Bool {
        get { isActive && restoreTask == nil || manualOverride }
        set {
            if newValue {
                snoozed = false
                manualOverride = true
            } else {
                restoreNow = true
                if !triggeringApps.isEmpty { snoozed = true }
                manualOverride = false
                evaluate()
            }
            objectWillChange.send()
        }
    }

    @Published private(set) var isActive = false
    @Published private(set) var triggeringApps: [String] = []

    @Published private(set) var trueToneOn = DisplayControl.trueToneEnabled()
    @Published private(set) var nightShiftOn = DisplayControl.nightShiftEnabled()

    let trueToneSupported = DisplayControl.trueToneSupported()
    let nightShiftSupported = DisplayControl.nightShiftSupported()

    private var saved: SavedDisplayState?
    private var restoreTask: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []

    private init() {
        settings = AppSettings.load()
    }

    // MARK: Ciclo de vida

    func start() {
        // Se o app foi encerrado à força durante o modo edição, desfaz o que ficou pendente.
        if let pending = SavedDisplayState.load() {
            apply(restore: pending)
            SavedDisplayState.clear()
        }

        let nc = NSWorkspace.shared.notificationCenter
        let names: [Notification.Name] = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.didActivateApplicationNotification,
        ]
        for name in names {
            observers.append(nc.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.evaluate() }
            })
        }
        // Ao acordar do repouso o macOS pode religar o True Tone/mudar o brilho: reaplica.
        observers.append(nc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(2))
                    if self.isActive { self.enforce(reason: "Mac acordou") }
                    self.evaluate()
                }
            }
        })

        if settings.notify { requestNotificationPermission() }
        evaluate()
    }

    /// Chamado ao sair do app: nunca deixa a tela no "modo edição".
    func shutdown() {
        restoreTask?.cancel()
        if isActive { deactivate(reason: "app encerrado") }
    }

    // MARK: Lógica principal

    func evaluate() {
        let enabledApps = settings.apps.filter(\.isEnabled)
        var matches: [String] = []

        switch settings.triggerMode {
        case .running:
            for app in NSWorkspace.shared.runningApplications {
                if let m = enabledApps.first(where: { $0.matches(app.bundleIdentifier) }) {
                    matches.append(app.localizedName ?? m.name)
                }
            }
        case .frontmost:
            if let front = NSWorkspace.shared.frontmostApplication,
               let m = enabledApps.first(where: { $0.matches(front.bundleIdentifier) }) {
                matches.append(front.localizedName ?? m.name)
            }
        }

        triggeringApps = Array(Set(matches)).sorted()
        if matches.isEmpty { snoozed = false }
        let shouldBeActive = !paused && (manualOverride || (!matches.isEmpty && !snoozed))

        if shouldBeActive {
            restoreTask?.cancel()
            restoreTask = nil
            if !isActive {
                activate(reason: manualOverride ? "ativado manualmente" : triggeringApps.joined(separator: ", "))
            }
        } else if isActive && (restoreTask == nil || restoreNow) {
            restoreTask?.cancel()
            // Pausar restaura na hora; fechar/trocar de app respeita o atraso configurado.
            let immediate = paused || restoreNow
            restoreNow = false
            let delay = settings.restoreDelay
            restoreTask = Task { @MainActor [weak self] in
                if !immediate && delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
                guard let self, !Task.isCancelled else { return }
                self.restoreTask = nil
                self.deactivate(reason: immediate ? "automação pausada" : "apps de edição fechados")
            }
        }
        refreshStatus()
    }

    private func activate(reason: String) {
        var state = SavedDisplayState()

        if settings.disableTrueTone && trueToneSupported && DisplayControl.trueToneEnabled() {
            if DisplayControl.setTrueToneEnabled(false) { state.trueTone = true }
        }
        if settings.disableNightShift && nightShiftSupported && DisplayControl.nightShiftEnabled() {
            if DisplayControl.setNightShiftEnabled(false) { state.nightShift = true }
        }
        if settings.setBrightness {
            let current = DisplayControl.builtInBrightness()
            if current >= 0 { state.brightness = current }
            DisplayControl.setBuiltInBrightness(Float(settings.brightness))
        }

        saved = state
        state.persist()
        isActive = true
        notify(title: tr("TrueView ativado", "TrueView on"), body: reason)
        refreshStatus()
    }

    private func deactivate(reason: String) {
        if let saved { apply(restore: saved) }
        saved = nil
        SavedDisplayState.clear()
        isActive = false
        notify(title: tr("TrueView desativado", "TrueView off"), body: tr("Configurações de tela restauradas", "Display settings restored"))
        refreshStatus()
    }

    /// Só desfaz o que o próprio app mudou (se o True Tone já estava desligado, continua desligado).
    private func apply(restore state: SavedDisplayState) {
        if state.trueTone == true { DisplayControl.setTrueToneEnabled(true) }
        if state.nightShift == true { DisplayControl.setNightShiftEnabled(true) }
        if let b = state.brightness, settings.restoreBrightness { DisplayControl.setBuiltInBrightness(b) }
    }

    /// Reaplica o modo edição sem perder o estado original salvo.
    private func enforce(reason: String) {
        if settings.disableTrueTone && DisplayControl.trueToneEnabled() {
            DisplayControl.setTrueToneEnabled(false)
            if saved?.trueTone == nil { saved?.trueTone = true }
        }
        if settings.disableNightShift && DisplayControl.nightShiftEnabled() {
            DisplayControl.setNightShiftEnabled(false)
            if saved?.nightShift == nil { saved?.nightShift = true }
        }
        if settings.setBrightness { DisplayControl.setBuiltInBrightness(Float(settings.brightness)) }
        saved?.persist()
        refreshStatus()
    }

    private func settingsChanged(from old: AppSettings) {
        if isActive {
            // Mudanças nas ações valem na hora enquanto o modo edição está ligado.
            if settings.setBrightness && (settings.brightness != old.brightness || !old.setBrightness) {
                if saved?.brightness == nil, !old.setBrightness {
                    let cur = DisplayControl.builtInBrightness()
                    if cur >= 0 { saved?.brightness = cur }
                }
                DisplayControl.setBuiltInBrightness(Float(settings.brightness))
                saved?.persist()
            }
            if settings.disableTrueTone && !old.disableTrueTone || settings.disableNightShift && !old.disableNightShift {
                enforce(reason: "configuração alterada")
            }
        }
        if settings.notify && !old.notify { requestNotificationPermission() }
        evaluate()
    }

    // MARK: Controles manuais do menu

    func toggleTrueTone() {
        DisplayControl.setTrueToneEnabled(!DisplayControl.trueToneEnabled())
        refreshStatus()
    }

    func refreshStatus() {
        trueToneOn = DisplayControl.trueToneEnabled()
        nightShiftOn = DisplayControl.nightShiftEnabled()
    }

    // MARK: Utilidades

    private func requestNotificationPermission() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
    }

    private func notify(title: String, body: String) {
        guard settings.notify, Bundle.main.bundleIdentifier != nil else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
}
