import StoreKit
import SwiftUI

struct PremiumView: View {
    @Bindable var controller: SubscriptionController
    @State private var showsManageSubscriptions = false

    private var state: SubscriptionPresentationState { controller.presentationState }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(.pink)
                    .accessibilityHidden(true)
                VStack(spacing: 8) {
                    Text("Oreamy Premium").font(.title.bold())
                    Text("Keep every tale going.").font(.title3).foregroundStyle(.secondary)
                }
                stateNotice
                allowance
                if state.showsProductSelector {
                    products
                } else {
                    currentPaidPlan
                }
                actions
                Text("Apple purchase status and Oreamy service access are synchronized separately for now.")
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .padding()
        }
        .navigationTitle("Premium")
        .navigationBarTitleDisplayMode(.inline)
        .manageSubscriptionsSheet(isPresented: $showsManageSubscriptions)
        .onChange(of: showsManageSubscriptions) { wasPresented, isPresented in
            guard wasPresented, !isPresented else { return }
            Task { await controller.refreshAfterSubscriptionManagement() }
        }
    }

    private var stateNotice: some View {
        let presentation = AccountPlanPresentation.make(state: state)
        return VStack(spacing: 5) {
            if case .freeTrial = state {
                Text("30-day Free Trial").font(.headline)
            }
            Label(
                presentation.title,
                systemImage: state.isPaidPremium ? "checkmark.seal.fill" : "clock.badge.checkmark"
            )
            .foregroundStyle(state.isPaidPremium ? .green : .secondary)
            if let detail = presentation.detail {
                Text(detail).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var allowance: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("\(state.monthlyAiAllowance) AI records per month", systemImage: "waveform.badge.mic")
            if case .premiumExpiring(_, let expirationDate) = state {
                Text("Available with Premium until \(expirationDate.formatted(date: .abbreviated, time: .omitted)).")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if case .free = state {
                Text("Existing history stays available")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var currentPaidPlan: some View {
        if let paidProduct = state.paidProduct {
            let period: SubscriptionPeriod = paidProduct == .monthly ? .monthly : .annual
            let product = controller.products.first { $0.period == period }
            VStack(alignment: .leading, spacing: 8) {
                Label(
                    paidProduct == .monthly ? "Monthly Plan" : "Annual Plan",
                    systemImage: paidProduct == .monthly ? "calendar" : "calendar.badge.checkmark"
                )
                .font(.headline)
                if let product {
                    Text(product.displayPrice).font(.title3.bold())
                }
                if case .premiumExpiring = state {
                    Text("Auto-renewal is currently off.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.background, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.secondary.opacity(0.25)))
        }
    }

    @ViewBuilder private var products: some View {
        switch controller.loadState {
        case .idle, .loading:
            ProgressView("Loading subscription options")
        case .unavailable:
            ContentUnavailableView("Subscriptions Unavailable", systemImage: "cart", description: Text("Please try again later."))
        case .failed:
            ContentUnavailableView("Couldn't Load Subscriptions", systemImage: "exclamationmark.triangle", description: Text("Please try again."))
        case .loaded:
            VStack(spacing: 12) {
                ForEach(controller.products) { product in productButton(product) }
            }
        }
    }

    private func productButton(_ product: StoreProduct) -> some View {
        let selected = controller.selectedProductID == product.id
        return Button { controller.select(product) } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(product.period == .monthly ? "Monthly" : "Annual").font(.headline)
                    Spacer()
                    Text(product.displayPrice).font(.headline)
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected ? .pink : .secondary)
                }
                if product.period == .annual, let savingsLabel = product.savingsLabel {
                    Text(savingsLabel).font(.caption.bold()).foregroundStyle(.pink)
                }
            }
            .padding()
            .background(.background, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected ? Color.pink : Color.secondary.opacity(0.25), lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(product.period == .monthly ? String(localized: "Monthly") : String(localized: "Annual")), \(product.displayPrice)\(product.savingsLabel.map { ", \($0)" } ?? "")")
        .accessibilityValue(selected ? String(localized: "Selected") : String(localized: "Not Selected"))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var actions: some View {
        VStack(spacing: 12) {
            if state.showsPurchaseCTA {
                Button {
                    Task { await controller.purchaseSelectedProduct() }
                } label: {
                    Text("Start Premium").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).tint(.pink)
                .disabled(controller.selectedProductID == nil || controller.purchaseState == .purchasing)
            }
            if controller.purchaseState == .purchasing { ProgressView() }
            if controller.purchaseState == .pending {
                Text("Your purchase is pending approval.").font(.footnote).foregroundStyle(.secondary)
            }
            if let errorMessage = controller.errorMessage {
                Text(errorMessage).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
            }
            if state.isPaidPremium {
                Button("Manage Subscription in Apple") { showsManageSubscriptions = true }
            }
            Button(controller.isRestoring ? "Restoring Purchases" : "Restore Purchases") {
                Task { await controller.restorePurchases() }
            }
            .disabled(controller.isRestoring)
        }
    }
}
