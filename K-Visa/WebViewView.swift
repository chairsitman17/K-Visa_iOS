//
//  WebViewView.swift
//  K-Visa
//

import SwiftUI
import WebKit

struct WebViewView: UIViewRepresentable {
    let viewModel: WebViewViewModel
    
    func makeCoordinator() -> WebViewCoordinator {
        return WebViewCoordinator(viewModel: viewModel)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "login_google") // WebView에서 Google Login 시그널을 받을 수 있게 하기
        contentController.add(context.coordinator, name: "login_apple") // WebView에서 Apple Login 시그널을 받을 수 있게 하기
        config.userContentController = contentController
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.customUserAgent = "K-VisaApp_iOS"
        
        webView.load(URLRequest(url: viewModel.url))
        context.coordinator.webView = webView
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // shouldReloadWebView state가 업데이트되면 페이지 새로고침
        if viewModel.shouldReloadWebView {
            uiView.reload()
            viewModel.shouldReloadWebView = false // state 업데이트
        }
        // 전달해야할 토큰이 있으면 웹앱에 Auth Token을 전달하게 하여 WebView 쿠키에 인증정보 추가하게 하기
        if viewModel.authToken != nil {
            let token = viewModel.authToken!
            let _token = token.split(separator: "/")
            let js = "window.dispatchEvent(new CustomEvent('firebase-login', { detail: { token: '\(_token[1])', provider: '\(_token[0])' } }));"
            uiView.evaluateJavaScript(js)
            viewModel.authToken = nil
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
