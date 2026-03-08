import SwiftUI
import StoreKit

/// マイページ画面
struct MyPageView: View {

    @StateObject private var viewModel = MyPageViewModel()
    @State private var showConsentSheet = false
    @State private var showRevokeAlert = false

    private let privacyURL = URL(string: "https://it-master.jp/biblion/privacy-policy.html")!
    private let termsURL = URL(string: "https://it-master.jp/biblion/terms.html")!

    var body: some View {
        NavigationStack {
            List {
                // MARK: - プラン情報
                Section(header: Text("mypage.title")) {
                    HStack {
                        Text(planDisplayName)
                            .font(.headline)
                        Spacer()
                        Text(planDisplayName)
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(viewModel.planBadgeColor.opacity(0.15))
                            .foregroundColor(viewModel.planBadgeColor)
                            .clipShape(Capsule())
                    }

                    if let expires = viewModel.expiresAt {
                        let formatter = DateFormatter()
                        let _ = { formatter.dateStyle = .medium }()
                        Text(String(format: NSLocalizedString("mypage.plan.expires", comment: ""), formatter.string(from: expires)))
                            .foregroundColor(.secondary)
                    }
                }

                // MARK: - チケット
                Section(header: Text("mypage.section.ticket")) {
                    VStack(spacing: 8) {
                        Text("\(viewModel.ticketCount)")
                            .font(.largeTitle.bold())
                            .foregroundColor(.indigo)
                            .frame(maxWidth: .infinity)
                        Text(String(format: NSLocalizedString("mypage.ticket.count", comment: ""), viewModel.ticketCount))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)

                    // 購入ボタン（将来のStoreKit実装用プレースホルダー）
                    Button {
                        // Phase 3: StoreKit 2 でチケット購入
                    } label: {
                        HStack {
                            Image(systemName: "ticket.fill")
                            Text("mypage.ticket.buy")
                        }
                        .foregroundColor(.indigo)
                    }
                }

                // MARK: - プラン変更
                Section(header: Text("mypage.section.plan")) {
                    if viewModel.planType == .free {
                        planCard(
                            title: NSLocalizedString("mypage.plan.basic", comment: ""),
                            price: NSLocalizedString("mypage.plan.basic.price", comment: ""),
                            features: [
                                NSLocalizedString("mypage.plan.basic.feature1", comment: ""),
                                NSLocalizedString("mypage.plan.basic.feature2", comment: ""),
                                NSLocalizedString("mypage.plan.basic.feature3", comment: "")
                            ],
                            upgradeKey: "mypage.upgrade.basic",
                            color: .blue
                        )
                        planCard(
                            title: NSLocalizedString("mypage.plan.premium", comment: ""),
                            price: NSLocalizedString("mypage.plan.premium.price", comment: ""),
                            features: [
                                NSLocalizedString("mypage.plan.premium.feature1", comment: ""),
                                NSLocalizedString("mypage.plan.premium.feature2", comment: ""),
                                NSLocalizedString("mypage.plan.premium.feature3", comment: "")
                            ],
                            upgradeKey: "mypage.upgrade.premium",
                            color: Color(hex: "C9A84C")
                        )
                    } else {
                        HStack {
                            Text(planDisplayName)
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }

                    Button("mypage.restore") {
                        // Phase 3: AppStore.sync()
                    }
                    .foregroundColor(.secondary)
                }

                // MARK: - データとプライバシー
                Section(header: Text("mypage.section.privacy")) {
                    // AI同意トグル
                    Toggle(isOn: Binding(
                        get: { viewModel.isAIConsentGiven },
                        set: { newValue in
                            if !newValue {
                                showRevokeAlert = true
                            } else {
                                viewModel.grantAIConsent()
                            }
                        }
                    )) {
                        Text("mypage.aiConsent")
                    }
                    .tint(.indigo)

                    Link(destination: privacyURL) {
                        HStack {
                            Text("settings.privacyPolicy")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)

                    Link(destination: termsURL) {
                        HStack {
                            Text("settings.terms")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                }

                // MARK: - アプリ情報
                Section(header: Text("settings.about")) {
                    HStack {
                        Text("settings.version")
                        Spacer()
                        Text(String(format: NSLocalizedString("mypage.version", comment: ""), viewModel.appVersion))
                            .foregroundColor(.secondary)
                    }
                    Button("mypage.review") {
                        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                            SKStoreReviewController.requestReview(in: scene)
                        }
                    }
                }
            }
            .navigationTitle(Text("mypage.title"))
            .onAppear { viewModel.refresh() }
            .alert("mypage.aiConsent.revokeAlert", isPresented: $showRevokeAlert) {
                Button("common.cancel", role: .cancel) {}
                Button("common.done", role: .destructive) {
                    viewModel.revokeAIConsent()
                }
            }
        }
    }

    // MARK: - プラン名表示

    private var planDisplayName: String {
        switch viewModel.planType {
        case .free: return NSLocalizedString("mypage.plan.free", comment: "")
        case .basic: return NSLocalizedString("mypage.plan.basic", comment: "")
        case .premium: return NSLocalizedString("mypage.plan.premium", comment: "")
        }
    }

    // MARK: - プランカード

    private func planCard(title: String, price: String, features: [String], upgradeKey: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(color)
                Spacer()
                Text(price)
                    .font(.caption.bold())
                    .foregroundColor(color)
            }

            ForEach(features, id: \.self) { feature in
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundColor(color)
                    Text(feature)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Button {
                // Phase 3: 購入処理
            } label: {
                Text(LocalizedStringKey(upgradeKey))
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(color.opacity(0.12))
                    .foregroundColor(color)
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    MyPageView()
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
}
