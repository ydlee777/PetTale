import SwiftUI

struct HomeView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 52))
                .foregroundStyle(.tint)

            Text("Pettale")
                .font(.largeTitle.bold())

            Text("Every pet has a tale.")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
