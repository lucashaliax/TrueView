import SwiftUI

/// Ícone monocromático e discreto (SF Symbol sem fundo colorido).
struct SymbolTile: View {
    let symbol: String
    var color: Color = .primary
    var size: CGFloat = 28
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.6, weight: .medium))
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(color)
            .frame(width: size, height: size)
    }
}

struct AppIconView: View {
    let app: MonitoredApp
    var size: CGFloat = 28
    var body: some View {
        if let icon = app.icon {
            Image(nsImage: icon).resizable().frame(width: size, height: size)
        } else {
            SymbolTile(symbol: "app.dashed", color: .secondary, size: size * 0.85)
                .frame(width: size, height: size)
        }
    }
}

extension View {
    /// Cartão de vidro (Liquid Glass) com cantos arredondados.
    func glassCard(_ radius: CGFloat = 16) -> some View {
        glassEffect(.regular, in: .rect(cornerRadius: radius))
    }
}

/// Botão em cápsula de vidro.
struct GlassPillButton: View {
    let title: String?
    let symbol: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                if let title { Text(title) }
            }
            .font(.callout)
            .frame(maxWidth: title == nil ? nil : .infinity)
            .padding(.vertical, 7)
            .padding(.horizontal, 12)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
    }
}
