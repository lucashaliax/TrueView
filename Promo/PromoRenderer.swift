// Gera as imagens promocionais do TrueView (2880×1800, PNG).
// Rode a partir da raiz do repositório:
//   swiftc -O -swift-version 5 Promo/PromoRenderer.swift -o build/promo-render && build/promo-render
import SwiftUI
import AppKit

// MARK: - Paleta e componentes de "vidro"

let canvas = CGSize(width: 1440, height: 900)
let ink = Color.white
let inkSecondary = Color(white: 0.62)
let accent = Color(red: 0.20, green: 0.80, blue: 0.40)
let warm = Color(red: 1.0, green: 0.84, blue: 0.62)

let appIcon: NSImage = NSImage(contentsOfFile: "Icon/icon_1024.png") ?? NSImage()

/// Fundo grafite com o brilho espectral do ícone.
struct Backdrop: View {
    var glow: [(Color, CGPoint, CGFloat)] = [
        (.purple, CGPoint(x: 0.85, y: 0.15), 520),
        (.orange, CGPoint(x: 0.95, y: 0.95), 460),
        (.cyan, CGPoint(x: 0.15, y: 0.9), 420),
    ]
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(white: 0.11), Color(white: 0.03)], startPoint: .top, endPoint: .bottom)
            ForEach(Array(glow.enumerated()), id: \.offset) { _, g in
                Circle().fill(g.0)
                    .frame(width: g.2, height: g.2)
                    .position(x: g.1.x * canvas.width, y: g.1.y * canvas.height)
                    .blur(radius: 140)
                    .opacity(0.45)
            }
        }
        .frame(width: canvas.width, height: canvas.height)
        .clipped()
    }
}

/// Superfície de vidro simulada (o glassEffect real não aparece em renderização fora da tela).
struct Glass: ViewModifier {
    var radius: CGFloat
    var strength: Double = 1
    func body(content: Content) -> some View {
        content
            .background {
                let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
                ZStack {
                    shape.fill(Color(white: 0.16).opacity(0.72 * strength))
                    shape.fill(LinearGradient(colors: [.white.opacity(0.14 * strength), .white.opacity(0.02)],
                                              startPoint: .top, endPoint: .bottom))
                    shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.42), .white.opacity(0.06), .white.opacity(0.16)],
                                                      startPoint: .topLeading, endPoint: .bottomTrailing),
                                       lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
            }
    }
}

extension View {
    func glass(_ radius: CGFloat, strength: Double = 1) -> some View { modifier(Glass(radius: radius, strength: strength)) }
}

struct FakeToggle: View {
    var on: Bool
    var scale: CGFloat = 1
    var body: some View {
        ZStack(alignment: on ? .trailing : .leading) {
            Capsule().fill(on ? accent : Color(white: 0.32))
            Circle().fill(.white).padding(2).shadow(color: .black.opacity(0.2), radius: 1, y: 1)
        }
        .frame(width: 36 * scale, height: 21 * scale)
    }
}

struct Pill: View {
    var text: String
    var symbol: String? = nil
    var size: CGFloat = 15
    var body: some View {
        HStack(spacing: 7) {
            if let symbol { Image(systemName: symbol) }
            Text(text)
        }
        .font(.system(size: size, weight: .medium))
        .foregroundStyle(ink)
        .padding(.horizontal, size * 0.95).padding(.vertical, size * 0.55)
        .glass(100)
    }
}

// MARK: - Réplica do painel da barra de menus

struct PanelReplica: View {
    var status = "Active · Lightroom Classic"
    var editOn = true
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "camera.aperture").font(.system(size: 18, weight: .medium)).frame(width: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text("TrueView").font(.system(size: 14, weight: .bold))
                    Text(status).font(.system(size: 11)).foregroundStyle(inkSecondary)
                }
                Spacer()
                FakeToggle(on: true, scale: 0.85)
            }
            .padding(.horizontal, 6).padding(.top, 4)

            HStack(spacing: 12) {
                Image(systemName: "photo").font(.system(size: 19, weight: .medium))
                    .foregroundStyle(editOn ? accent : ink).frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Edit mode").font(.system(size: 14, weight: .semibold))
                    Text(editOn ? "Active now" : "Turns on automatically").font(.system(size: 11)).foregroundStyle(inkSecondary)
                }
                Spacer()
                FakeToggle(on: editOn)
            }
            .padding(12).glass(18, strength: 0.8)

            VStack(spacing: 0) {
                row("sun.max", "Turn off True Tone", true)
                row("moon", "Turn off Night Shift", true)
                row("sun.max.circle", "Custom brightness", true)
                HStack(spacing: 8) {
                    Image(systemName: "sun.min").font(.system(size: 11)).foregroundStyle(inkSecondary)
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(white: 0.3)).frame(height: 4)
                        Capsule().fill(accent).frame(width: 120, height: 4)
                        Circle().fill(.white).frame(width: 15, height: 15).offset(x: 113)
                    }
                    Text("75%").font(.system(size: 11)).monospacedDigit()
                }
                .padding(.leading, 42).padding(.trailing, 10).padding(.bottom, 9).padding(.top, 2)
            }
            .padding(4).glass(18, strength: 0.8)

            HStack(spacing: 8) {
                HStack(spacing: 6) { Image(systemName: "gearshape"); Text("Settings") }
                    .font(.system(size: 13)).frame(maxWidth: .infinity).padding(.vertical, 7).glass(100, strength: 0.8)
                Image(systemName: "power").font(.system(size: 13)).padding(.vertical, 7).padding(.horizontal, 12)
                    .glass(100, strength: 0.8)
            }
            .padding(.top, 2)
        }
        .foregroundStyle(ink)
        .padding(12)
        .frame(width: 310)
        .glass(24)
    }

    private func row(_ symbol: String, _ title: String, _ on: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 14, weight: .medium)).frame(width: 22)
            Text(title).font(.system(size: 13))
            Spacer()
            FakeToggle(on: on, scale: 0.85)
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
    }
}

/// Faixa da barra de menus do macOS com o ícone do TrueView em destaque.
struct MenuBarStrip: View {
    var body: some View {
        HStack(spacing: 22) {
            Image(systemName: "apple.logo").font(.system(size: 15))
            Text("Lightroom Classic").font(.system(size: 13, weight: .bold))
            ForEach(["File", "Edit", "Library", "Photo", "View", "Window", "Help"], id: \.self) {
                Text($0).font(.system(size: 13))
            }
            Spacer()
            Image(systemName: "wifi")
            Image(systemName: "battery.75percent")
            Image(systemName: "camera.aperture").font(.system(size: 15, weight: .medium))
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(.white.opacity(0.22)))
            Text("Wed 9:41").font(.system(size: 13))
        }
        .font(.system(size: 13))
        .foregroundStyle(ink)
        .padding(.horizontal, 20)
        .frame(width: canvas.width, height: 32)
        .background(Color.black.opacity(0.35))
    }
}

// MARK: - 1. Hero

struct HeroSlide: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            Backdrop()
            MenuBarStrip()
            HStack(alignment: .center, spacing: 70) {
                VStack(alignment: .leading, spacing: 26) {
                    Image(nsImage: appIcon).resizable().frame(width: 150, height: 150)
                        .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
                    Text("TrueView").font(.system(size: 26, weight: .semibold)).foregroundStyle(inkSecondary)
                    Text("True color.\nAutomatically.")
                        .font(.system(size: 88, weight: .bold)).tracking(-1.5)
                        .foregroundStyle(ink).lineSpacing(-6)
                    Text("Turns off True Tone the moment you open\nyour photo editor — and brings it back when you're done.")
                        .font(.system(size: 22)).foregroundStyle(inkSecondary).lineSpacing(4)
                }
                Spacer(minLength: 0)
                PanelReplica()
                    .scaleEffect(1.45)
                    .frame(width: 450, height: 600)
            }
            .padding(.horizontal, 110)
            .frame(width: canvas.width, height: canvas.height)
            .offset(y: 16)
        }
        .frame(width: canvas.width, height: canvas.height)
    }
}

// MARK: - 2. Como funciona

struct HowSlide: View {
    var body: some View {
        ZStack {
            Backdrop(glow: [(.orange, CGPoint(x: 0.5, y: 0.55), 620), (.purple, CGPoint(x: 0.1, y: 0.1), 380),
                            (.cyan, CGPoint(x: 0.95, y: 0.2), 380)])
            VStack(spacing: 0) {
                Text("Open. Edit. Done.").font(.system(size: 80, weight: .bold)).tracking(-1.5).foregroundStyle(ink)
                Text("TrueView watches your editing apps and handles the display for you.")
                    .font(.system(size: 24)).foregroundStyle(inkSecondary).padding(.top, 14)

                HStack(spacing: 22) {
                    step(1, symbol: "photo.on.rectangle.angled", slash: false, title: "Open your editor",
                         text: "Lightroom, Photoshop, Photos —\nor any app you choose.")
                    arrow
                    step(2, symbol: "sun.max", slash: true, title: "True Tone turns off",
                         text: "Night Shift too, and brightness\ngoes to the level you set.")
                    arrow
                    step(3, symbol: "arrow.uturn.backward", slash: false, title: "Close it. All restored.",
                         text: "Only what TrueView changed\ngoes back. Nothing else.")
                }
                .padding(.top, 70)

                HStack(spacing: 12) {
                    ForEach(["Lightroom Classic", "Lightroom", "Photoshop", "Photos", "Capture One", "Affinity Photo", "Pixelmator Pro"], id: \.self) {
                        Pill(text: $0, size: 14)
                    }
                    Pill(text: "Any app", symbol: "plus", size: 14)
                }
                .padding(.top, 60)
            }
        }
        .frame(width: canvas.width, height: canvas.height)
    }

    private var arrow: some View {
        Image(systemName: "chevron.right").font(.system(size: 30, weight: .semibold)).foregroundStyle(Color(white: 0.4))
    }

    private func step(_ n: Int, symbol: String, slash: Bool, title: String, text: String) -> some View {
        VStack(spacing: 22) {
            ZStack {
                Circle().fill(Color.white.opacity(0.08)).frame(width: 112, height: 112)
                    .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1))
                Image(systemName: symbol).font(.system(size: 46, weight: .regular)).foregroundStyle(n == 2 ? warm : ink)
                if slash {
                    Capsule().fill(ink).frame(width: 4, height: 82).rotationEffect(.degrees(-45))
                        .shadow(color: .black.opacity(0.6), radius: 0, x: 2, y: 0)
                }
            }
            Text("\(n)").font(.system(size: 14, weight: .bold)).foregroundStyle(.black)
                .frame(width: 26, height: 26).background(Circle().fill(accent))
            VStack(spacing: 10) {
                Text(title).font(.system(size: 27, weight: .semibold)).foregroundStyle(ink)
                Text(text).font(.system(size: 18)).foregroundStyle(inkSecondary).multilineTextAlignment(.center).lineSpacing(3)
            }
        }
        .frame(width: 330, height: 370)
        .glass(32)
    }
}

// MARK: - 3. Antes / depois

struct Landscape: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                LinearGradient(stops: [
                    .init(color: Color(red: 0.36, green: 0.55, blue: 0.86), location: 0),
                    .init(color: Color(red: 0.72, green: 0.80, blue: 0.93), location: 0.45),
                    .init(color: Color(red: 0.98, green: 0.90, blue: 0.86), location: 0.62),
                ], startPoint: .top, endPoint: .bottom)
                Circle().fill(Color(red: 1, green: 0.97, blue: 0.92)).frame(width: 110).position(x: w * 0.5, y: h * 0.36)
                    .blur(radius: 2)
                mountain([(0, 0.62), (0.12, 0.42), (0.24, 0.55), (0.38, 0.30), (0.52, 0.50), (0.66, 0.36), (0.82, 0.52), (1, 0.40)], w, h)
                    .fill(Color(red: 0.55, green: 0.62, blue: 0.75))
                mountain([(0, 0.72), (0.18, 0.55), (0.34, 0.66), (0.5, 0.52), (0.7, 0.68), (0.86, 0.58), (1, 0.66)], w, h)
                    .fill(Color(red: 0.30, green: 0.40, blue: 0.48))
                Rectangle().fill(LinearGradient(colors: [Color(red: 0.42, green: 0.58, blue: 0.80), Color(red: 0.16, green: 0.26, blue: 0.36)],
                                                startPoint: .top, endPoint: .bottom))
                    .frame(height: h * 0.28).position(x: w / 2, y: h * 0.86)
                mountain([(0, 1), (0, 0.82), (0.2, 0.76), (0.45, 0.84), (0.7, 0.79), (1, 0.85), (1, 1)], w, h, closeBottom: false)
                    .fill(Color(red: 0.10, green: 0.16, blue: 0.14))
            }
        }
    }

    private func mountain(_ pts: [(CGFloat, CGFloat)], _ w: CGFloat, _ h: CGFloat, closeBottom: Bool = true) -> Path {
        Path { p in
            p.move(to: CGPoint(x: pts[0].0 * w, y: pts[0].1 * h))
            for pt in pts.dropFirst() { p.addLine(to: CGPoint(x: pt.0 * w, y: pt.1 * h)) }
            if closeBottom { p.addLine(to: CGPoint(x: w, y: h)); p.addLine(to: CGPoint(x: 0, y: h)) }
            p.closeSubpath()
        }
    }
}

struct CompareSlide: View {
    let photo = CGSize(width: 1180, height: 560)
    var body: some View {
        ZStack {
            Backdrop(glow: [(.blue, CGPoint(x: 0.8, y: 0.2), 480), (.orange, CGPoint(x: 0.15, y: 0.75), 460)])
            VStack(spacing: 0) {
                Text("See your photos as they really are.")
                    .font(.system(size: 64, weight: .bold)).tracking(-1.2).foregroundStyle(ink)
                Text("True Tone warms the screen to match the room. Great for reading — wrong for editing.")
                    .font(.system(size: 22)).foregroundStyle(inkSecondary).padding(.top, 12)

                ZStack {
                    Landscape()
                    // Metade esquerda: como a tela mostra com o True Tone ligado.
                    Landscape()
                        .overlay(Color(red: 1.0, green: 0.62, blue: 0.22).opacity(0.30))
                        .saturation(0.9)
                        .mask(alignment: .leading) { Rectangle().frame(width: photo.width / 2) }
                    Rectangle().fill(.white).frame(width: 3)
                    Image(systemName: "arrow.left.and.right")
                        .font(.system(size: 20, weight: .bold)).foregroundStyle(ink)
                        .frame(width: 58, height: 58)
                        .background(Circle().fill(Color(white: 0.15).opacity(0.75)))
                        .overlay(Circle().strokeBorder(.white.opacity(0.6), lineWidth: 1.5))
                    VStack {
                        HStack {
                            Pill(text: "True Tone on", symbol: "sun.max", size: 16)
                            Spacer()
                            Pill(text: "TrueView", symbol: "camera.aperture", size: 16)
                        }
                        Spacer()
                    }
                    .padding(22)
                }
                .frame(width: photo.width, height: photo.height)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(.white.opacity(0.25), lineWidth: 1))
                .compositingGroup()
                .shadow(color: .black.opacity(0.5), radius: 40, y: 20)
                .padding(.top, 50)
            }
        }
        .frame(width: canvas.width, height: canvas.height)
    }
}

// MARK: - 4. Controle

struct SettingsReplica: View {
    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                Circle().fill(Color(red: 1, green: 0.37, blue: 0.34)).frame(width: 12)
                Circle().fill(Color(red: 1, green: 0.74, blue: 0.18)).frame(width: 12)
                Circle().fill(Color(red: 0.16, green: 0.78, blue: 0.25)).frame(width: 12)
                Spacer()
            }
            HStack(spacing: 4) {
                ForEach(["Apps", "Trigger", "General", "About"], id: \.self) { t in
                    Text(t).font(.system(size: 13, weight: t == "Apps" ? .semibold : .regular))
                        .foregroundStyle(t == "Apps" ? Color.black : ink)
                        .frame(maxWidth: .infinity).padding(.vertical, 6)
                        .background { if t == "Apps" { Capsule().fill(.white.opacity(0.9)) } }
                }
            }
            .padding(4).glass(100, strength: 0.8)

            VStack(spacing: 0) {
                appRow("Lightroom Classic", "camera.aperture", open: true, on: true)
                appRow("Lightroom", "cloud", open: false, on: true)
                appRow("Photoshop", "paintbrush.pointed", open: false, on: true)
                appRow("Photos", "photo.stack", open: false, on: true)
                appRow("Capture One", "camera", open: false, on: false)
                appRow("Pixelmator Pro", "wand.and.stars", open: false, on: true, last: true)
            }
            .padding(4).glass(18, strength: 0.8)

            HStack(spacing: 8) {
                Label("Add app", systemImage: "plus").frame(maxWidth: .infinity).padding(.vertical, 7).glass(100, strength: 0.8)
                Label("From open apps", systemImage: "square.grid.2x2").frame(maxWidth: .infinity).padding(.vertical, 7)
                    .glass(100, strength: 0.8)
            }
            .font(.system(size: 13))
        }
        .foregroundStyle(ink)
        .padding(.horizontal, 18).padding(.vertical, 16)
        .frame(width: 440)
        .glass(26)
    }

    private func appRow(_ name: String, _ symbol: String, open: Bool, on: Bool, last: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: symbol).font(.system(size: 16, weight: .medium))
                    .foregroundStyle(open ? accent : ink).frame(width: 30, height: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(name).font(.system(size: 13))
                    if open { Text("Open now").font(.system(size: 11)).foregroundStyle(accent) }
                }
                Spacer()
                FakeToggle(on: on, scale: 0.85)
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            if !last { Rectangle().fill(.white.opacity(0.08)).frame(height: 1).padding(.leading, 52) }
        }
    }
}

struct ControlSlide: View {
    let features: [(String, String)] = [
        ("sun.max.circle", "Custom brightness"),
        ("moon", "Night Shift off"),
        ("timer", "Restore delay"),
        ("macwindow.on.rectangle", "Frontmost-only mode"),
        ("power", "Open at login"),
        ("globe", "English · Português"),
    ]
    var body: some View {
        ZStack {
            Backdrop(glow: [(.green, CGPoint(x: 0.8, y: 0.5), 460), (.purple, CGPoint(x: 0.2, y: 0.15), 420),
                            (.orange, CGPoint(x: 0.3, y: 1.0), 400)])
            HStack(alignment: .center, spacing: 80) {
                VStack(alignment: .leading, spacing: 22) {
                    Text("You're in\ncontrol.").font(.system(size: 84, weight: .bold)).tracking(-1.5).foregroundStyle(ink)
                    Text("Pick the apps. Pick what happens.\nTrueView only undoes what it changed.")
                        .font(.system(size: 22)).foregroundStyle(inkSecondary).lineSpacing(4)
                    LazyVGrid(columns: [GridItem(.fixed(250), alignment: .leading), GridItem(.fixed(250), alignment: .leading)],
                              alignment: .leading, spacing: 14) {
                        ForEach(features, id: \.1) { f in
                            HStack(spacing: 10) {
                                Image(systemName: f.0).font(.system(size: 17, weight: .medium)).frame(width: 24)
                                Text(f.1).font(.system(size: 16, weight: .medium))
                            }
                            .foregroundStyle(ink)
                            .padding(.horizontal, 16).padding(.vertical, 12)
                            .frame(width: 240, alignment: .leading)
                            .glass(16)
                        }
                    }
                    .padding(.top, 18)
                }
                SettingsReplica()
                    .scaleEffect(1.3)
                    .frame(width: 572, height: 640)
            }
            .padding(.horizontal, 100)
        }
        .frame(width: canvas.width, height: canvas.height)
    }
}

// MARK: - Renderização

@MainActor func render<V: View>(_ view: V, _ path: String) {
    let r = ImageRenderer(content: view.environment(\.colorScheme, .dark))
    r.scale = 2
    guard let img = r.cgImage else { fatalError("falha ao renderizar \(path)") }
    let rep = NSBitmapImageRep(cgImage: img)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
    print("ok \(path) \(img.width)×\(img.height)")
}

MainActor.assumeIsolated {
    render(HeroSlide(), "Promo/01-hero.png")
    render(HowSlide(), "Promo/02-how-it-works.png")
    render(CompareSlide(), "Promo/03-true-color.png")
    render(ControlSlide(), "Promo/04-control.png")
}
