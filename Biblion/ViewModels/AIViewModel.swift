import SwiftUI
import Combine

// MARK: - AIViewModel

@MainActor
final class AIViewModel: ObservableObject {

    // MARK: - Published プロパティ

    @Published var isLoading = false
    @Published var result: String?
    @Published var referencedBooks: [String] = []
    @Published var errorMessage: String?
    @Published var showConsentView = false
    @Published var showPurchasePrompt = false
    @Published var ticketCount: Int32 = 0
    @Published var currentPlan: PlanType = .free
    @Published var lastMenuType: AIMenuType?

    private let service = AIService()
    private let cdManager = CoreDataManager.shared

    // MARK: - 初期化

    init() {
        refreshFromCoreData()
    }

    // MARK: - CoreDataから状態を読み込む

    func refreshFromCoreData() {
        let plan = cdManager.fetchOrCreateUserPlan()
        ticketCount = plan.ticketCount
        currentPlan = PlanType(rawValue: plan.planType ?? "free") ?? .free
    }

    // MARK: - AI同意確認

    var isAIConsentGiven: Bool {
        cdManager.fetchOrCreateUserPlan().isAIConsentGiven
    }

    // MARK: - AI実行

    func executeAI(menuType: AIMenuType, userInput: String) async {
        // 1. 同意確認
        guard isAIConsentGiven else {
            showConsentView = true
            return
        }

        // 2. チケット確認
        let plan = cdManager.fetchOrCreateUserPlan()
        guard plan.ticketCount > 0 else {
            showPurchasePrompt = true
            return
        }

        // 3. ローディング開始
        isLoading = true
        result = nil
        referencedBooks = []
        errorMessage = nil
        lastMenuType = menuType

        // 4. 送信用書籍データを構築
        let books = cdManager.fetchBooks()
        let bookData: [AIBookData] = books.compactMap { book in
            let memos = cdManager.fetchMemos(for: book).map { $0.content ?? "" }.filter { !$0.isEmpty }
            guard !memos.isEmpty else { return nil }
            return AIBookData(
                title: book.title ?? "",
                author: book.author ?? "",
                memos: memos
            )
        }

        // 5. API呼び出し
        do {
            let response = try await service.execute(
                menuType: menuType,
                userInput: userInput,
                bookData: bookData
            )

            // 6. 成功: チケット消費 → CoreData保存 → 結果表示
            cdManager.consumeTicket()
            cdManager.addAIHistory(
                menuType: menuType.rawValue,
                inputText: userInput,
                outputText: response.result
            )
            result = response.result
            referencedBooks = response.referencedBooks
            refreshFromCoreData()

        } catch {
            // 7. 失敗: チケット消費なし
            if let aiError = error as? AIServiceError {
                errorMessage = aiError.errorDescription
            } else {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    // MARK: - 再試行（チケット1枚追加消費）

    func retryAI(menuType: AIMenuType, userInput: String) async {
        await executeAI(menuType: menuType, userInput: userInput)
    }

    // MARK: - 書籍メモの件数（参照可能書籍数）

    var booksWithMemosCount: Int {
        let books = cdManager.fetchBooks()
        return books.filter { book in
            let memos = cdManager.fetchMemos(for: book)
            return !memos.isEmpty
        }.count
    }
}
