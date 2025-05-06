//
//  WebViewView.swift
//  K-Visa
//

import SwiftUI
import WebKit

struct WebViewView: UIViewRepresentable {
    @ObservedObject var viewModel: WebViewViewModel
    
    func makeCoordinator() -> WebViewCoordinator {
        return WebViewCoordinator(viewModel: viewModel)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let loadCheckJS = """
        window.addEventListener("DOMContentLoaded", function() {
            window.webkit.messageHandlers.pageDidFullyLoad.postMessage("complete");
        });
        """
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        let loadScript = WKUserScript(source: loadCheckJS, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        contentController.addUserScript(loadScript)
        contentController.add(context.coordinator, name: "pageDidFullyLoad") // HTML, CSS, JS가 모두 로딩되었는지 확인하기 위함
        contentController.add(context.coordinator, name: "login_google") // WebView에서 Google Login 시그널을 받을 수 있게 하기
        contentController.add(context.coordinator, name: "login_apple") // WebView에서 Apple Login 시그널을 받을 수 있게 하기
        config.userContentController = contentController
        config.websiteDataStore = WKWebsiteDataStore.default()
        if #available(iOS 14.0, *) {
            let preferences = WKWebpagePreferences()
            preferences.allowsContentJavaScript = true
            config.defaultWebpagePreferences = preferences
        }
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.customUserAgent = "K-VisaApp_iOS"
        
        webView.load(URLRequest(url: viewModel.url))
        context.coordinator.webView = webView
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // 전달해야할 토큰이 있으면 웹앱에 Auth Token을 전달하게 하여 WebView 쿠키에 인증정보 추가하게 하기
        if viewModel.authToken != nil {
            let tokenWithProvider = viewModel.authToken!
            let token = tokenWithProvider.split(separator: "/")
            let js = "window.dispatchEvent(new CustomEvent('firebase-login', { detail: { token: '\(token[1])', provider: '\(token[0])' } }));"
            print(js)
            uiView.evaluateJavaScript(js)
            DispatchQueue.main.async {
                viewModel.authToken = nil
            }
        }
        // shouldReloadWebView state가 업데이트되면 페이지 새로고침
        if viewModel.shouldReloadWebView {
            uiView.reload()
            DispatchQueue.main.async {
                viewModel.shouldReloadWebView = false // state 업데이트
            }
        }
    }
    
    // GIDSignIn.sharedInstance.signIn (Google OAuth) 에서
    // ViewController를 필요로 하므로 RootViewController를 가져오게 하는 함수를 만듦
    func getRootViewController() -> UIViewController {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first,
              let rootVC = window.rootViewController else {
            fatalError("UIViewController가 없습니다.")
        }
        var topVC = rootVC
        while let presentedVC = topVC.presentedViewController {
            topVC = presentedVC
        }
        return topVC
    }
}
