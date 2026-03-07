import SwiftUI

/// SNS投稿生成画面
struct AISNSPostView: View {

    @ObservedObject var viewModel: AIViewModel
    @State private var selectedBook: Book?
    @State private var selectedMemoIDs: Set<NSManagedObjectID> = []
    @State private var selectedPlatform = 0  // 0=X, 1=Instagram, 2=Threads
    @State private var showResult = false
    @State private var showRetryAlert = false

    private let platforms = ["X", "Instagram", "Threads"]

    private var booksWithMemos: [Book] {
        CoreDataManager.shared.fetchBooks().filter { book in
            !CoreDataManager.shared.fetchMemos(for: book).isEmpty
        }
    }

    private var memosForSelectedBook: [Memo] {
        guard let book = selectedBook else { return [] }
        return CoreDataManager.shared.fetchMemos(for: book)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Form {
                    // 書籍選択
                    Section(header: Text("書籍を選択")) {
                        if booksWithMemos.isEmpty {
                            Text("ai.error.noMemo")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        } else {
                            ForEach(booksWithMemos, id: \.id) { book in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(book.title ?? "")
                                            .font(.body)
                                        Text(book.author ?? "")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if selectedBook == book {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.indigo)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if selectedBook == book {
                                        selectedBook = nil
                                        selectedMemoIDs = []
                                    } else {
                                        selectedBook = book
                                        selectedMemoIDs = []
                                    }
                                }
                            }
                        }
                    }

                    // メモ選択（書籍選択後）
                    if let _ = selectedBook, !memosForSelectedBook.isEmpty {
                        Section(header: Text("ai.sns.selectMemos")) {
                            ForEach(memosForSelectedBook, id: \.id) { memo in
                                let isSelected = selectedMemoIDs.contains(memo.objectID)
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                                        .foregroundColor(isSelected ? .indigo : .gray)
                                    Text(memo.content ?? "")
                                        .font(.subheadline)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if isSelected {
                                        selectedMemoIDs.remove(memo.objectID)
                                    } else {
                                        selectedMemoIDs.insert(memo.objectID)
                                    }
                                }
                            }
                        }
                    }

                    // 投稿先選択
                    Section(header: Text("ai.sns.platform")) {
                        Picker("ai.sns.platform", selection: $selectedPlatform) {
                            ForEach(platforms.indices, id: \.self) { i in
                                Text(platforms[i]).tag(i)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    // 実行ボタン
                    Section {
                        Button {
                            Task { await executeAI() }
                        } label: {
                            Text("ai.execute.sns")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .foregroundColor(canExecute ? .white : .secondary)
                        }
                        .listRowBackground(canExecute ? Color.indigo : Color(.systemGray4))
                        .disabled(!canExecute)
                    }
                }
                .navigationTitle(Text("ai.menu.sns.title"))
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(isPresented: $showResult) {
                    if let result = viewModel.result {
                        AIResultView(
                            result: result,
                            referencedBooks: viewModel.referencedBooks,
                            menuType: .sns,
                            onRetry: {
                                showResult = false
                                showRetryAlert = true
                            }
                        )
                    }
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
        selectedBook != nil && !selectedMemoIDs.isEmpty && !viewModel.isLoading
    }

    private func executeAI() async {
        guard let book = selectedBook else { return }
        let platform = platforms[selectedPlatform]
        let selectedMemos = memosForSelectedBook
            .filter { selectedMemoIDs.contains($0.objectID) }
            .map { $0.content ?? "" }
            .joined(separator: "\n- ")

        let prompt = "\(platform)用の書評投稿を作成してください。書籍：\(book.title ?? "")（\(book.author ?? "")）\n選択したメモ：\n- \(selectedMemos)"
        await viewModel.executeAI(menuType: .sns, userInput: prompt)
        if viewModel.result != nil {
            showResult = true
        }
    }
}

#Preview {
    AISNSPostView(viewModel: AIViewModel())
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
}
