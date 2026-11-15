// Claude Sessions Dashboard.app — runs the bundled server.py and shows it in a WKWebView.
import Cocoa
import WebKit

let appName = "Claude Sessions Dashboard"

// Pick a free localhost port so we never clash with a manually started server on 8765.
func freePort() -> Int {
    let fd = socket(AF_INET, SOCK_STREAM, 0)
    defer { close(fd) }
    var addr = sockaddr_in()
    addr.sin_family = sa_family_t(AF_INET)
    addr.sin_port = 0
    addr.sin_addr.s_addr = inet_addr("127.0.0.1")
    var len = socklen_t(MemoryLayout<sockaddr_in>.size)
    _ = withUnsafeMutablePointer(to: &addr) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, len) }
    }
    _ = withUnsafeMutablePointer(to: &addr) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(fd, $0, &len) }
    }
    return Int(UInt16(bigEndian: addr.sin_port))
}

final class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate, WKUIDelegate {
    var window: NSWindow!
    var webView: WKWebView!
    var server: Process?
    var url: URL!

    func applicationDidFinishLaunching(_ note: Notification) {
        buildMenu()
        webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.navigationDelegate = self
        webView.uiDelegate = self
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1280, height: 860),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        window.title = appName
        window.contentView = webView
        window.setFrameAutosaveName("main")
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        startServer()
    }

    // Server files are copied out of the bundle to Application Support, so the server's
    // own state file (attach-tabs.json) never writes inside the signed app bundle.
    func startServer() {
        let fm = FileManager.default
        let res = Bundle.main.resourceURL!.appendingPathComponent("server")
        let work = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(appName)
        try? fm.createDirectory(at: work, withIntermediateDirectories: true)
        for name in (try? fm.contentsOfDirectory(atPath: res.path)) ?? [] {
            let dst = work.appendingPathComponent(name)
            try? fm.removeItem(at: dst)
            try? fm.copyItem(at: res.appendingPathComponent(name), to: dst)
        }

        let port = freePort()
        url = URL(string: "http://127.0.0.1:\(port)/")!
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        p.arguments = [work.appendingPathComponent("server.py").path, "--no-open"]
        p.currentDirectoryURL = work
        var env = ProcessInfo.processInfo.environment
        env["PORT"] = String(port)
        env["PYTHONDONTWRITEBYTECODE"] = "1"
        // GUI apps get a minimal PATH; add the usual places for claude / orca CLIs.
        env["PATH"] = "\(NSHomeDirectory())/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        p.environment = env
        p.terminationHandler = { proc in
            DispatchQueue.main.async {
                guard !NSApp.isTerminating_ else { return }
                self.showError("The dashboard server stopped (exit \(proc.terminationStatus)).")
            }
        }
        do { try p.run() } catch { showError("Could not start python3: \(error.localizedDescription)"); return }
        server = p
        waitForServer(tries: 50)
    }

    func waitForServer(tries: Int) {
        URLSession.shared.dataTask(with: url) { _, resp, _ in
            DispatchQueue.main.async {
                if (resp as? HTTPURLResponse)?.statusCode == 200 {
                    self.webView.load(URLRequest(url: self.url))
                } else if tries > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self.waitForServer(tries: tries - 1) }
                } else {
                    self.showError("The dashboard server did not start.")
                }
            }
        }.resume()
    }

    func showError(_ msg: String) {
        webView.loadHTMLString("<body style='font:15px -apple-system;padding:40px;color:#888'>\(msg)</body>", baseURL: nil)
    }

    // Links to anything other than the dashboard (Jira, PRs, target=_blank) open in the default browser.
    func webView(_ wv: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let u = action.request.url, u.host != "127.0.0.1", u.scheme != "about" {
            NSWorkspace.shared.open(u); decisionHandler(.cancel); return
        }
        decisionHandler(.allow)
    }

    func webView(_ wv: WKWebView, createWebViewWith c: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let u = action.request.url { NSWorkspace.shared.open(u) }
        return nil
    }

    func webView(_ wv: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let a = NSAlert(); a.messageText = message
        a.addButton(withTitle: "OK"); a.addButton(withTitle: "Cancel")
        completionHandler(a.runModal() == .alertFirstButtonReturn)
    }

    func webView(_ wv: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let a = NSAlert(); a.messageText = message; a.runModal(); completionHandler()
    }

    @objc func reload(_ sender: Any?) { webView.reload() }

    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool { true }

    func applicationWillTerminate(_ note: Notification) {
        NSApp.isTerminating_ = true
        server?.terminate()
    }

    func buildMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem(); main.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Hide \(appName)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        let editItem = NSMenuItem(); main.addItem(editItem)
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit

        let viewItem = NSMenuItem(); main.addItem(viewItem)
        let view = NSMenu(title: "View")
        view.addItem(withTitle: "Reload", action: #selector(reload(_:)), keyEquivalent: "r")
        viewItem.submenu = view

        let winItem = NSMenuItem(); main.addItem(winItem)
        let win = NSMenu(title: "Window")
        win.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        win.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        winItem.submenu = win
        NSApp.windowsMenu = win
        NSApp.mainMenu = main
    }
}

extension NSApplication {
    private static var terminating = false
    var isTerminating_: Bool {
        get { NSApplication.terminating }
        set { NSApplication.terminating = newValue }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
