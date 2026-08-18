import AuthenticationServices
import SwiftUI

struct AuthenticationView: View {
    @Bindable var controller: AuthenticationController
    let subscription: SubscriptionController?

    init(controller: AuthenticationController, subscription: SubscriptionController? = nil) {
        self.controller = controller
        self.subscription = subscription
    }

    var body: some View {
        List {
            if let subscription {
                Section {
                    NavigationLink {
                        PremiumView(controller: subscription)
                    } label: {
                        let presentation = AccountPlanPresentation.make(state: subscription.presentationState)
                        HStack {
                            Label("Oreamy Account", systemImage: "heart.circle.fill")
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(presentation.title)
                                if let detail = presentation.detail {
                                    Text(detail).font(.caption).multilineTextAlignment(.trailing)
                                }
                            }.foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityHint("Shows subscription options and local Apple purchase status")
                } header: {
                    Text("Subscription")
                } footer: {
                    Text("Oreamy trial and AI access remain managed by the Oreamy service.")
                }
            }

            Section {
                VStack(spacing: 16) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 52)).accessibilityHidden(true)
                    Text("Oreamy Account").font(.title2.bold())
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
            }
        }
        .navigationTitle("Account")
        .task(id: session?.accessToken) {
            await subscription?.refreshServiceAccess(session: session)
        }
    }

    private var session: OreamySession? {
        if case .signedIn(let session) = controller.state { return session }
        return nil
    }

}
