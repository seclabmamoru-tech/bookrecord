import SwiftUI

/// メモ選択シート用の値型
private struct MemoItem: Identifiable {
    let id: Int   // fetchMemos の順番インデックス
    let content: String
}

/// 書籍要約画面
struct AISummaryView: View {

    @ObservedObject var viewModel: AIViewModel
    @State private var selectedBook: Book?
    @State private var showResult = false
    @State private var showRetryAlert = false
    @State private var showMyPageForConsent = false
    @State private var showMemoSelection = false
    @State private var memosForSelection: [MemoItem] = []
    @State private var selectedMemoIDs: Set<Int> = []

    private let memoLimit = 30

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
                        Task { await handleExecute() }
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
            .onChange(of: selectedBook) { book in
                guard let book else { memosForSelection = []; return }
                let items = CoreDataManager.shared.fetchMemos(for: book)
                    .map { $0.content ?? "" }
                    .filter { !$0.isEmpty }
                    .enumerated()
                    .map { MemoItem(id: $0.offset, content: $0.element) }
                memosForSelection = items
            }
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
            .sheet(isPresented: $showMemoSelection) {
                MemoSelectionView(
                    memos: memosForSelection,
                    selectedIDs: $selectedMemoIDs,
                    limit: memoLimit
                ) {
                    showMemoSelection = false
                    Task { await executeAI(memos: selectedMemos) }
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
                    Task { await handleExecute() }
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
                        Text("ai.summary.noMemoNote")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    } else {
                        HStack(spacing: 4) {
                            Text(String(format: NSLocalizedString("book.memoCount", comment: ""), memoCount))
                                .font(.caption2)
                                .foregroundColor(.indigo)
                            if memoCount > memoLimit {
                                Text("ai.summary.memoSelectRequired")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                        }
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

    private var selectedMemos: [String] {
        memosForSelection
            .filter { selectedMemoIDs.contains($0.id) }
            .map { $0.content }
    }

    // MARK: - 実行ハンドラ

    private func handleExecute() async {
        if memosForSelection.count > memoLimit {
            selectedMemoIDs = []
            showMemoSelection = true
        } else {
            await executeAI(memos: memosForSelection.map { $0.content })
        }
    }

    private func executeAI(memos: [String]) async {
        guard let book = selectedBook else { return }

        let prompt = AIPrompts.summary(
            bookTitle: book.title ?? "",
            author: book.author ?? "",
            memos: memos
        )
        let bookData = [AIBookData(title: book.title ?? "", author: book.author ?? "", memos: memos)]
        let plan = CoreDataManager.shared.fetchOrCreateUserPlan()
        let planType = PlanType(rawValue: plan.planType ?? "free") ?? .free
        let willShowAd = PlanLimits.showAIInterstitial(for: planType)
        if willShowAd {
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

// MARK: - メモ選択シート

private struct MemoSelectionView: View {

    let memos: [MemoItem]
    @Binding var selectedIDs: Set<Int>
    let limit: Int
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(memos) { memo in
                        memoRow(memo)
                        Divider().padding(.leading, 16)
                    }
                }
            }
            .navigationTitle(
                String(format: NSLocalizedString("ai.summary.memoSelection.title", comment: ""), selectedIDs.count, limit)
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("ai.execute.summary.confirm") {
                        onConfirm()
                    }
                    .disabled(selectedIDs.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    @ViewBuilder
    private func memoRow(_ memo: MemoItem) -> some View {
        let isSelected = selectedIDs.contains(memo.id)
        let isDisabled = !isSelected && selectedIDs.count >= limit

        Button {
            if isSelected {
                selectedIDs.remove(memo.id)
            } else if !isDisabled {
                selectedIDs.insert(memo.id)
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .indigo : (isDisabled ? Color.secondary.opacity(0.4) : .secondary))
                    .font(.title3)
                Text(memo.content)
                    .font(.body)
                    .foregroundColor(isDisabled && !isSelected ? .secondary : .primary)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

#Preview {
    AISummaryView(viewModel: AIViewModel())
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
}
