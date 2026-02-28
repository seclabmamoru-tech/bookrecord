import SwiftUI
import Combine

/// ホーム画面の ViewModel（統計・タイマー管理）
final class HomeViewModel: ObservableObject {

    // MARK: - Published プロパティ

    @Published var allBooks: [Book] = []
    @Published var readingBooks: [Book] = []
    @Published var isTimerRunning = false
    @Published var elapsedSeconds: Int = 0
    @Published var selectedBook: Book?
    @Published var showMemoSheet = false
    @Published var selectedYear: Int = Calendar.current.component(.year, from: Date())

    // MARK: - プライベートプロパティ

    private var timerInstance: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let coreData = CoreDataManager.shared

    // MARK: - 初期化

    init() {
        fetchBooks()
        observeContext()
    }

    // MARK: - データ取得

    func fetchBooks() {
        allBooks = coreData.fetchBooks()
        readingBooks = allBooks.filter { $0.status == "reading" }
        // 選択中の書籍が読書中でない場合はリセット
        if let selected = selectedBook, !readingBooks.contains(where: { $0.id == selected.id }) {
            selectedBook = readingBooks.first
        } else if selectedBook == nil {
            selectedBook = readingBooks.first
        }
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

    // MARK: - 統計計算

    /// 総読了冊数
    var completedBooksCount: Int {
        allBooks.filter { $0.status == "completed" }.count
    }

    /// 総読書時間（分）
    var totalReadingMinutes: Int32 {
        allBooks.reduce(0) { $0 + $1.totalReadingMinutes }
    }

    /// 総読書時間のフォーマット文字列（例: "12h 30m"）
    var totalReadingTimeFormatted: String {
        let hours = totalReadingMinutes / 60
        let minutes = totalReadingMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    /// ジャンル別冊数データ
    var genreData: [(String, Int)] {
        var counts: [String: Int] = [:]
        for book in allBooks {
            let genre = book.genre ?? "その他"
            counts[genre, default: 0] += 1
        }
        return counts.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    /// 選択可能な年の一覧（読了済み書籍の年 + 当年）
    var availableYears: [Int] {
        let calendar = Calendar.current
        var years = Set<Int>()
        years.insert(calendar.component(.year, from: Date()))
        for book in allBooks where book.status == "completed" {
            if let endDate = book.endDate {
                years.insert(calendar.component(.year, from: endDate))
            }
        }
        return years.sorted()
    }

    /// 選択中の年の月別読了冊数データ（1〜12月）
    var monthlyData: [(String, Int)] {
        let completedBooks = allBooks.filter { $0.status == "completed" && $0.endDate != nil }
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.current
        dateFormatter.dateFormat = "M月"

        return (1...12).compactMap { month in
            var components = DateComponents()
            components.year = selectedYear
            components.month = month
            guard let date = calendar.date(from: components) else { return nil }
            let label = dateFormatter.string(from: date)
            let count = completedBooks.filter { book in
                guard let endDate = book.endDate else { return false }
                return calendar.isDate(endDate, equalTo: date, toGranularity: .month)
            }.count
            return (label, count)
        }
    }

    // MARK: - タイマー操作

    /// タイマーを開始する
    func startTimer() {
        guard !isTimerRunning else { return }
        isTimerRunning = true
        elapsedSeconds = 0
        timerInstance = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.elapsedSeconds += 1
        }
        if let t = timerInstance {
            RunLoop.main.add(t, forMode: .common)
        }
    }

    /// タイマーを停止し ReadingSession を保存する
    func stopTimer() {
        timerInstance?.invalidate()
        timerInstance = nil
        isTimerRunning = false

        // 1分以上計測した場合のみ保存
        let minutes = Int32(elapsedSeconds / 60)
        if minutes > 0, let book = selectedBook {
            coreData.addReadingSession(book: book, durationMinutes: minutes, date: Date())
            fetchBooks()
        }
        elapsedSeconds = 0
    }

    /// 経過時間の表示文字列（mm:ss 形式）
    var elapsedTimeString: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - タイマー中のメモ追加

    /// タイマー中にメモを追加する
    func addMemo(content: String, to book: Book) {
        let memos = coreData.fetchMemos(for: book)
        let nextOrder = Int32((memos.map { $0.sortOrder }.max().map { Int($0) } ?? -1) + 1)
        coreData.addMemo(content: content, to: book, sortOrder: nextOrder)
    }
}
