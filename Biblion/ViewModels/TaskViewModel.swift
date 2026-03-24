import SwiftUI
import Combine

/// タスクリスト画面の ViewModel
final class TaskViewModel: ObservableObject {

    // MARK: - Published プロパティ

    @Published var tasks: [TaskEntity] = []
    @Published var errorMessage: String?
    @Published var showError = false

    // MARK: - プライベートプロパティ

    private var cancellables = Set<AnyCancellable>()
    private let coreData = CoreDataManager.shared

    // MARK: - 初期化

    init() {
        fetchTasks()
        observeContext()
    }

    // MARK: - データ操作

    func fetchTasks() {
        tasks = coreData.fetchTasks()
    }

    func addTask(title: String) {
        let nextOrder = Int32(tasks.count)
        coreData.addTask(title: title, sortOrder: nextOrder)
        fetchTasks()
        updateNotifications()
    }

    func updateTask(_ task: TaskEntity, title: String) {
        task.title = title
        coreData.updateTask(task)
        fetchTasks()
    }

    func deleteTask(_ task: TaskEntity) {
        coreData.deleteTask(task)
        fetchTasks()
        updateNotifications()
    }

    func reorderTasks(from source: IndexSet, to destination: Int) {
        var reordered = tasks
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, task) in reordered.enumerated() {
            task.sortOrder = Int32(index)
        }
        coreData.save()
        fetchTasks()
    }

    // MARK: - 当日の実行記録

    /// 当日のタスク完了状態を切り替える
    func toggleToday(for task: TaskEntity) {
        let currentState = isTodayDone(for: task)
        coreData.setTaskRecord(task: task, date: Date(), isDone: !currentState)
    }

    /// 当日のタスクが完了済みか
    func isTodayDone(for task: TaskEntity) -> Bool {
        coreData.todayRecord(for: task)?.isDone ?? false
    }

    // MARK: - 週次統計

    /// 直近4週分の週次実行率を返す（[(ラベル, 実行率%)] 形式）
    func weeklyStats(for task: TaskEntity) -> [(String, Double)] {
        let records = coreData.fetchTaskRecords(for: task)
        let calendar = Calendar.current
        var result: [(String, Double)] = []

        for weekOffset in (0..<4).reversed() {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: Date()),
                  let weekStartDay = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: weekStart))
            else { continue }

            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStartDay) ?? weekStartDay
            let weekRecords = records.filter { record in
                guard let date = record.date as Date? else { return false }
                return date >= weekStartDay && date < weekEnd
            }

            let doneCount = weekRecords.filter { $0.isDone }.count
            let rate: Double = weekRecords.isEmpty ? 0.0 : Double(doneCount) / Double(weekRecords.count) * 100.0

            let formatter = DateFormatter()
            formatter.dateFormat = "M/d"
            let label = formatter.string(from: weekStartDay)
            result.append((label, rate))
        }
        return result
    }

    /// 今週の実行記録を日単位で返す（月曜始まり、7要素）
    func thisWeekRecords(for task: TaskEntity) -> [(Date, Bool)] {
        let calendar = Calendar.current
        guard let weekStart = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        ) else { return [] }

        let allRecords = coreData.fetchTaskRecords(for: task)
        var result: [(Date, Bool)] = []

        for dayOffset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: weekStart),
                  let nextDay = calendar.date(byAdding: .day, value: 1, to: day)
            else { continue }
            let record = allRecords.first { r in
                guard let date = r.date as Date? else { return false }
                return date >= day && date < nextDay
            }
            result.append((day, record?.isDone ?? false))
        }
        return result
    }

    // MARK: - 通知更新

    private func updateNotifications() {
        NotificationManager.shared.scheduleNotifications(hasTasks: !tasks.isEmpty)
    }

    // MARK: - CoreData 変更監視

    private func observeContext() {
        NotificationCenter.default.publisher(
            for: .NSManagedObjectContextObjectsDidChange,
            object: coreData.context
        )
        .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
        .sink { [weak self] _ in
            self?.fetchTasks()
        }
        .store(in: &cancellables)
    }
}
