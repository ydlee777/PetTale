import SwiftUI

struct OreamyWelcomeView: View {
    let getStarted: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 54)
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 58, weight: .semibold))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                VStack(spacing: 10) {
                    Text("Oreamy")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text("Every pet has a tale.")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                }
                VStack(spacing: 10) {
                    Text("Tell Oreamy about your pet's day.")
                    Text("We'll help turn those little moments into a story and organized records.")
                }
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

                Button("Get Started", action: getStarted)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Get Started")
                Spacer(minLength: 28)
            }
            .frame(maxWidth: 520)
            .padding(.horizontal, 28)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemBackground))
    }
}
