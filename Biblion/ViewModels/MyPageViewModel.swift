import SwiftUI
import Combine

/// マイページ ViewModel
@MainActor
final class MyPageViewModel: ObservableObject {

    // MARK: - Published プロパティ

    @Published var planType: PlanType = .free
    @Published var ticketCount: Int32 = 0
    @Published var expiresAt: Date?
    @Published var isAIConsentGiven: Bool = false
    @Published var showRevokeConsentAlert = false

    // 購入処理の状態
    @Published var isProcessing = false
    @Published var alertMessage: String?
    @Published var showAlert = false

    private let cdManager = CoreDataManager.shared
    private let store = StoreManager.shared

    // MARK: - 初期化

    init() {
        refresh()
    }

    // MARK: - データ更新

    func refresh() {
        let plan = cdManager.fetchOrCreateUserPlan()
        planType = PlanType(rawValue: plan.planType ?? "free") ?? .free
        ticketCount = cdManager.totalTicketCount
        expiresAt = plan.expiresAt
        isAIConsentGiven = plan.isAIConsentGiven
    }

    // MARK: - AI同意操作

    func revokeAIConsent() {
        cdManager.setAIConsent(false)
        isAIConsentGiven = false
    }

    func grantAIConsent() {
        cdManager.setAIConsent(true)
        isAIConsentGiven = true
    }

    // MARK: - 購入処理

    func buyTicket45() async {
        isProcessing = true
        await store.purchaseTicket45()
        isProcessing = false
        if let error = store.purchaseError {
            alertMessage = error
            showAlert = true
        } else if store.purchaseError == nil {
            refresh()
        }
    }

    func purchaseBasic() async {
        isProcessing = true
        await store.purchaseBasic()
        isProcessing = false
        if let error = store.purchaseError {
            alertMessage = error
            showAlert = true
        } else {
            refresh()
        }
    }

    func purchasePremium() async {
        isProcessing = true
        await store.purchasePremium()
        isProcessing = false
        if let error = store.purchaseError {
            alertMessage = error
            showAlert = true
        } else {
            refresh()
        }
    }

    // MARK: - 購入復元

    func restorePurchases() async {
        isProcessing = true
        await store.restorePurchases()
        isProcessing = false
        refresh()
        if let error = store.purchaseError {
            alertMessage = error
            showAlert = true
        }
    }

    // MARK: - プランバッジカラー

    var planBadgeColor: Color {
        switch planType {
        case .free: return .gray
        case .basic: return .blue
        case .premium: return Color(hex: "C9A84C")
        }
    }

    // MARK: - バージョン

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
    }
}

// MARK: - Color(hex:) 拡張

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
