import SwiftUI

/// 書籍詳細画面（書籍情報・メモ管理・読書セッション履歴）
struct BookDetailView: View {

    @EnvironmentObject var viewModel: LibraryViewModel
    @EnvironmentObject var homeViewModel: HomeViewModel
    @Environment(\.dismiss) private var dismiss

    let book: Book

    @State private var memos: [Memo] = []
    @State private var sessions: [ReadingSession] = []
    @State private var showAddMemo = false
    @State private var selectedMemo: Memo?
    @State private var showEditBook = false
    @State private var showDeleteAlert = false
    @State private var memoToDelete: Memo?
    @State private var showDeleteMemoAlert = false
    @State private var sessionToDelete: ReadingSession?
    @State private var showDeleteSessionAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 書籍情報ヘッダー
                bookHeader

                Divider()

                // メモセクション
                memoSection

                Divider()

                // 読書セッション履歴
                sessionSection

                // 読書タイマー（読書中のみ）
                if book.status == "reading" {
                    Divider()
                    timerSection
                }

                // 書籍削除
                Divider()
                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Label("book.delete", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .padding(.top, 4)
            }
            .padding()
        }
        .navigationTitle(book.title ?? "")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showEditBook = true
                } label: {
                    Text("common.edit")
                }
            }
        }
        .sheet(isPresented: $showAddMemo, onDismiss: loadData) {
            AddEditMemoView(book: book, memo: nil)
                .environmentObject(viewModel)
        }
        .sheet(item: $selectedMemo, onDismiss: loadData) { memo in
            AddEditMemoView(book: book, memo: memo)
                .environmentObject(viewModel)
        }
        .sheet(isPresented: $showEditBook) {
            AddBookView(book: book)
                .environmentObject(viewModel)
        }
        .alert("common.deleteConfirm", isPresented: $showDeleteAlert) {
            Button("common.delete", role: .destructive) {
                viewModel.deleteBook(book)
                dismiss()
            }
            Button("common.cancel", role: .cancel) {}
        }
        .onAppear { loadData() }
        .onChange(of: viewModel.books) { _ in loadData() }
    }

    // MARK: - データ読み込み

    private func loadData() {
        memos = viewModel.fetchMemos(for: book)
        sessions = viewModel.fetchSessions(for: book)
    }

    // MARK: - 書籍情報ヘッダー

    private var bookHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            // 表紙画像
            if let imageData = book.coverImageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 90, height: 120)
                    .clipped()
                    .cornerRadius(8)
                    .shadow(radius: 4)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(width: 90, height: 120)
                    .overlay(
                        Image(systemName: "book.closed.fill")
                            .font(.title)
                            .foregroundColor(.gray)
                    )
            }

            // 書籍情報
            VStack(alignment: .leading, spacing: 6) {
                Text(book.title ?? "")
                    .font(.headline)
                    .lineLimit(3)

                if let author = book.author, !author.isEmpty {
                    Text(author)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                StatusBadge(status: book.status ?? "want")

                if let genre = book.genre, !genre.isEmpty {
                    Label(genre, systemImage: "tag")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // 読書期間
                if let start = book.startDate {
                    let formatter = DateFormatter()
                    let _ = (formatter.dateStyle = .short)
                    let _ = (formatter.locale = .current)
                    let startStr = formatter.string(from: start)
                    let endStr = book.endDate.map { formatter.string(from: $0) } ?? "…"
                    Label("\(startStr) 〜 \(endStr)", systemImage: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // 累計読書時間
                let hours = book.totalReadingMinutes / 60
                let minutes = book.totalReadingMinutes % 60
                Label(hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m", systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - メモセクション

    private var memoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("book.memos")
                    .font(.headline)
                Spacer()
                Button {
                    showAddMemo = true
                } label: {
                    Image(systemName: "plus.circle")
                }
                .tint(.indigo)
            }

            if memos.isEmpty {
                Text("book.noMemos")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                    .padding(.vertical, 8)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(memos, id: \.id) { memo in
                            MemoRow(memo: memo) {
                                selectedMemo = memo
                            } onDelete: {
                                memoToDelete = memo
                                showDeleteMemoAlert = true
                            }
                            if memo.id != memos.last?.id {
                                Divider().padding(.leading, 32)
                            }
                        }
                    }
                }
                .frame(maxHeight: 260)
            }
        }
        .alert("common.deleteConfirm", isPresented: $showDeleteMemoAlert) {
            Button("common.delete", role: .destructive) {
                if let m = memoToDelete {
                    viewModel.deleteMemo(m)
                    loadData()
                }
            }
            Button("common.cancel", role: .cancel) {}
        }
    }

    // MARK: - 読書タイマー

    private var timerSection: some View {
        let isThisBook = homeViewModel.isTimerRunning && homeViewModel.selectedBook?.id == book.id
        let isOtherBook = homeViewModel.isTimerRunning && homeViewModel.selectedBook?.id != book.id
        return CardContainer {
            VStack(spacing: 16) {
                Label("book.timer", systemImage: "timer")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(isThisBook ? homeViewModel.elapsedTimeString : "00:00")
                    .font(.system(size: 52, weight: .thin, design: .monospaced))
                    .foregroundColor(isThisBook ? .indigo : .primary)

                if isThisBook {
                    Button(action: homeViewModel.stopTimer) {
                        Label("home.timer.stop", systemImage: "stop.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                } else if isOtherBook {
                    Text("home.timer.otherBook")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Button {
                        homeViewModel.selectedBook = book
                        homeViewModel.startTimer()
                    } label: {
                        Label("home.timer.start", systemImage: "play.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                }
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - 読書セッション履歴

    private var sessionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("book.sessionHistory")
                .font(.headline)

            if sessions.isEmpty {
                Text("book.noSessions")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                    .padding(.vertical, 8)
            } else {
                ForEach(sessions, id: \.id) { session in
                    SessionRow(session: session) {
                        sessionToDelete = session
                        showDeleteSessionAlert = true
                    }
                    if session.id != sessions.last?.id {
                        Divider()
                    }
                }
            }
        }
        .alert("common.deleteConfirm", isPresented: $showDeleteSessionAlert) {
            Button("common.delete", role: .destructive) {
                if let s = sessionToDelete {
                    viewModel.deleteSession(s)
                    loadData()
                }
            }
            Button("common.cancel", role: .cancel) {}
        }
    }
}

// MARK: - ステータスバッジ

struct StatusBadge: View {
    let status: String

    var label: String {
        switch status {
        case "want": return NSLocalizedString("library.filter.want", comment: "")
        case "reading": return NSLocalizedString("library.filter.reading", comment: "")
        case "completed": return NSLocalizedString("library.filter.completed", comment: "")
        default: return status
        }
    }

    var color: Color {
        switch status {
        case "want": return .orange
        case "reading": return .blue
        case "completed": return .green
        default: return .gray
        }
    }

    var body: some View {
        Text(label)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}

// MARK: - メモ行

private struct MemoRow: View {
    let memo: Memo
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button(action: onTap) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "quote.bubble")
                        .foregroundColor(.indigo)
                        .font(.subheadline)
                        .padding(.top, 2)

                    Text(memo.content ?? "")
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundColor(.primary)
                }
            }
            .buttonStyle(.plain)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .font(.caption)
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - セッション行

private struct SessionRow: View {
    let session: ReadingSession
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "clock.fill")
                .foregroundColor(.indigo)
            if let date = session.date {
                Text(date, style: .date)
                    .font(.subheadline)
            }
            Spacer()
            let h = session.durationMinutes / 60
            let m = session.durationMinutes % 60
            Text(h > 0 ? "\(h)h \(m)m" : "\(m)m")
                .font(.subheadline.bold())
                .foregroundColor(.indigo)
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        BookDetailView(book: Book())
            .environmentObject(LibraryViewModel())
            .environmentObject(HomeViewModel())
    }
}
