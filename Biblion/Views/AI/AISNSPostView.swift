import SwiftUI
import CoreData

/// SNS投稿生成画面
struct AISNSPostView: View {

    @ObservedObject var viewModel: AIViewModel
    @State private var selectedBook: Book?
    @State private var selectedMemoIDs: Set<NSManagedObjectID> = []
    @State private var selectedPlatform = 0  // 0=X, 1=Instagram, 2=Threads
    @State private var selectedGenres: Set<String> = []
    @State private var showResult = false
    @State private var showRetryAlert = false
    @State private var showMyPageForConsent = false

    private let platforms = ["X", "Instagram", "Threads"]

    private struct GenreCategory {
        let name: String
        let genres: [String]
    }

    private let genreCategories: [GenreCategory] = [
        GenreCategory(name: "直感", genres: ["驚き", "楽しい", "尊い", "癒し", "感動", "ショック"]),
        GenreCategory(name: "知識", genres: ["得した", "注意喚起"]),
        GenreCategory(name: "主張", genres: ["同調", "物申す"]),
        GenreCategory(name: "納得", genres: ["あるある", "真理"]),
        GenreCategory(name: "声援", genres: ["応援", "支援"]),
        GenreCategory(name: "欲求", genres: ["したい", "報酬"])
    ]

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
        ZStack {
            Form {
                    // 書籍選択
                    Section(header: Text("home.timer.selectBook")) {
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

                    // ジャンル選択
                    Section(header: Text("ai.sns.genre")) {
                        ForEach(genreCategories, id: \.name) { category in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(category.name)
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 6) {
                                    ForEach(category.genres, id: \.self) { genre in
                                        let isSelected = selectedGenres.contains(genre)
                                        Button(action: {
                                            if isSelected {
                                                selectedGenres.remove(genre)
                                            } else {
                                                selectedGenres.insert(genre)
                                            }
                                        }) {
                                            Text(genre)
                                                .font(.subheadline)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .frame(maxWidth: .infinity)
                                                .background(isSelected ? Color.indigo : Color(.systemGray5))
                                                .foregroundColor(isSelected ? .white : .primary)
                                                .cornerRadius(16)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
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
        selectedBook != nil && !selectedMemoIDs.isEmpty && !selectedGenres.isEmpty && !viewModel.isLoading
    }

    private func executeAI() async {
        guard let book = selectedBook else { return }
        let platform = platforms[selectedPlatform]
        let filteredMemos = memosForSelectedBook.filter { selectedMemoIDs.contains($0.objectID) }
        let selectedMemosText = filteredMemos
            .map { $0.content ?? "" }
            .joined(separator: "\n- ")

        let genreText = selectedGenres.sorted().joined(separator: "・")
        let prompt = """
あなたはフォロワー100万人を超えるインフルエンサーです。\
読んだ本の「本質」を一言で刺せる投稿を量産してきたプロです。\
以下の条件をもとに、\(platform)で拡散される書評投稿を1つ作成してください。

---

【書籍】
\(book.title ?? "")（\(book.author ?? "")）

【選んだメモ（本の核心）】
- \(selectedMemosText)

【読み手に与えたい感情】
\(genreText)

---

## 投稿を作るときのルール

### ① 冒頭で「スクロールを止める」
- 最初の1行で読者の手を止めること
- 「え、それ私のことだ」と思わせる書き出し
- 数字・問いかけ・逆説のどれかを使う

### ② 「感情の流れ」を設計する
以下の順番で感情を動かすこと：
違和感 → 共感 → 納得 → 行動したくなる

### ③ 具体と抽象を交互に使う
- 抽象論だけでは刺さらない
- 選んだメモの内容から "あの瞬間"を想起させる具体場面を入れる

### ④ 締めは「行動・思考の変化」を促す一言
- 読後に何かしたくなる・考えたくなる余韻を残す
- 問いかけ or 短い命令形が効果的

### ⑤ ハッシュタグ
- 3〜5個・拡散力のあるものだけ選ぶ
- 書名タグは必ず入れる

---

## 出力形式
投稿案を3つ作成してください。
各案は「【案1】」「【案2】」「【案3】」の見出しで区切り、投稿本文のみ出力してください（解説・注釈・補足は不要）。
"""

        // 選択した書籍・メモのみをAPIに送信
        let bookData = [AIBookData(
            title: book.title ?? "",
            author: book.author ?? "",
            memos: filteredMemos.map { $0.content ?? "" }
        )]
        // フリーチケット使用時はAI依頼のタイミングで広告を表示
        let willShowAd = CoreDataManager.shared.fetchOrCreateUserPlan().freeTicketCount > 0
        if willShowAd {
            await withCheckedContinuation { continuation in
                InterstitialAdManager.shared.showAIAd { continuation.resume() }
            }
        }
        await viewModel.executeAI(menuType: .sns, userInput: prompt, bookData: bookData)
        if viewModel.result != nil {
            showResult = true
        }
    }
}

#Preview {
    AISNSPostView(viewModel: AIViewModel())
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
}
