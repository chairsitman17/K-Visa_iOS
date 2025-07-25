//
//  WebViewViewModel.swift
//  K-Visa
//

import Foundation
import Combine
import Firebase
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices
import CryptoKit
import Foundation

class WebViewViewModel: NSObject, ObservableObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    
    @Published var url: URL = URL(string: "https://korea-visa.kr")!
    @Published var prevUrl: URL = URL(string: "https://korea-visa.kr")!
    @Published var isLoading: Bool = true
    @Published var shouldReloadWebView: Bool = false
    // authToken은 (Provider)/(Token)으로 구성되어 있음.
    @Published var authToken: String?
    @Published var currentNonce: String?

    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(handleOpenWebView(_:)), name: .OpenWebViewWithURL, object: nil)
    }
    
    @objc private func handleOpenWebView(_ notification: Notification) {
            if let newUrl = notification.object as? URL {
                self.url = newUrl
            }
        }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // 현재 앱의 KeyWindow를 반환 (presentation용 Anchor)
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) else {
                fatalError("KeyWindow를 찾을 수 없습니다.")
        }
        return window
    }
    
    func handleOAuthLogin(provider: String, presentingVC: UIViewController) {
        guard let clientID = FirebaseApp.app()?.options.clientID else { return }

        // Google 로그인일때...
        if provider == "google" {
            // Firebase Google 인증 Config값 가져오기
            let config = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = config

            // Sign in flow 시작
            GIDSignIn.sharedInstance.signIn(withPresenting: presentingVC) { result, error in
                if let error = error {
                    print("Google OAuth login failed with error: \(error.localizedDescription)")
                    return
                }
                
                guard let user = result?.user,
                    let idToken = user.idToken?.tokenString else {
                    print("Google OAuth login failed: Missing user or token")
                    return
                }
                
                // 인증 성공!
                // K-Visa WebApp에 인증 토큰 전달을 위해
                // State 업데이트, WebViewView의 updateUIView Trigger하기
                DispatchQueue.main.async {
                    self.authToken = "google/\(idToken)"
                }
                
            }
            
        // Apple 로그인일때...
        } else if provider == "apple" {
            let nonce = randomNonceString()
            currentNonce = nonce
            let appleIDProvider = ASAuthorizationAppleIDProvider()
            let request = appleIDProvider.createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = sha256(nonce)

            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            authorizationController.delegate = self
            authorizationController.presentationContextProvider = self
            authorizationController.performRequests()
        }
    }
    
    // Apple 로그인에 사용되는 SHA256, Nonce 함수 시작
    func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.map { String(format: "%02x", $0) }.joined()
    }

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
          fatalError(
            "Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)"
          )
        }

        let charset: [Character] =
          Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")

        let nonce = randomBytes.map { byte in
          // Pick a random character from the set, wrapping around if needed.
          charset[Int(byte) % charset.count]
        }

        return String(nonce)
    }
    // Apple 로그인에 사용되는 SHA256, Nonce 함수 끝
}


@available(iOS 13.0, *)
extension WebViewViewModel {

  func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
      if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
          guard let nonce = currentNonce else {
              fatalError("Invalid state: A login callback was received, but no login request was sent.")
          }
          guard let appleIDToken = appleIDCredential.identityToken else {
              print("Unable to fetch identity token")
              return
          }
          guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
              print("Unable to serialize token string from data: \(appleIDToken.debugDescription)")
              return
          }
          
          // 인증 성공!
          // K-Visa WebApp에 인증 토큰 전달을 위해
          // State 업데이트, WebViewView의 updateUIView Trigger하기
          DispatchQueue.main.async {
              self.authToken = "apple/\(idTokenString)__rawNonce__\(nonce)"
          }

      }
  }

  func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
    // Handle error.
    print("Sign in with Apple errored: \(error)")
  }

}
