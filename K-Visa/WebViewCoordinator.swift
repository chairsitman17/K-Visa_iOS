//
//  WebViewCoordinator.swift
//  K-Visa
//

import Foundation
import WebKit

class WebViewCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    weak var webView: WKWebView?
    private let viewModel: WebViewViewModel
    
    init(viewModel: WebViewViewModel) {
        self.viewModel = viewModel
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "login_google" {
            if let presentingVC = webView?.parentViewController() {
                viewModel.handleOAuthLogin(provider: "google", presentingVC: presentingVC)
            } else {
                print("ViewController를 찾을 수 없습니다.")
            }
        } else if message.name == "login_apple" {
            if let presentingVC = webView?.parentViewController() {
                viewModel.handleOAuthLogin(provider: "apple", presentingVC: presentingVC)
            } else {
                print("ViewController를 찾을 수 없습니다.")
            }
        }
    }
}

extension UIView {
    func parentViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let next = responder?.next {
            if let vc = next as? UIViewController {
                return vc
            }
            responder = next
        }
        return nil
    }
}
