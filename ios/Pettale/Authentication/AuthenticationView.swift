import AuthenticationServices
import SwiftUI

struct AuthenticationView: View {
    @Bindable var controller: AuthenticationController

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 64))
                .accessibilityHidden(true)
            Text("Pettale Account").font(.title2.bold())
            Text("Sign in is only required for future online services. Your local pet history remains available.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            switch controller.state {
            case .signedIn:
                Label("Signed In", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                Button("Sign Out", role: .destructive) { controller.logout() }
            case .signingIn:
                ProgressView("Signing In")
            case .signedOut, .failed:
                SignInWithAppleButton(.continue) { request in
                    do {
                        request.requestedScopes = [.email]
                        request.nonce = try controller.prepareNonce()
                    } catch {
                        controller.cancelAppleAuthorization()
                    }
                } onCompletion: { result in
                    switch result {
                    case .success(let authorization):
                        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                              let token = credential.identityToken else {
                            controller.cancelAppleAuthorization(); return
                        }
                        Task { await controller.completeAppleAuthorization(identityTokenData: token) }
                    case .failure:
                        controller.cancelAppleAuthorization()
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 48)
                if case .failed(let message) = controller.state {
                    Text(message).foregroundStyle(.red).font(.footnote)
                }
            }
        }
        .padding()
        .navigationTitle("Account")
    }
}
