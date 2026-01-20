//
//  WebView.swift
//  HealthyMe
//
//  A SwiftUI wrapper for WKWebView to display web content.
//  Used for displaying the privacy policy hosted on GitHub Pages.
//
//  Note: WKWebView spawns multiple subprocesses (Networking, GPU, WebContent)
//  on first use, which can take several seconds. We defer initialization
//  to avoid blocking the main thread during sheet presentation.
//

import SwiftUI
import WebKit

struct WebView: View {
    let url: URL
    let title: String

    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var hasError = false
    @State private var isWebViewReady = false

    private let logger: LoggerServiceProtocol = LoggerService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                if isWebViewReady {
                    WebViewRepresentable(
                        url: url,
                        isLoading: $isLoading,
                        hasError: $hasError,
                        logger: logger
                    )
                }

                if isLoading {
                    loadingView
                }

                if hasError {
                    errorView
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        logger.debug("WebView dismissed by user")
                        dismiss()
                    }
                }
            }
            .task {
                // Yield to let the sheet presentation complete before
                // spawning WebKit's heavy subprocesses
                logger.info("WebView: Preparing to load \(url.absoluteString)")
                await Task.yield()
                isWebViewReady = true
                logger.debug("WebView: Ready, starting WebKit processes")
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Unable to load page")
                .font(.headline)
            Text("Check your internet connection")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Try Again") {
                logger.info("WebView: User requested retry")
                hasError = false
                isLoading = true
                isWebViewReady = false
                Task {
                    await Task.yield()
                    isWebViewReady = true
                }
            }
            .buttonStyle(.bordered)
        }
    }
}

// MARK: - UIViewRepresentable Wrapper

/// Wraps WKWebView for use in SwiftUI.
/// Handles loading state updates via Coordinator pattern.
private struct WebViewRepresentable: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var hasError: Bool
    let logger: LoggerServiceProtocol

    func makeUIView(context: Context) -> WKWebView {
        logger.debug("WebView: Creating WKWebView instance")

        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        logger.debug("WebView: Starting URL request")
        webView.load(URLRequest(url: url))

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // No updates needed after initial load
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading, hasError: $hasError, logger: logger)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var isLoading: Bool
        @Binding var hasError: Bool
        let logger: LoggerServiceProtocol

        init(isLoading: Binding<Bool>, hasError: Binding<Bool>, logger: LoggerServiceProtocol) {
            _isLoading = isLoading
            _hasError = hasError
            self.logger = logger
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            logger.debug("WebView: Started provisional navigation")
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            logger.debug("WebView: Content started loading")
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            logger.info("WebView: Finished loading successfully")
            isLoading = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            logger.error("WebView: Navigation failed - \(error.localizedDescription)")
            isLoading = false
            hasError = true
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            logger.error("WebView: Provisional navigation failed - \(error.localizedDescription)")
            isLoading = false
            hasError = true
        }
    }
}

#Preview {
    WebView(
        url: URL(string: "https://milesofmichael.github.io/HealthyMe/privacy")!,
        title: "Privacy Policy"
    )
}
