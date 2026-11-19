import SwiftUI
import AppKit

/// Painel que abre ao clicar no ícone da barra de menus.
struct MenuPanel: View {
    @EnvironmentObject var engine: AutomationEngine
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            VStack(spacing: 10) {
                header
                editModeCard
                actionsCard
                footer
            }
            .padding(12)
        }
        .frame(width: 310)
        .tint(.green)
    }

    // MARK: Cabeçalho

    private var header: some View {
        HStack(spacing: 10) {
            SymbolTile(symbol: "camera.aperture", size: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text("TrueView").font(.headline)
                Text(statusText).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Toggle(tr("Automação", "Automation"), isOn: Binding(
                get: { !engine.paused }, set: { engine.paused = !$0 }))
                .toggleStyle(.switch).labelsHidden().controlSize(.small)
                .help(tr("Ligar/pausar a automação", "Turn automation on/pause"))
        }
        .padding(.horizontal, 6).padding(.top, 4)
    }

    private var statusText: String {
        if engine.paused { return tr("Automação pausada", "Automation paused") }
        if engine.isActive {
            if engine.manualOverride { return tr("Ativo · manual", "Active · manual") }
            return tr("Ativo", "Active") + " · " + engine.triggeringApps.joined(separator: ", ")
        }
        return tr("Aguardando apps de edição", "Waiting for editing apps")
    }

    // MARK: Modo edição

    private var editModeCard: some View {
        HStack(spacing: 12) {
            SymbolTile(symbol: "photo", color: engine.isActive ? .green : .primary, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(tr("Modo edição", "Edit mode")).font(.system(size: 14, weight: .semibold))
                Text(engine.isActive ? tr("Ativo agora", "Active now")
                                     : tr("Liga automaticamente", "Turns on automatically"))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: Binding(get: { engine.editModeToggle }, set: { engine.editModeToggle = $0 }))
                .toggleStyle(.switch).labelsHidden()
        }
        .padding(12)
        .glassCard(18)
    }

    // MARK: Ações

    private var actionsCard: some View {
        VStack(spacing: 2) {
            ActionRow(symbol: "sun.max",
                      title: tr("Desligar True Tone", "Turn off True Tone"),
                      isOn: $engine.settings.disableTrueTone)
                .disabled(!engine.trueToneSupported)
            ActionRow(symbol: "moon",
                      title: tr("Desligar Night Shift", "Turn off Night Shift"),
                      isOn: $engine.settings.disableNightShift)
                .disabled(!engine.nightShiftSupported)
            ActionRow(symbol: "sun.max.circle",
                      title: tr("Brilho personalizado", "Custom brightness"),
                      isOn: $engine.settings.setBrightness)
            HStack(spacing: 8) {
                Image(systemName: "sun.min").foregroundStyle(.secondary)
                Slider(value: $engine.settings.brightness, in: 0.05...1)
                    .controlSize(.small)
                Text("\(Int((engine.settings.brightness * 100).rounded()))%")
                    .font(.caption).monospacedDigit().frame(width: 34, alignment: .trailing)
            }
            .padding(.leading, 42).padding(.trailing, 10).padding(.bottom, 8)
            .disabled(!engine.settings.setBrightness)
            .opacity(engine.settings.setBrightness ? 1 : 0.4)
        }
        .padding(4)
        .glassCard(18)
    }

    // MARK: Rodapé

    private var footer: some View {
        VStack(spacing: 8) {
            let enabled = engine.settings.apps.filter(\.isEnabled)
            HStack(spacing: 4) {
                Text(tr("Monitorando \(enabled.count) apps", "Watching \(enabled.count) apps"))
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                let withIcons = enabled.filter { $0.icon != nil }
                ForEach(withIcons.prefix(4)) { AppIconView(app: $0, size: 20) }
                if enabled.count > min(4, withIcons.count) {
                    Text("+\(enabled.count - min(4, withIcons.count))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)

            HStack(spacing: 8) {
                GlassPillButton(title: tr("Configurações", "Settings"), symbol: "gearshape") {
                    NSApp.activate()
                    openWindow(id: "settings")
                }
                GlassPillButton(title: nil, symbol: "power") { NSApp.terminate(nil) }
                    .help(tr("Sair do TrueView", "Quit TrueView"))
            }
        }
        .padding(.top, 2)
    }
}

struct ActionRow: View {
    let symbol: String
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 10) {
            SymbolTile(symbol: symbol, size: 22)
            Text(title).font(.system(size: 13))
            Spacer()
            Toggle("", isOn: $isOn).toggleStyle(.switch).labelsHidden().controlSize(.small)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
    }
}
