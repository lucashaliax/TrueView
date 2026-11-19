// Gera o ícone do TrueView (1024×1024) com SwiftUI: swift Icon/IconRenderer.swift <saida.png>
import SwiftUI
import AppKit

struct TrueViewIcon: View {
    var body: some View {
        ZStack {
            // Corpo do ícone no grid do macOS (824 pt dentro de 1024, cantos contínuos).
            let shape = RoundedRectangle(cornerRadius: 186, style: .continuous)
            shape
                .fill(LinearGradient(colors: [Color(red: 0.20, green: 0.21, blue: 0.24),
                                              Color(red: 0.05, green: 0.05, blue: 0.07)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay {
                    // Brilho espectral difuso atrás da lente: a "luz real" da tela.
                    // Brilho espectral difuso atrás da lente: a "luz real" da tela.
                    Circle()
                        .fill(AngularGradient(colors: [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink, .red],
                                              center: .center))
                        .frame(width: 560, height: 560)
                        .blur(radius: 70)
                        .opacity(0.75)
                }
                .clipShape(shape)
                .overlay {
                    shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0.02)],
                                                      startPoint: .top, endPoint: .bottom), lineWidth: 3)
                }
                .frame(width: 824, height: 824)
                .shadow(color: .black.opacity(0.35), radius: 24, y: 14)

            // Lente de vidro.
            ZStack {
                // Metade quente (True Tone ligado) x metade neutra (cor real).
                // Metade quente (True Tone ligado) x metade neutra (cor real).
                Circle()
                    .fill(LinearGradient(stops: [
                        .init(color: Color(red: 1.0, green: 0.72, blue: 0.38).opacity(0.55), location: 0),
                        .init(color: Color(red: 1.0, green: 0.72, blue: 0.38).opacity(0.30), location: 0.5),
                        .init(color: .white.opacity(0.22), location: 0.5),
                        .init(color: .white.opacity(0.10), location: 1),
                    ], startPoint: .leading, endPoint: .trailing))
                // Reflexo especular.
                Ellipse()
                    .fill(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 360, height: 190)
                    .offset(y: -150)
                    .blur(radius: 6)
                // Aro da lente.
                Circle()
                    .strokeBorder(LinearGradient(colors: [.white.opacity(0.95), .white.opacity(0.15), .white.opacity(0.55)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing),
                                  lineWidth: 7)
                // Diafragma.
                Image(systemName: "camera.aperture")
                    .font(.system(size: 250, weight: .ultraLight))
                    .foregroundStyle(.white.opacity(0.92))
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
            }
            .frame(width: 500, height: 500)
            .shadow(color: .black.opacity(0.45), radius: 30, y: 18)
        }
        .frame(width: 1024, height: 1024)
    }
}

@MainActor func render(_ path: String) {
    let r = ImageRenderer(content: TrueViewIcon())
    r.scale = 1
    guard let img = r.cgImage else { fatalError("render falhou") }
    let rep = NSBitmapImageRep(cgImage: img)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

MainActor.assumeIsolated { render(CommandLine.arguments.dropFirst().first ?? "icon_1024.png") }
