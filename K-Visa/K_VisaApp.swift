//
//  K_VisaApp.swift
//  K-Visa
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import UserNotifications
import Firebase

extension Notification.Name {
    static let FCMTokenReceived = Notification.Name("FCMTokenReceived")
    static let OpenWebViewWithURL = Notification.Name("OpenWebViewWithURL")
    static let WebViewReady = Notification.Name("WebViewReady")
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    var pendingUrlString: String = ""
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("📲 APNs 토큰 등록됨: \(deviceToken.map { String(format: "%02.2hhx", $0) }.joined())")
        Messaging.messaging().apnsToken = deviceToken
    }
    
    func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        UIApplication.shared.registerForRemoteNotifications()
    
        return true
    }
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                     willPresent notification: UNNotification,
                                     withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                     didReceive response: UNNotificationResponse,
                                     withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("🔔 알림 클릭됨: \(userInfo)")

        if let urlString = userInfo["url"] as? String,
            let url = URL(string: urlString) {
            // 웹뷰로 열기 (예: WebViewController로 전달)
            print(url)
            self.pendingUrlString = urlString
            NotificationCenter.default.post(name: .OpenWebViewWithURL, object: url)
        }
        
        NotificationCenter.default.addObserver(forName: .WebViewReady, object: nil, queue: .main) { _ in
            if self.pendingUrlString != "" {
                let url = URL(string: self.pendingUrlString)
                NotificationCenter.default.post(name: .OpenWebViewWithURL, object: url)
                self.pendingUrlString = ""
            }
        }
        completionHandler()
    }
}

@main
struct K_VisaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
