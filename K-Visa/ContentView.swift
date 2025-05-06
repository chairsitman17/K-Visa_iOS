//
//  ContentView.swift
//  K-Visa
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import GoogleSignIn


class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()

    return true
  }
}

struct ContentView: View {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject var viewModel = WebViewViewModel()
    
    var body: some View {
        ZStack(alignment: .top) {
            // K-Visa 웹앱 켜기
            WebViewView(viewModel: viewModel)
//                .ignoresSafeArea(edges: [.bottom, .horizontal])
                .padding(.bottom, 1)
        
//            // 상단 Dynamic Island 영역용 흰 배경
//            Color.white
//                .frame(height: 44)
//                .edgesIgnoringSafeArea(.top)
        }
    }
}

#Preview {
    ContentView()
}
