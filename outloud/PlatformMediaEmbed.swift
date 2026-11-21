import SwiftUI
import WebKit

/// Official player URLs stay usable when individual signed media links expire.
struct PlatformMediaEmbed: NSViewRepresentable {
    let url: URL
    var onFailure: () -> Void = {}
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        let view = WKWebView(frame: .zero, configuration: configuration)
        configuration.userContentController.add(context.coordinator, name: "playbackFailure")
        view.navigationDelegate = context.coordinator
        return view
    }
    func updateNSView(_ view: WKWebView, context: Context) {
        context.coordinator.onFailure = onFailure
        guard context.coordinator.loadedURL != url else { return }
        context.coordinator.loadedURL = url
        if url.host == "www.tiktok.com" {
            view.loadHTMLString("""
                <!doctype html><meta name="viewport" content="width=device-width, initial-scale=1">
                <style>html,body,iframe{background:black;margin:0;width:100%;height:100%;border:0;overflow:hidden;display:block}</style>
                <script>
                addEventListener("message", event => {
                    const player = document.querySelector("iframe");
                    if (event.origin !== "https://www.tiktok.com" || event.source !== player?.contentWindow) return;
                    const data = event.data;
                    if (!data?.["x-tiktok-player"]) return;
                    if (data.type === "onPlayerError" && data.value?.errorCode !== 3002) {
                        window.webkit.messageHandlers.playbackFailure.postMessage(null);
                    }
                });
                </script>
                <iframe src="\(url.absoluteString.replacingOccurrences(of: "&", with: "&amp;"))" allow="fullscreen"></iframe>
                """, baseURL: nil)
        } else {
            view.load(URLRequest(url: url))
        }
    }
    static func dismantleNSView(_ view: WKWebView, coordinator: Coordinator) {
        view.stopLoading()
        view.configuration.userContentController.removeScriptMessageHandler(forName: "playbackFailure")
        view.navigationDelegate = nil
    }
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var onFailure: () -> Void = {}
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.frameInfo.isMainFrame else { return }
            onFailure()
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            if (error as NSError).code != NSURLErrorCancelled { onFailure() }
        }
        func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse,
                     decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            if let http = response.response as? HTTPURLResponse, http.statusCode >= 400,
               http.url?.host == loadedURL?.host {
                onFailure()
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
        var loadedURL: URL?
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let target = navigationAction.request.url else { decisionHandler(.cancel); return }
            if navigationAction.navigationType == .linkActivated {
                if target.scheme == "https", ["www.tiktok.com", "www.instagram.com"].contains(target.host ?? "") { NSWorkspace.shared.open(target) }
                decisionHandler(.cancel); return
            }
            if navigationAction.targetFrame?.isMainFrame == true,
               target.host != loadedURL?.host, target.absoluteString != "about:blank" {
                decisionHandler(.cancel); return
            }
            decisionHandler(.allow)
        }
    }
    static func instagramURL(_ original: String?) -> URL? {
        guard let original, let source = URL(string: original), source.scheme == "https",
              ["instagram.com", "www.instagram.com"].contains(source.host ?? ""), source.user == nil, source.password == nil,
              source.port == nil else { return nil }
        let path = source.path.split(separator: "/")
        guard path.count == 2, ["p", "reel", "tv"].contains(String(path[0])),
              path[1].range(of: "^[A-Za-z0-9_-]{3,80}$", options: .regularExpression) != nil else { return nil }
        return URL(string: "https://www.instagram.com/\(path[0])/\(path[1])/embed/")
    }
    static func tiktokURL(_ original: String?, controls: Bool) -> URL? {
        guard let original, let source = URL(string: original), source.scheme == "https",
              ["tiktok.com", "www.tiktok.com"].contains(source.host ?? ""), source.user == nil, source.password == nil,
              source.port == nil else { return nil }
        let path = source.path.split(separator: "/")
        guard path.count == 3, path[0].hasPrefix("@"), path[1] == "video",
              (10...25).contains(path[2].count), path[2].allSatisfy(\.isNumber) else { return nil }
        var url = URLComponents(string: "https://www.tiktok.com/player/v1/\(path[2])")!
        url.queryItems = [URLQueryItem(name: "autoplay", value: "0"), URLQueryItem(name: "loop", value: "0"),
            URLQueryItem(name: "controls", value: controls ? "1" : "0"), URLQueryItem(name: "description", value: "0"),
            URLQueryItem(name: "music_info", value: "0"), URLQueryItem(name: "rel", value: "0")]
        return url.url
    }
}
