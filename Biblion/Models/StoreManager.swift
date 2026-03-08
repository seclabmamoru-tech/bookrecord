import Foundation
import Combine
import StoreKit

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

    /// バーコードスキャン利用可否（Basic以上のプランで利用可能）
    static func canUseBarcodeScanner(for plan: PlanType) -> Bool {
        return plan == .basic || plan == .premium
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

// MARK: - プロダクトID

enum ProductID {
    static let basicMonthly   = "jp.it_master.Biblion.basic.monthly"
    static let premiumMonthly = "jp.it_master.Biblion.premium.monthly"
    static let ticket45       = "jp.it_master.Biblion.tickets.45"

    static var allIDs: [String] { [basicMonthly, premiumMonthly, ticket45] }
}

// MARK: - StoreError

enum StoreError: LocalizedError {
    case failedVerification
    case productNotFound

    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return NSLocalizedString("store.error.failedVerification", comment: "")
        case .productNotFound:
            return NSLocalizedString("store.error.productNotFound", comment: "")
        }
    }
}

// MARK: - StoreManager

@MainActor
final class StoreManager: ObservableObject {

    static let shared = StoreManager()

    @Published var currentPlan: PlanType = .free
    @Published var isProcessing = false
    @Published var purchaseError: String?

    private var products: [String: Product] = [:]
    private var transactionListener: Task<Void, Error>?

    private init() {
        loadPlanFromCoreData()
        transactionListener = listenForTransactions()
        Task { await fetchProducts() }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - 内部：CoreDataからプラン読み込み

    private func loadPlanFromCoreData() {
        let userPlan = CoreDataManager.shared.fetchOrCreateUserPlan()
        currentPlan = PlanType(rawValue: userPlan.planType ?? "free") ?? .free
    }

    /// プラン更新
    func updatePlan(_ planType: PlanType, expiresAt: Date? = nil) {
        currentPlan = planType
        CoreDataManager.shared.updateUserPlan(planType: planType.rawValue, expiresAt: expiresAt)
    }

    // MARK: - 商品情報取得

    func fetchProducts() async {
        do {
            let storeProducts = try await Product.products(for: ProductID.allIDs)
            for product in storeProducts {
                products[product.id] = product
            }
        } catch {
            print("商品情報の取得に失敗しました: \(error)")
        }
    }

    // MARK: - 購入

    /// チケット45枚を購入する
    func purchaseTicket45() async {
        await purchase(productID: ProductID.ticket45)
    }

    /// Basicプランを購入する
    func purchaseBasic() async {
        await purchase(productID: ProductID.basicMonthly)
    }

    /// Premiumプランを購入する
    func purchasePremium() async {
        await purchase(productID: ProductID.premiumMonthly)
    }

    private func purchase(productID: String) async {
        if products[productID] == nil {
            await fetchProducts()
        }
        guard let product = products[productID] else {
            purchaseError = StoreError.productNotFound.errorDescription
            return
        }

        isProcessing = true
        purchaseError = nil
        defer { isProcessing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await handleTransaction(transaction)
                await transaction.finish()
            case .userCancelled:
                break
            case .pending:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    // MARK: - 購入復元

    func restorePurchases() async {
        isProcessing = true
        purchaseError = nil
        defer { isProcessing = false }

        do {
            try await AppStore.sync()
            for await result in Transaction.currentEntitlements {
                if let transaction = try? checkVerified(result) {
                    await handleTransaction(transaction)
                }
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    // MARK: - トランザクションリスナー（バックグラウンド）

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if let transaction = try? await self.checkVerified(result) {
                    await self.handleTransaction(transaction)
                    await transaction.finish()
                }
            }
        }
    }

    // MARK: - トランザクション処理

    private func handleTransaction(_ transaction: Transaction) async {
        switch transaction.productID {
        case ProductID.basicMonthly:
            updatePlan(.basic, expiresAt: transaction.expirationDate)
        case ProductID.premiumMonthly:
            updatePlan(.premium, expiresAt: transaction.expirationDate)
        case ProductID.ticket45:
            CoreDataManager.shared.addPurchasedTickets(45)
        default:
            break
        }
    }

    // MARK: - 検証

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let value):
            return value
        }
    }
}
