import SwiftUI

/// 書籍要約画面
struct AISummaryView: View {

    @ObservedObject var viewModel: AIViewModel
    @State private var selectedBook: Book?
    @State private var showResult = false
    @State private var showRetryAlert = false
    @State private var showMyPageForConsent = false

    private var allBooks: [Book] {
        CoreDataManager.shared.fetchBooks()
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if allBooks.isEmpty {
                    emptyState
                } else {
                    bookList
                }

                // 実行ボタン
                VStack {
                    Button {
                        Task { await executeAI() }
                    } label: {
                        Text("ai.execute.summary")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canExecute ? Color.indigo : Color(.systemGray4))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(!canExecute)
                    .padding()
                }
                .background(Color(.systemBackground))
            }
            .navigationTitle(Text("ai.menu.summary.title"))
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showResult) {
                if let result = viewModel.result {
                    AIResultView(
                        result: result,
                        referencedBooks: viewModel.referencedBooks,
                        menuType: .summary,
                        onRetry: {
                            showResult = false
                            showRetryAlert = true
                        }
                    )
                }
            }
            .alert("ai.notConsented", isPresented: $viewModel.showConsentView) {
                Button("ai.consent.goMyPage") { showMyPageForConsent = true }
                Button("common.cancel", role: .cancel) {}
            } message: {
                Text("ai.consentRequired")
            }
            .sheet(isPresented: $showMyPageForConsent) {
                MyPageView()
            }
            .alert("ai.menu.noTicketTitle", isPresented: $viewModel.showPurchasePrompt) {
                Button("common.cancel", role: .cancel) {}
            } message: {
                Text("ai.menu.noTicketMessage")
            }
            .alert("ai.result.retryAlert", isPresented: $showRetryAlert) {
                Button("common.cancel", role: .cancel) {}
                Button("ai.result.retry") {
                    Task { await executeAI() }
                }
            }
            .alert("common.error", isPresented: .init(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("common.done", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }

            // ローディングオーバーレイ
            if viewModel.isLoading {
                loadingOverlay
            }
        }
    }

    // MARK: - 書籍リスト（全書籍表示）

    private var bookList: some View {
        List(allBooks, id: \.id, selection: $selectedBook) { book in
            let memoCount = CoreDataManager.shared.fetchMemos(for: book).count
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title ?? "")
                        .font(.body)
                    Text(book.author ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if memoCount == 0 {
                        // メモなし：一般情報でサマリーすることを示すバッジ
                        Text("ai.summary.noMemoNote")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    } else {
                        Text(String(format: NSLocalizedString("book.memoCount", comment: ""), memoCount))
                            .font(.caption2)
                            .foregroundColor(.indigo)
                    }
                }

                Spacer()

                if selectedBook == book {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.indigo)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                selectedBook = (selectedBook == book) ? nil : book
            }
            .padding(.vertical, 4)
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - 空状態（書籍が1冊もない場合）

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "book.closed")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("library.empty")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                Text("ai.loading")
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            .padding(32)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemGray2)))
        }
    }

    private var canExecute: Bool {
        selectedBook != nil && !viewModel.isLoading
    }

    private func executeAI() async {
        guard let book = selectedBook else { return }
        let memos = CoreDataManager.shared.fetchMemos(for: book)
            .map { $0.content ?? "" }
            .filter { !$0.isEmpty }

        let prompt = AIPrompts.summary(
            bookTitle: book.title ?? "",
            author: book.author ?? "",
            memos: memos
        )
        // 選択した書籍のみを送信（他の書籍が参照書籍に混入しないよう）
        let bookData = [AIBookData(title: book.title ?? "", author: book.author ?? "", memos: memos)]
        let willShowAd = CoreDataManager.shared.fetchOrCreateUserPlan().freeTicketCount > 0
        if willShowAd {
            // 広告とAI生成を並行実行
            async let adTask: Void = withCheckedContinuation { cont in
                InterstitialAdManager.shared.showAIAd { cont.resume() }
            }
            await viewModel.executeAI(menuType: .summary, userInput: prompt, bookData: bookData)
            _ = await adTask
        } else {
            await viewModel.executeAI(menuType: .summary, userInput: prompt, bookData: bookData)
        }
        if viewModel.result != nil {
            showResult = true
        }
    }
}

#Preview {
    AISummaryView(viewModel: AIViewModel())
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
}
