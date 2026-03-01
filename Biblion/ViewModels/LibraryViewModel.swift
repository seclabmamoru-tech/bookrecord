import SwiftUI
import Combine

/// ライブラリ画面の ViewModel（書籍管理）
final class LibraryViewModel: ObservableObject {

    // MARK: - Published プロパティ

    @Published var books: [Book] = []
    @Published var selectedStatus: String = "all"
    @Published var selectedGenre: String = "all"
    @Published var showAddBook = false
    @Published var errorMessage: String?
    @Published var showError = false

    // MARK: - プライベートプロパティ

    private var cancellables = Set<AnyCancellable>()
    private let coreData = CoreDataManager.shared

    // MARK: - 定数

    static let genres = ["genre.business", "genre.selfHelp", "genre.fiction", "genre.technology", "genre.history", "genre.other"]
    static let statuses = ["want", "reading", "completed"]

    // MARK: - 初期化

    init() {
        fetchBooks()
        observeContext()
    }

    // MARK: - フィルタリング

    /// フィルター適用後の書籍一覧
    var filteredBooks: [Book] {
        books.filter { book in
            let statusMatch = selectedStatus == "all" || book.status == selectedStatus
            let genreMatch = selectedGenre == "all" || book.genre == selectedGenre
            return statusMatch && genreMatch
        }
    }

    // MARK: - データ操作

    func fetchBooks() {
        books = coreData.fetchBooks()
    }

    func addBook(
        title: String,
        author: String,
        genre: String,
        status: String,
        startDate: Date?,
        endDate: Date?,
        coverImageData: Data?
    ) {
        coreData.addBook(
            title: title,
            author: author,
            genre: genre,
            status: status,
            startDate: startDate,
            endDate: endDate,
            coverImageData: coverImageData
        )
        fetchBooks()
    }

    func updateBook(_ book: Book) {
        coreData.updateBook(book)
        fetchBooks()
    }

    func deleteBook(_ book: Book) {
        coreData.deleteBook(book)
        fetchBooks()
    }

    // MARK: - メモ操作

    func addMemo(content: String, to book: Book) {
        let memos = coreData.fetchMemos(for: book)
        let nextOrder = Int32((memos.map { $0.sortOrder }.max().map { Int($0) } ?? -1) + 1)
        coreData.addMemo(content: content, to: book, sortOrder: nextOrder)
    }

    func updateMemo(_ memo: Memo) {
        coreData.updateMemo(memo)
    }

    func deleteMemo(_ memo: Memo) {
        coreData.deleteMemo(memo)
    }

    func reorderMemos(_ memos: [Memo], from source: IndexSet, to destination: Int) {
        var reordered = memos
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, memo) in reordered.enumerated() {
            memo.sortOrder = Int32(index)
        }
        coreData.save()
    }

    func fetchMemos(for book: Book) -> [Memo] {
        coreData.fetchMemos(for: book)
    }

    func deleteSession(_ session: ReadingSession) {
        coreData.deleteReadingSession(session)
    }

    func fetchSessions(for book: Book) -> [ReadingSession] {
        coreData.fetchReadingSessions(for: book)
    }

    // MARK: - CoreData 変更監視

    private func observeContext() {
        NotificationCenter.default.publisher(
            for: .NSManagedObjectContextObjectsDidChange,
            object: coreData.context
        )
        .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
        .sink { [weak self] _ in
            self?.fetchBooks()
        }
        .store(in: &cancellables)
    }
}
