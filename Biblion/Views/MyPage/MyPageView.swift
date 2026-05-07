import SwiftUI
import StoreKit
import UserNotifications

/// マイページ画面
struct MyPageView: View {

    @StateObject private var viewModel = MyPageViewModel()
    @StateObject private var notifVM   = NotificationSettingsViewModel()
    @State private var showConsentSheet = false
    @State private var showRevokeAlert = false
    @State private var showTicketHistory = false

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


                }

                // MARK: - チケット
                Section(header: Text("mypage.section.ticket")) {
                    VStack(spacing: 6) {
                        HStack {
                            Text("mypage.ticket.plan")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: NSLocalizedString("mypage.ticket.count", comment: ""), viewModel.planTicketCount))
                                .font(.caption.bold())
                                .foregroundColor(.indigo)
                        }
                        HStack {
                            Text("mypage.ticket.free")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: NSLocalizedString("mypage.ticket.count", comment: ""), viewModel.freeTicketCount))
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Text("mypage.ticket.purchased")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: NSLocalizedString("mypage.ticket.count", comment: ""), viewModel.purchasedTicketCount))
                                .font(.caption.bold())
                                .foregroundColor(.orange)
                        }
                        Divider()
                        HStack {
                            Text("mypage.ticket.total")
                                .font(.subheadline.bold())
                            Spacer()
                            Text(String(format: NSLocalizedString("mypage.ticket.count", comment: ""), viewModel.ticketCount))
                                .font(.subheadline.bold())
                                .foregroundColor(.indigo)
                        }
                    }
                    .padding(.vertical, 4)

                    Button {
                        Task { await viewModel.buyTicket45() }
                    } label: {
                        HStack {
                            if viewModel.isProcessing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "ticket.fill")
                            }
                            Text("mypage.ticket.buy")
                        }
                        .foregroundColor(.indigo)
                    }
                    .disabled(viewModel.isProcessing)
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
                                NSLocalizedString("mypage.plan.basic.feature3", comment: ""),
                                NSLocalizedString("mypage.plan.basic.feature4", comment: "")
                            ],
                            upgradeKey: "mypage.upgrade.basic",
                            color: .blue,
                            onUpgrade: { Task { await viewModel.purchaseBasic() } }
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
                            color: Color(hex: "C9A84C"),
                            onUpgrade: { Task { await viewModel.purchasePremium() } }
                        )
                    } else if viewModel.planType == .basic {
                        currentPlanCard(
                            title: NSLocalizedString("mypage.plan.basic", comment: ""),
                            price: NSLocalizedString("mypage.plan.basic.price", comment: ""),
                            features: [
                                NSLocalizedString("mypage.plan.basic.feature1", comment: ""),
                                NSLocalizedString("mypage.plan.basic.feature2", comment: ""),
                                NSLocalizedString("mypage.plan.basic.feature3", comment: ""),
                                NSLocalizedString("mypage.plan.basic.feature4", comment: "")
                            ],
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
                            color: Color(hex: "C9A84C"),
                            onUpgrade: { Task { await viewModel.purchasePremium() } }
                        )
                    } else {
                        currentPlanCard(
                            title: NSLocalizedString("mypage.plan.premium", comment: ""),
                            price: NSLocalizedString("mypage.plan.premium.price", comment: ""),
                            features: [
                                NSLocalizedString("mypage.plan.premium.feature1", comment: ""),
                                NSLocalizedString("mypage.plan.premium.feature2", comment: ""),
                                NSLocalizedString("mypage.plan.premium.feature3", comment: "")
                            ],
                            color: Color(hex: "C9A84C")
                        )
                    }

                    Button {
                        Task { await viewModel.restorePurchases() }
                    } label: {
                        HStack {
                            if viewModel.isProcessing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text("mypage.restore")
                        }
                    }
                    .foregroundColor(.secondary)
                    .disabled(viewModel.isProcessing)

                    Text("mypage.cancel.note")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }

                // MARK: - 通知設定
                Section(header: Text("mypage.section.notification")) {
                    // 通知許可が拒否されている場合の案内
                    if notifVM.authorizationStatus == .denied {
                        HStack(spacing: 8) {
                            Image(systemName: "bell.slash.fill")
                                .foregroundColor(.orange)
                            Text("mypage.notification.denied")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    // 通知 ON/OFF トグル
                    Toggle(isOn: Binding(
                        get: { notifVM.isEnabled },
                        set: { newValue in
                            if newValue && notifVM.authorizationStatus == .notDetermined {
                                notifVM.requestAuthorizationAndApply()
                            }
                            notifVM.isEnabled = newValue
                        }
                    )) {
                        Label("mypage.notification.enable", systemImage: "bell.fill")
                    }
                    .tint(.indigo)
                    .disabled(notifVM.authorizationStatus == .denied)

                    if notifVM.isEnabled {
                        // 時刻ピッカー
                        DatePicker(
                            selection: $notifVM.notificationTime,
                            displayedComponents: .hourAndMinute
                        ) {
                            Label("mypage.notification.time", systemImage: "clock")
                        }

                        // 曜日選択
                        VStack(alignment: .leading, spacing: 8) {
                            Label("mypage.notification.weekdays", systemImage: "calendar")
                                .font(.subheadline)
                            weekdaySelector
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onAppear { Task { await notifVM.refreshAuthorizationStatus() } }

                // MARK: - 朝のメモ通知設定
                Section(header: Text("mypage.section.morningMemo")) {
                    if notifVM.authorizationStatus == .denied {
                        HStack(spacing: 8) {
                            Image(systemName: "bell.slash.fill")
                                .foregroundColor(.orange)
                            Text("mypage.notification.denied")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Toggle(isOn: Binding(
                        get: { notifVM.morningMemoEnabled },
                        set: { newValue in
                            if newValue && notifVM.authorizationStatus == .notDetermined {
                                notifVM.requestAuthorizationAndApply()
                            }
                            notifVM.morningMemoEnabled = newValue
                        }
                    )) {
                        Label("mypage.morningMemo.enable", systemImage: "sun.max.fill")
                    }
                    .tint(.orange)
                    .disabled(notifVM.authorizationStatus == .denied)

                    if notifVM.morningMemoEnabled {
                        DatePicker(
                            selection: $notifVM.morningMemoTime,
                            displayedComponents: .hourAndMinute
                        ) {
                            Label("mypage.notification.time", systemImage: "clock")
                        }

                        Text("mypage.morningMemo.description")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showTicketHistory = true
                    } label: {
                        Image(systemName: "ticket")
                    }
                }
            }
            .sheet(isPresented: $showTicketHistory) {
                TicketHistoryView()
            }
            .onAppear { viewModel.refresh() }
            .alert("mypage.aiConsent.revokeAlert", isPresented: $showRevokeAlert) {
                Button("common.cancel", role: .cancel) {}
                Button("common.done", role: .destructive) {
                    viewModel.revokeAIConsent()
                }
            }
            .alert(
                NSLocalizedString("common.error", comment: ""),
                isPresented: $viewModel.showAlert,
                presenting: viewModel.alertMessage
            ) { _ in
                Button("common.done") {}
            } message: { message in
                Text(message)
            }
        }
    }

    // MARK: - 曜日選択ビュー

    /// 曜日ボタン（日〜土）
    /// Calendar.weekday 準拠: 1=日, 2=月, ..., 7=土
    private var weekdaySelector: some View {
        let weekdays: [(Int, String)] = [
            (2, NSLocalizedString("weekday.mon", comment: "")),
            (3, NSLocalizedString("weekday.tue", comment: "")),
            (4, NSLocalizedString("weekday.wed", comment: "")),
            (5, NSLocalizedString("weekday.thu", comment: "")),
            (6, NSLocalizedString("weekday.fri", comment: "")),
            (7, NSLocalizedString("weekday.sat", comment: "")),
            (1, NSLocalizedString("weekday.sun", comment: ""))
        ]
        return HStack(spacing: 6) {
            ForEach(weekdays, id: \.0) { weekday, label in
                let isSelected = notifVM.selectedWeekdays.contains(weekday)
                Button {
                    notifVM.toggleWeekday(weekday)
                } label: {
                    Text(label)
                        .font(.caption.bold())
                        .frame(width: 36, height: 36)
                        .background(isSelected ? Color.indigo : Color(.systemGray5))
                        .foregroundColor(isSelected ? .white : .primary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
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

    // MARK: - 現在のプランカード（アップグレードボタンなし）

    private func currentPlanCard(
        title: String,
        price: String,
        features: [String],
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(color)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(NSLocalizedString("mypage.plan.current", comment: ""))
                        .font(.caption.bold())
                        .foregroundColor(.green)
                }
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
        }
        .padding(.vertical, 4)
    }

    // MARK: - プランカード

    private func planCard(
        title: String,
        price: String,
        features: [String],
        upgradeKey: String,
        color: Color,
        onUpgrade: @escaping () -> Void
    ) -> some View {
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
                onUpgrade()
            } label: {
                Group {
                    if viewModel.isProcessing {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(LocalizedStringKey(upgradeKey))
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 8)
                .background(color.opacity(0.12))
                .foregroundColor(color)
                .cornerRadius(8)
            }
            .disabled(viewModel.isProcessing)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    MyPageView()
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
}
