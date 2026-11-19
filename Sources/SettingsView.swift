import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum SettingsTab: String, CaseIterable, Identifiable {
    case apps, trigger, general, about
    var id: String { rawValue }
    var title: String {
        switch self {
        case .apps: "Apps"
        case .trigger: tr("Gatilho", "Trigger")
        case .general: tr("Geral", "General")
        case .about: tr("Sobre", "About")
        }
    }
}

// Estado local das telas (as Command Line Tools não trazem o plugin do macro @State).
final class SettingsUIState: ObservableObject {
    @Published var tab: SettingsTab = .apps
    @Published var hovered: MonitoredApp.ID?
    @Published var dropTargeted = false
    @Published var launchAtLogin = LaunchAtLogin.isEnabled
    @Published var loginError: String?
}

struct SettingsView: View {
    @EnvironmentObject var engine: AutomationEngine
    @StateObject private var ui = SettingsUIState()

    var body: some View {
        VStack(spacing: 14) {
            tabBar
            Group {
                switch ui.tab {
                case .apps: AppsPane(ui: ui)
                case .trigger: TriggerPane()
                case .general: GeneralPane(ui: ui)
                case .about: AboutPane()
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .padding(.horizontal, 18).padding(.bottom, 18).padding(.top, 34)
        .frame(width: 440, height: 520)
        .containerBackground(.ultraThinMaterial, for: .window)
        .tint(.green)
    }

    private var tabBar: some View {
        GlassEffectContainer(spacing: 4) {
            HStack(spacing: 4) {
                ForEach(SettingsTab.allCases) { tab in
                    Button { withAnimation(.snappy) { ui.tab = tab } } label: {
                        Text(tab.title)
                            .font(.callout.weight(ui.tab == tab ? .semibold : .regular))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .contentShape(.capsule)
                    }
                    .buttonStyle(.plain)
                    .background {
                        if ui.tab == tab {
                            Capsule().fill(.background.opacity(0.85))
                                .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                        }
                    }
                }
            }
            .padding(4)
            .glassEffect(.regular, in: .capsule)
        }
    }
}

// MARK: - Apps

struct AppsPane: View {
    @EnvironmentObject var engine: AutomationEngine
    @ObservedObject var ui: SettingsUIState

    var body: some View {
        VStack(spacing: 10) {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach($engine.settings.apps) { $app in
                        row($app)
                        if app.id != engine.settings.apps.last?.id {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
                .padding(4)
            }
            .scrollIndicators(.never)
            .glassCard(18)
            .overlay {
                if ui.dropTargeted {
                    RoundedRectangle(cornerRadius: 18).strokeBorder(.green, lineWidth: 2)
                }
            }
            .dropDestination(for: URL.self) { urls, _ in
                urls.forEach(addApp(at:))
                return true
            } isTargeted: { ui.dropTargeted = $0 }

            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    GlassPillButton(title: tr("Adicionar app", "Add app"), symbol: "plus") { chooseApp() }
                    Menu {
                        ForEach(runningRegularApps(), id: \.processIdentifier) { app in
                            Button(app.localizedName ?? app.bundleIdentifier ?? "?") { add(app) }
                        }
                    } label: {
                        Label(tr("Dos abertos", "From open apps"), systemImage: "square.grid.2x2")
                            .font(.callout)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                    }
                    .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden)
                    .glassEffect(.regular.interactive(), in: .capsule)
                }
            }

            Text(tr("Arraste um app para a lista ou passe o mouse sobre ele para remover.",
                    "Drag an app onto the list, or hover over one to remove it."))
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func row(_ app: Binding<MonitoredApp>) -> some View {
        let a = app.wrappedValue
        let running = isRunning(a)
        return HStack(spacing: 12) {
            AppIconView(app: a, size: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(a.name).font(.system(size: 13))
                if running {
                    Text(tr("Aberto agora", "Open now")).font(.caption).foregroundStyle(.green)
                } else if a.icon == nil {
                    Text(a.bundleID).font(.caption).foregroundStyle(.tertiary).lineLimit(1)
                }
            }
            Spacer()
            if ui.hovered == a.id {
                Button {
                    withAnimation { engine.settings.apps.removeAll { $0.id == a.id } }
                } label: {
                    Image(systemName: "minus.circle.fill").font(.system(size: 16))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .help(tr("Remover", "Remove"))
                .transition(.opacity)
            }
            Toggle("", isOn: app.isEnabled).toggleStyle(.switch).labelsHidden().controlSize(.small)
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .contentShape(.rect)
        .onHover { inside in
            withAnimation(.easeOut(duration: 0.12)) {
                if inside { ui.hovered = a.id } else if ui.hovered == a.id { ui.hovered = nil }
            }
        }
    }

    private func isRunning(_ app: MonitoredApp) -> Bool {
        _ = engine.triggeringApps   // re-renderiza quando apps abrem/fecham
        return NSWorkspace.shared.runningApplications.contains { app.matches($0.bundleIdentifier) }
    }

    private func runningRegularApps() -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != Bundle.main.bundleIdentifier }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    private func add(_ app: NSRunningApplication) {
        guard let id = app.bundleIdentifier else { return }
        add(name: app.localizedName ?? id, bundleID: id)
    }

    private func add(name: String, bundleID: String) {
        guard !engine.settings.apps.contains(where: { $0.matches(bundleID) }) else { return }
        withAnimation { engine.settings.apps.append(MonitoredApp(name: name, bundleID: bundleID)) }
    }

    private func addApp(at url: URL) {
        guard url.pathExtension == "app", let bundle = Bundle(url: url), let id = bundle.bundleIdentifier else { return }
        let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
        add(name: name, bundleID: id)
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        NSApp.activate()
        guard panel.runModal() == .OK else { return }
        panel.urls.forEach(addApp(at:))
    }
}

// MARK: - Gatilho

struct TriggerPane: View {
    @EnvironmentObject var engine: AutomationEngine

    var body: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                Label(tr("Ativar quando", "Activate when"), systemImage: "bolt.fill").font(.headline)
                Picker("", selection: $engine.settings.triggerMode) {
                    ForEach(TriggerMode.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.radioGroup).labelsHidden()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14).glassCard(18)

            VStack(alignment: .leading, spacing: 10) {
                Label(tr("Ao fechar", "When closing"), systemImage: "arrow.uturn.backward").font(.headline)
                HStack {
                    Text(tr("Aguardar antes de restaurar", "Wait before restoring"))
                    Spacer()
                    Stepper("\(Int(engine.settings.restoreDelay)) s",
                            value: $engine.settings.restoreDelay, in: 0...60, step: 1)
                }
                HStack {
                    Text(tr("Voltar ao brilho anterior", "Restore previous brightness"))
                    Spacer()
                    Toggle("", isOn: $engine.settings.restoreBrightness)
                        .toggleStyle(.switch).labelsHidden().controlSize(.small)
                }
                Text(tr("Só é religado o que o TrueView desligou. Se o True Tone já estava desligado, continua desligado.",
                        "Only what TrueView turned off is turned back on. If True Tone was already off, it stays off."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14).glassCard(18)

            if engine.settings.setBrightness {
                Label(tr("Desligue \"Ajustar brilho automaticamente\" em Ajustes > Telas, senão o macOS pode mudar o brilho escolhido.",
                         "Turn off \"Automatically adjust brightness\" in Settings > Displays, or macOS may change the chosen brightness."),
                      systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Geral

struct GeneralPane: View {
    @EnvironmentObject var engine: AutomationEngine
    @ObservedObject var ui: SettingsUIState

    var body: some View {
        VStack(spacing: 2) {
            setting("power", tr("Abrir ao iniciar sessão", "Open at login")) {
                Toggle("", isOn: $ui.launchAtLogin)
                    .toggleStyle(.switch).labelsHidden().controlSize(.small)
                    .onChange(of: ui.launchAtLogin) { _, on in
                        guard on != LaunchAtLogin.isEnabled else { return }
                        do { try LaunchAtLogin.set(on); ui.loginError = nil }
                        catch { ui.loginError = error.localizedDescription; ui.launchAtLogin = LaunchAtLogin.isEnabled }
                    }
            }
            setting("bell.badge", tr("Notificar ao ativar/desativar", "Notify on activate/deactivate")) {
                Toggle("", isOn: $engine.settings.notify)
                    .toggleStyle(.switch).labelsHidden().controlSize(.small)
            }
            setting("globe", tr("Idioma", "Language")) {
                Picker("", selection: $engine.settings.language) {
                    ForEach(AppLanguage.allCases) { Text($0.label).tag($0) }
                }
                .labelsHidden().fixedSize()
            }
            if let err = ui.loginError {
                Text(err).font(.caption).foregroundStyle(.red).padding(8)
            }
        }
        .padding(4).glassCard(18)
    }

    private func setting<C: View>(_ symbol: String, _ title: String,
                                  @ViewBuilder control: () -> C) -> some View {
        HStack(spacing: 10) {
            SymbolTile(symbol: symbol, size: 22)
            Text(title).font(.system(size: 13))
            Spacer()
            control()
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
    }
}

// MARK: - Sobre

struct AboutPane: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
    }

    var body: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 10)
            SymbolTile(symbol: "camera.aperture", size: 88)
                .glassEffect(.regular, in: .rect(cornerRadius: 26))
            VStack(spacing: 4) {
                Text("TrueView").font(.system(size: 26, weight: .bold, design: .rounded))
                Text(tr("Versão \(version)", "Version \(version)"))
                    .font(.callout).foregroundStyle(.secondary)
            }
            Text(tr("Desliga o True Tone e ajusta a tela automaticamente quando você abre seus apps de edição.",
                    "Turns off True Tone and tunes your display automatically when you open your editing apps."))
                .multilineTextAlignment(.center).font(.callout).foregroundStyle(.secondary)
                .padding(.horizontal, 20)
            VStack(spacing: 2) {
                Text(tr("Desenvolvido por", "Developed by")).font(.caption).foregroundStyle(.secondary)
                Text("Lucas Haliax").font(.system(size: 15, weight: .semibold))
            }
            .padding(.horizontal, 22).padding(.vertical, 10)
            .glassEffect(.regular, in: .capsule)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
