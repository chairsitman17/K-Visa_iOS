//
//  WebViewCoordinator.swift
//  K-Visa
//

import Foundation
import WebKit
import SwiftUI
import Firebase
import Foundation

class WebViewCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    weak var webView: WKWebView?
    private let viewModel: WebViewViewModel
    
    init(viewModel: WebViewViewModel) {
        self.viewModel = viewModel
//        super.init()
//        NotificationCenter.default.addObserver(forName: .FCMTokenReceived, object: nil, queue: .main) { notification in
//            if let js = notification.object as? String {
//                self.webView?.evaluateJavaScript(js)
//            }
//        }
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
        } else if message.name == "pageDidFullyLoad" {
            print("페이지 로딩 완료")
            DispatchQueue.main.async {
                self.viewModel.isLoading = false
            }
        } else if message.name == "request_notification_permission" {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                    print("🔔 알림 권한 요청 결과: \(granted)")
                    guard granted else {
                        let js = "window.dispatchEvent(new CustomEvent('notification-denied'));"
                        self.webView?.evaluateJavaScript(js)
                        return
                    }
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                
                    // FCM 토큰 요청
                    Messaging.messaging().token { token, error in
                        if let error = error {
                            print("❌ FCM 토큰 오류:", error)
                            let js = "window.dispatchEvent(new CustomEvent('notification-denied'));"
                            self.webView?.evaluateJavaScript(js)
                        } else if let token = token {
                            print("✅ FCM 토큰:", token)
                            let js = "window.receiveNotificationToken &&    window.receiveNotificationToken('\(token)');"
                            self.webView?.evaluateJavaScript(js)
                        }
                    }
                }
        } else if message.name == "check_notification_permission" {
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                let status: String
                switch settings.authorizationStatus {
                case .notDetermined:
                    status = "not_determined"
                case .denied:
                    status = "denied"
                case .authorized:
                    status = "authorized"
                case .provisional:
                    status = "provisional"
                case .ephemeral:
                    status = "ephemeral"
                @unknown default:
                    status = "unknown"
                }

                let js = "window.receiveNotificationPermission && window.receiveNotificationPermission('\(status)');"
                DispatchQueue.main.async {
                    self.webView?.evaluateJavaScript(js)
                }
            }
        } else {
            print("JS Log: \(message.body)")
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
