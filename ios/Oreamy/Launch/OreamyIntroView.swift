import SwiftUI

struct OreamyIntroView: View {
    let holdsForDevelopment: Bool
    let completion: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPresented = false
    @State private var didComplete = false

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
                .offset(y: isPresented || reduceMotion ? 0 : 8)
            Text("Oreamy")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
            Text("Every pet has a tale.")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .opacity(isPresented ? 1 : 0)
        .scaleEffect(reduceMotion || isPresented ? 1 : 0.96)
        .accessibilityElement(children: .combine)
        .task { await presentAndComplete() }
    }

    @MainActor
    private func presentAndComplete() async {
        let plan = OreamyIntroAnimationPlan.resolve(reduceMotion: reduceMotion)
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.2)) { isPresented = true }
        } else {
            withAnimation(.easeOut(duration: 0.45)) { isPresented = true }
        }
        guard !holdsForDevelopment else { return }
        try? await Task.sleep(for: plan.duration)
        guard !Task.isCancelled, !didComplete else { return }
        didComplete = true
        completion()
    }
}
