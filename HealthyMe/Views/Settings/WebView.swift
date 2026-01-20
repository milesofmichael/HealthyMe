//
//  WebView.swift
//  HealthyMe
//
//  A SwiftUI wrapper for WKWebView to display web content.
//  Used for displaying the privacy policy hosted on GitHub Pages.
//

import SwiftUI
import WebKit

struct WebView: View {
    let url: URL
    let title: String

    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ZStack {
                WebViewRepresentable(url: url, isLoading: $isLoading)

                if isLoading {
                    ProgressView()
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - UIViewRepresentable Wrapper

/// Wraps WKWebView for use in SwiftUI.
/// Handles loading state updates via Coordinator pattern.
private struct WebViewRepresentable: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // No updates needed after initial load
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var isLoading: Bool

        init(isLoading: Binding<Bool>) {
            _isLoading = isLoading
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoading = false
        }
    }
}

#Preview {
    WebView(
        url: URL(string: "https://milesofmichael.github.io/HealthyMe/privacy")!,
        title: "Privacy Policy"
    )
}
