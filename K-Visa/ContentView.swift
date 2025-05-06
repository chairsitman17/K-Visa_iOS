//
//  ContentView.swift
//  K-Visa
//

import SwiftUI

struct ContentView: View {
    @StateObject var viewModel = WebViewViewModel()
    
    var body: some View {
        ZStack(alignment: .top) {
            // K-Visa 웹앱 켜기
            WebViewView(viewModel: viewModel)
                .padding(.bottom, 1)
            
            if viewModel.isLoading {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeOut(duration: 0.3), value: viewModel.isLoading)
    }
}

struct SplashView: View {
    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()
            VStack {
                Image("splash")
                    .resizable()
                    .frame(width: 150, height: 150)
            }
        }
    }
}

#Preview {
    ContentView()
}
