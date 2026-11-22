import AppKit
import Security
import UserNotifications

/// Updates the app from its GitHub releases: checks the latest release, downloads the zip,
/// verifies it and replaces the running app, then relaunches.
///
/// Copied from Floatr (App/Updater.swift); texts use TrueView's tr(pt, en).
/// Self-contained so it can be copied into other apps. Each app sets in its Info.plist:
///   UpdateRepository   "owner/name" on GitHub
/// and publishes releases tagged "vX.Y[.Z]" with "<CFBundleName>.zip" attached (the zipped .app).
///
/// Safety: the new app must have the same bundle identifier, a valid signature, and the same
/// signing team as the running app. Anything else is rejected and nothing is replaced.
@MainActor
final class Updater: ObservableObject {
    static let shared = Updater()

    struct Release: Equatable {
        let version: String
        let notes: String
        let zipURL: URL
        let pageURL: URL
    }

    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(Release)
        case downloading
        case installing
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    /// Hook for apps that send the user somewhere when they click an update notification.
    var onOpenRequested: (() -> Void)?

    private let lastCheckKey = "Updater.lastCheck"
    private let notifiedKey = "Updater.notifiedVersion"

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }
    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "App"
    }
    private var repository: String? {
        Bundle.main.object(forInfoDictionaryKey: "UpdateRepository") as? String
    }

    // MARK: Checking

    /// Asks GitHub for the latest release. Updates `state` and returns the release when it's newer.
    @discardableResult
    func check() async -> Release? {
        guard let repository, let api = URL(string: "https://api.github.com/repos/\(repository)/releases/latest") else {
            state = .failed(tr("Este app não tem fonte de atualizações.", "This app has no update source."))
            return nil
        }
        state = .checking
        do {
            var request = URLRequest(url: api, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = json["tag_name"] as? String,
                  let page = (json["html_url"] as? String).flatMap(URL.init(string:)) else {
                state = .failed(tr("Não foi possível ler a versão mais recente. Tente mais tarde.", "Couldn't read the latest release. Try again later."))
                return nil
            }
            UserDefaults.standard.set(Date(), forKey: lastCheckKey)
            let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            guard Self.isNewer(version, than: currentVersion) else {
                state = .upToDate
                return nil
            }
            let assets = json["assets"] as? [[String: Any]] ?? []
            guard let zip = assets.first(where: { ($0["name"] as? String) == "\(appName).zip" })?["browser_download_url"] as? String,
                  let zipURL = URL(string: zip) else {
                state = .failed(tr("A nova versão ainda não tem arquivo para instalar.", "The new version has no file to install yet."))
                return nil
            }
            let release = Release(version: version, notes: json["body"] as? String ?? "", zipURL: zipURL, pageURL: page)
            state = .available(release)
            return release
        } catch {
            state = .failed(tr("Não foi possível acessar o GitHub. Verifique a conexão e tente de novo.", "Couldn't reach GitHub. Check your connection and try again."))
            return nil
        }
    }

    /// Checks at most once a day; posts a notification the first time a version is found.
    func checkInBackgroundIfDue() {
        let last = UserDefaults.standard.object(forKey: lastCheckKey) as? Date ?? .distantPast
        guard Date().timeIntervalSince(last) > 24 * 3600 else { return }
        Task {
            guard let release = await check() else { return }
            guard UserDefaults.standard.string(forKey: notifiedKey) != release.version else { return }
            UserDefaults.standard.set(release.version, forKey: notifiedKey)
            await notify(release)
        }
    }

    static func isNewer(_ a: String, than b: String) -> Bool {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0, y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    // MARK: Installing

    func install(_ release: Release) {
        Task {
            state = .downloading
            do {
                let (file, response) = try await URLSession.shared.download(from: release.zipURL)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw UpdateError.download }
                state = .installing
                let current = Bundle.main.bundleURL
                let bundleID = Bundle.main.bundleIdentifier ?? ""
                let name = appName
                // Unzipping, verifying and swapping run off the main thread.
                try await Task.detached {
                    try Self.replaceApp(at: current, withZip: file, appName: name, bundleID: bundleID, version: release.version)
                }.value
                relaunch(at: current)
            } catch let error as UpdateError {
                state = .failed(error.message)
            } catch {
                state = .failed(UpdateError.download.message)
            }
        }
    }

    enum UpdateError: Error {
        case download, unzip, notTheSameApp, badSignature, cantReplace
        var message: String {
            switch self {
            case .download: tr("O download falhou. Tente de novo.", "The download failed. Try again.")
            case .unzip: tr("O arquivo baixado está danificado.", "The downloaded file is damaged.")
            case .notTheSameApp: tr("O app baixado não é a nova versão deste app. Nada foi alterado.", "The downloaded app isn't this app's new version. Nothing was changed.")
            case .badSignature: tr("O app baixado não foi assinado pelo mesmo desenvolvedor. Nada foi alterado.", "The downloaded app isn't signed by the same developer. Nothing was changed.")
            case .cantReplace: tr("Não foi possível substituir o app na pasta. Baixe pela página do release.", "Couldn't replace the app in its folder. Download it from the release page instead.")
            }
        }
    }

    nonisolated private static func replaceApp(at current: URL, withZip zip: URL, appName: String,
                                               bundleID: String, version: String) throws {
        let fm = FileManager.default
        let work = fm.temporaryDirectory.appendingPathComponent("Update-\(UUID().uuidString)")
        try fm.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: work) }

        guard run("/usr/bin/ditto", ["-x", "-k", zip.path, work.path]) else { throw UpdateError.unzip }
        let newApp = work.appendingPathComponent("\(appName).app")
        guard let newBundle = Bundle(url: newApp),
              newBundle.bundleIdentifier == bundleID,
              newBundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String == version else {
            throw UpdateError.notTheSameApp
        }
        guard let newTeam = teamIdentifier(of: newApp), newTeam == teamIdentifier(of: current) else {
            throw UpdateError.badSignature
        }
        _ = run("/usr/bin/xattr", ["-cr", newApp.path])
        do {
            _ = try fm.replaceItemAt(current, withItemAt: newApp)
        } catch {
            throw UpdateError.cantReplace
        }
    }

    /// Team ID of a validly signed app (nested code included), or nil.
    nonisolated private static func teamIdentifier(of app: URL) -> String? {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(app as CFURL, [], &code) == errSecSuccess, let code else { return nil }
        let flags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSCheckNestedCode | kSecCSStrictValidate)
        guard SecStaticCodeCheckValidity(code, flags, nil) == errSecSuccess else { return nil }
        var info: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess else { return nil }
        return (info as? [String: Any])?[kSecCodeInfoTeamIdentifier as String] as? String
    }

    @discardableResult
    nonisolated private static func run(_ tool: String, _ args: [String]) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = args
        do { try p.run() } catch { return false }
        p.waitUntilExit()
        return p.terminationStatus == 0
    }

    private func relaunch(at app: URL) {
        // App extensions keep running inside their host with the old code; stop them so the
        // host starts the new ones (Safari does this on the next message).
        let plugins = app.appendingPathComponent("Contents/PlugIns").path
        _ = Self.run("/usr/bin/pkill", ["-f", plugins + "/"])
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 1; /usr/bin/open \"$0\"", app.path]
        try? task.run()
        NSApp.terminate(nil)
    }

    // MARK: Notification

    private func notify(_ release: Release) async {
        let center = UNUserNotificationCenter.current()
        // Provisional: delivered quietly to Notification Center, no permission prompt.
        _ = try? await center.requestAuthorization(options: [.alert, .provisional])
        let content = UNMutableNotificationContent()
        content.title = tr("\(appName) \(release.version) está disponível", "\(appName) \(release.version) is available")
        content.body = tr("Clique para atualizar.", "Click to update.")
        try? await center.add(UNNotificationRequest(identifier: "update-\(release.version)", content: content, trigger: nil))
    }
}
