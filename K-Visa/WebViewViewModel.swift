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

class WebViewViewModel: NSObject, ObservableObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
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
    
    @Published var url: URL = URL(string: "https://kvisa-nextjs--k-visa-81cf2.asia-east1.hosted.app")!
    @Published var isLoading: Bool = false
    @Published var shouldReloadWebView: Bool = false
    // authToken은 (Provider)/(Token)으로 구성되어 있음.
    @Published var authToken: String?
    @Published var currentNonce: String?
    
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
                
                let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)
                
                // Firebase에 인증하기
                Auth.auth().signIn(with: credential) { result, error in
                    if let error = error {
                        print("Firebase login failed with error: \(error.localizedDescription)")
                        return
                    }
                    
                    // 인증 성공!
                    // K-Visa WebApp에 인증 토큰 전달을 위해
                    // State 업데이트, WebViewView의 updateUIView Trigger하기
                    
                    result?.user.getIDToken(completion: { idToken, error in
                        if let idToken = idToken {
                            DispatchQueue.main.async {
                                self.authToken = "google/\(idToken)"
                            }
                        } else if let error = error {
                            print("ID 토큰 가져오기 실패: \(error.localizedDescription)")
                        }
                    })
                    
                }
            }
            
            
            
            
        // Apple 로그인일때...
        } else if provider == "apple" {
            let nonce = randomNonceString()
            currentNonce = nonce
            
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.email, .fullName]
            request.nonce = sha256(nonce)
            
            let authController = ASAuthorizationController(authorizationRequests: [request])
            authController.delegate = self
            authController.presentationContextProvider = self
            authController.performRequests()
        }
        
    }
    
    // Apple 로그인에 사용되는 SHA256, Nonce 함수 시작
    func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.map { String(format: "%02x", $0) }.joined()
    }

    func randomNonceString(length: Int = 32) -> String {
        let charset: [Character] =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms = (0..<16).map { _ in UInt8.random(in: 0...255) }
            for random in randoms {
                if remainingLength == 0 {
                    return result
                }

                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
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
      
      let credential = OAuthProvider.appleCredential(withIDToken: idTokenString,
                                                        rawNonce: nonce,
                                                        fullName: appleIDCredential.fullName)
      // Firebase에서 인증하기
      Auth.auth().signIn(with: credential) { (result, error) in
          if error != nil {
              print("Apple 인증 오류: \(error!)")
              return
          }
          
          // 인증 성공!
          // K-Visa WebApp에 인증 토큰 전달을 위해
          // State 업데이트, WebViewView의 updateUIView Trigger하기
          result?.user.getIDToken(completion: { idToken, error in
              if let idToken = idToken {
                  DispatchQueue.main.async {
                      self.authToken = "apple/\(idToken)"
                  }
              } else if let error = error {
                  print("ID 토큰 가져오기 실패: \(error.localizedDescription)")
              }
          })
      }
    }
  }

  func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
    // Handle error.
    print("Sign in with Apple errored: \(error)")
  }

}
