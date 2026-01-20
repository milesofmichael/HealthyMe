//
//  WebKitWarmer.swift
//  HealthyMe
//
//  Pre-warms WebKit processes at app launch.
//
//  WKWebView spawns three subprocesses on first use (Networking, GPU, WebContent)
//  which can take 2-4 seconds. By initializing a throwaway WKWebView early,
//  these processes are ready when the user actually needs them.
//

import WebKit

/// Handles pre-warming of WebKit processes to avoid delays when showing web content.
@MainActor
final class WebKitWarmer {
    static let shared = WebKitWarmer()

    private var warmerWebView: WKWebView?
    private let logger: LoggerServiceProtocol = LoggerService.shared

    private init() {}

    /// Call this at app launch to pre-warm WebKit processes.
    /// The processes will spin up in the background without blocking the UI.
    func warmUp() {
        logger.info("WebKitWarmer: Starting WebKit process pre-warm")

        // Create a minimal WKWebView - this triggers process launches
        let configuration = WKWebViewConfiguration()
        warmerWebView = WKWebView(frame: .zero, configuration: configuration)

        // Load a blank page to fully initialize the processes
        warmerWebView?.loadHTMLString("", baseURL: nil)

        logger.debug("WebKitWarmer: Pre-warm initiated")
    }

    /// Release the warmer WebView after processes are ready.
    /// Call this after a delay or when you're sure the processes have launched.
    func cleanup() {
        warmerWebView = nil
        logger.debug("WebKitWarmer: Cleaned up warmer WebView")
    }
}
