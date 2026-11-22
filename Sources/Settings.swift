import Foundation
import AppKit

/// Um app que dispara o "modo edição".
/// `bundleID` aceita curinga no final: "com.captureone.*" pega todas as versões.
struct MonitoredApp: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var bundleID: String
    var isEnabled: Bool = true

    func matches(_ other: String?) -> Bool {
        guard let other else { return false }
        if bundleID.hasSuffix("*") {
            return other.lowercased().hasPrefix(bundleID.dropLast().lowercased())
        }
        return other.caseInsensitiveCompare(bundleID) == .orderedSame
    }

    var icon: NSImage? {
        guard !bundleID.hasSuffix("*"),
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    static let defaults: [MonitoredApp] = [
        .init(name: "Lightroom Classic", bundleID: "com.adobe.LightroomClassicCC7"),
        .init(name: "Lightroom", bundleID: "com.adobe.lightroomCC"),
        .init(name: "Photoshop", bundleID: "com.adobe.Photoshop"),
        .init(name: "Photos", bundleID: "com.apple.Photos"),
        .init(name: "Capture One", bundleID: "com.captureone.*"),
        .init(name: "Affinity Photo", bundleID: "com.seriflabs.affinityphoto*"),
        .init(name: "Pixelmator Pro", bundleID: "com.pixelmatorteam.pixelmator.x"),
        .init(name: "DaVinci Resolve", bundleID: "com.blackmagic-design.DaVinciResolve*"),
    ]
}

enum TriggerMode: String, Codable, CaseIterable, Identifiable {
    /// Ativa enquanto o app estiver aberto (mesmo em segundo plano).
    case running
    /// Ativa só quando o app está em primeiro plano.
    case frontmost

    var id: String { rawValue }
    var label: String {
        switch self {
        case .running: tr("Enquanto o app estiver aberto", "While the app is open")
        case .frontmost: tr("Só com o app em primeiro plano", "Only when the app is in front")
        }
    }
}

struct AppSettings: Codable, Equatable {
    var apps: [MonitoredApp] = MonitoredApp.defaults
    var triggerMode: TriggerMode = .running

    var disableTrueTone = true
    var disableNightShift = true
    var setBrightness = false
    var brightness: Double = 0.75          // 0…1
    var restoreBrightness = true

    /// Segundos de espera antes de restaurar (evita "piscar" ao trocar de app).
    var restoreDelay: Double = 2
    var notify = false
    var language: AppLanguage = .system
    var checkForUpdates = true

    // Decodificação tolerante: chaves novas em versões futuras não apagam as configs antigas.
    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        apps = (try? c.decode([MonitoredApp].self, forKey: .apps)) ?? d.apps
        triggerMode = (try? c.decode(TriggerMode.self, forKey: .triggerMode)) ?? d.triggerMode
        disableTrueTone = (try? c.decode(Bool.self, forKey: .disableTrueTone)) ?? d.disableTrueTone
        disableNightShift = (try? c.decode(Bool.self, forKey: .disableNightShift)) ?? d.disableNightShift
        setBrightness = (try? c.decode(Bool.self, forKey: .setBrightness)) ?? d.setBrightness
        brightness = (try? c.decode(Double.self, forKey: .brightness)) ?? d.brightness
        restoreBrightness = (try? c.decode(Bool.self, forKey: .restoreBrightness)) ?? d.restoreBrightness
        restoreDelay = (try? c.decode(Double.self, forKey: .restoreDelay)) ?? d.restoreDelay
        notify = (try? c.decode(Bool.self, forKey: .notify)) ?? d.notify
        language = (try? c.decode(AppLanguage.self, forKey: .language)) ?? d.language
        checkForUpdates = (try? c.decode(Bool.self, forKey: .checkForUpdates)) ?? d.checkForUpdates
    }

    private static let key = "settings.v1"

    static func load() -> AppSettings {
        // Migra as configurações da versão "Modo Edição" (bundle ID antigo).
        if UserDefaults.standard.data(forKey: key) == nil,
           let old = UserDefaults(suiteName: "local.modoedicao.app")?.data(forKey: key) {
            UserDefaults.standard.set(old, forKey: key)
        }
        guard let data = UserDefaults.standard.data(forKey: key),
              let s = try? JSONDecoder().decode(AppSettings.self, from: data) else { return AppSettings() }
        return s
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}

/// Estado da tela antes de entrar no modo edição. Fica salvo em disco para
/// que, se o app travar ou o Mac reiniciar, o estado original seja restaurado.
struct SavedDisplayState: Codable {
    var trueTone: Bool?
    var nightShift: Bool?
    var brightness: Float?

    private static let key = "pendingRestore.v1"

    static func load() -> SavedDisplayState? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(SavedDisplayState.self, from: data)
    }

    func persist() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    static func clear() { UserDefaults.standard.removeObject(forKey: key) }
}

enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case system, pt, en
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: tr("Sistema", "System")
        case .pt: "Português"
        case .en: "English"
        }
    }
}

/// Texto no idioma escolhido (Sistema segue o idioma preferido do macOS).
func tr(_ pt: String, _ en: String) -> String {
    let lang = MainActor.assumeIsolated { AutomationEngine.shared.settings.language }
    switch lang {
    case .pt: return pt
    case .en: return en
    case .system:
        let first = Locale.preferredLanguages.first ?? "en"
        return first.hasPrefix("pt") ? pt : en
    }
}
