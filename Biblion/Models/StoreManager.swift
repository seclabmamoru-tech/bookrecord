import Foundation
import Combine

// MARK: - プランタイプ

enum PlanType: String, CaseIterable {
    case free = "free"
    case basic = "basic"
    case premium = "premium"

    var displayName: String {
        switch self {
        case .free: return "Freeプラン"
        case .basic: return "Basicプラン"
        case .premium: return "Premiumプラン"
        }
    }

    var displayNameEn: String {
        switch self {
        case .free: return "Free Plan"
        case .basic: return "Basic Plan"
        case .premium: return "Premium Plan"
        }
    }
}

// MARK: - プラン別機能制限

struct PlanLimits {
    /// タスク上限（nilは無制限）
    static func taskLimit(for plan: PlanType) -> Int? {
        switch plan {
        case .free: return 4
        case .basic, .premium: return nil
        }
    }

    /// バーコードスキャン利用可否（デモ用：全プラン解放）
    static func canUseBarcodeScanner(for plan: PlanType) -> Bool {
        return true
    }

    /// 起動時インタースティシャル表示可否
    static func showLaunchInterstitial(for plan: PlanType) -> Bool {
        return plan == .free
    }

    /// AI実行時インタースティシャル表示可否
    static func showAIInterstitial(for plan: PlanType) -> Bool {
        return plan == .free || plan == .basic
    }

    /// 月次チケット付与数
    static func monthlyTickets(for plan: PlanType) -> Int {
        switch plan {
        case .free: return 1
        case .basic: return 1
        case .premium: return 10
        }
    }
}

// MARK: - StoreManager（課金機能は将来実装）

@MainActor
final class StoreManager: ObservableObject {

    static let shared = StoreManager()

    @Published var currentPlan: PlanType = .free

    private init() {
        loadPlanFromCoreData()
    }

    private func loadPlanFromCoreData() {
        let userPlan = CoreDataManager.shared.fetchOrCreateUserPlan()
        currentPlan = PlanType(rawValue: userPlan.planType ?? "free") ?? .free
    }

    /// プラン更新（将来のStoreKit 2実装用）
    func updatePlan(_ planType: PlanType, expiresAt: Date? = nil) {
        currentPlan = planType
        CoreDataManager.shared.updateUserPlan(planType: planType.rawValue, expiresAt: expiresAt)
    }
}
