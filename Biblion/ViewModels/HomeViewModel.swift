import SwiftUI
import Combine

/// ホーム画面の ViewModel（統計・タイマー管理）
final class HomeViewModel: ObservableObject {

    // MARK: - Published プロパティ

    @Published var allBooks: [Book] = []
    @Published var readingBooks: [Book] = []
    @Published var isTimerRunning = false
    @Published var isTimerPaused = false
    @Published var elapsedSeconds: Int = 0
    @Published var selectedBook: Book?
    @Published var showMemoSheet = false
    @Published var selectedYear: Int = Calendar.current.component(.year, from: Date())

    // MARK: - プライベートプロパティ

    private var timerInstance: Timer?
    /// 現在の計測セグメントの開始日時（一時停止中は nil）
    private var timerStartDate: Date?
    /// 一時停止までに積算した秒数
    private var accumulatedSeconds: Int = 0
    private var cancellables = Set<AnyCancellable>()
    private let coreData = CoreDataManager.shared

    // MARK: - 初期化

    init() {
        fetchBooks()
        observeContext()
        observeAppLifecycle()
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

    // MARK: - CoreData 変更監視・アプリライフサイクル監視

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

    private func observeAppLifecycle() {
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                // バックグラウンド移行時: UI 更新タイマーを停止（経過秒は timerStartDate で保持）
                self?.timerInstance?.invalidate()
                self?.timerInstance = nil
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                guard let self, self.isTimerRunning, !self.isTimerPaused else { return }
                // フォアグラウンド復帰時: 壁時計で経過秒を再計算し UI タイマーを再開
                self.updateElapsed()
                self.startUIRefreshTimer()
            }
            .store(in: &cancellables)
    }

    // MARK: - 統計計算

    /// 総読了冊数
    var completedBooksCount: Int {
        allBooks.filter { $0.status == "completed" }.count
    }

    /// 総読書時間（秒）※ totalReadingMinutes フィールドに秒数を格納
    var totalReadingSeconds: Int {
        Int(allBooks.reduce(0) { $0 + $1.totalReadingMinutes })
    }

    /// 総読書時間のフォーマット文字列（例: "1h1m1s"）
    var totalReadingTimeFormatted: String {
        let hours = totalReadingSeconds / 3600
        let minutes = (totalReadingSeconds % 3600) / 60
        let seconds = totalReadingSeconds % 60
        return "\(hours)h\(minutes)m\(seconds)s"
    }

    /// ジャンル別冊数データ
    var genreData: [(String, Int)] {
        var counts: [String: Int] = [:]
        for book in allBooks {
            let genreKey = book.genre ?? "genre.other"
            let localizedGenre = NSLocalizedString(genreKey, comment: "")
            counts[localizedGenre, default: 0] += 1
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
        dateFormatter.setLocalizedDateFormatFromTemplate("MMM")

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
        isTimerPaused = false
        accumulatedSeconds = 0
        timerStartDate = Date()
        elapsedSeconds = 0
        startUIRefreshTimer()
    }

    /// タイマーを一時停止する
    func pauseTimer() {
        guard isTimerRunning, !isTimerPaused else { return }
        updateElapsed()
        accumulatedSeconds = elapsedSeconds
        timerStartDate = nil
        timerInstance?.invalidate()
        timerInstance = nil
        isTimerPaused = true
    }

    /// タイマーを再開する
    func resumeTimer() {
        guard isTimerRunning, isTimerPaused else { return }
        timerStartDate = Date()
        isTimerPaused = false
        startUIRefreshTimer()
    }

    /// タイマーを停止し ReadingSession を保存する
    func stopTimer() {
        if isTimerRunning && !isTimerPaused {
            updateElapsed()
        }
        timerInstance?.invalidate()
        timerInstance = nil
        isTimerRunning = false
        isTimerPaused = false
        timerStartDate = nil
        accumulatedSeconds = 0

        // 1秒以上計測した場合は秒数をそのまま保存
        if elapsedSeconds > 0, let book = selectedBook {
            coreData.addReadingSession(book: book, durationSeconds: Int32(elapsedSeconds), date: Date())
            fetchBooks()
        }
        elapsedSeconds = 0
    }

    /// 現在の経過秒を壁時計から再計算する
    private func updateElapsed() {
        guard let startDate = timerStartDate else { return }
        elapsedSeconds = accumulatedSeconds + Int(Date().timeIntervalSince(startDate))
    }

    /// UI 更新用タイマーを起動する
    private func startUIRefreshTimer() {
        timerInstance?.invalidate()
        timerInstance = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateElapsed()
        }
        if let t = timerInstance {
            RunLoop.main.add(t, forMode: .common)
        }
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
