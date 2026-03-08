import SwiftUI
import Combine

// MARK: - 周期

enum ScheduleFrequency: String, CaseIterable {
    case daily = "daily"
    case weekly = "weekly"
    case biweekly = "biweekly"

    var displayName: String {
        switch self {
        case .daily:    return NSLocalizedString("scheduler.frequency.daily", comment: "")
        case .weekly:   return NSLocalizedString("scheduler.frequency.weekly", comment: "")
        case .biweekly: return NSLocalizedString("scheduler.frequency.biweekly", comment: "")
        }
    }
}

// MARK: - ViewModel

final class SchedulerViewModel: ObservableObject {

    @Published var scheduledTasks: [ScheduledTask] = []

    private let coreData = CoreDataManager.shared

    init() {
        fetchScheduledTasks()
    }

    // MARK: - データ操作

    func fetchScheduledTasks() {
        scheduledTasks = coreData.fetchScheduledTasks()
    }

    func addScheduledTask(
        taskTitle: String,
        startHour: Int, startMinute: Int,
        endHour: Int, endMinute: Int,
        frequency: ScheduleFrequency,
        weekdays: [Int]
    ) {
        coreData.addScheduledTask(
            taskTitle: taskTitle,
            startHour: Int16(startHour),
            startMinute: Int16(startMinute),
            endHour: Int16(endHour),
            endMinute: Int16(endMinute),
            frequency: frequency.rawValue,
            weekdays: weekdays.map { String($0) }.joined(separator: ","),
            referenceDate: Date()
        )
        fetchScheduledTasks()
        scheduleNotifications()
    }

    func updateScheduledTask(
        _ task: ScheduledTask,
        taskTitle: String,
        startHour: Int, startMinute: Int,
        endHour: Int, endMinute: Int,
        frequency: ScheduleFrequency,
        weekdays: [Int]
    ) {
        task.taskTitle = taskTitle
        task.startHour = Int16(startHour)
        task.startMinute = Int16(startMinute)
        task.endHour = Int16(endHour)
        task.endMinute = Int16(endMinute)
        task.frequency = frequency.rawValue
        task.weekdays = weekdays.map { String($0) }.joined(separator: ",")
        coreData.updateScheduledTask(task)
        fetchScheduledTasks()
        scheduleNotifications()
    }

    func deleteScheduledTask(_ task: ScheduledTask) {
        coreData.deleteScheduledTask(task)
        fetchScheduledTasks()
        scheduleNotifications()
    }

    // MARK: - 週のカレンダー

    /// 指定 offset の週（月曜始まり）の7日間を返す
    func weekDates(offset: Int = 0) -> [Date] {
        let calendar = Calendar.current
        guard let weekStart = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        ),
        let targetStart = calendar.date(byAdding: .weekOfYear, value: offset, to: weekStart)
        else { return [] }

        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: targetStart) }
    }

    /// 指定日に対応するスケジュール済みタスクを返す（開始時刻でソート）
    func scheduledTasks(for date: Date) -> [ScheduledTask] {
        scheduledTasks
            .filter { isOccurring($0, on: date) }
            .sorted { ($0.startHour * 60 + $0.startMinute) < ($1.startHour * 60 + $1.startMinute) }
    }

    // MARK: - 出現判定

    private func isOccurring(_ task: ScheduledTask, on date: Date) -> Bool {
        guard let freq = task.frequency else { return false }
        switch freq {
        case ScheduleFrequency.daily.rawValue:
            return true
        case ScheduleFrequency.weekly.rawValue:
            return weekdayMatches(task, on: date)
        case ScheduleFrequency.biweekly.rawValue:
            guard weekdayMatches(task, on: date) else { return false }
            return isBiweeklyOccurrence(task, on: date)
        default:
            return false
        }
    }

    private func weekdayMatches(_ task: ScheduledTask, on date: Date) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        let weekdays = parseWeekdays(task.weekdays ?? "")
        return weekdays.contains(weekday)
    }

    private func isBiweeklyOccurrence(_ task: ScheduledTask, on date: Date) -> Bool {
        let calendar = Calendar.current
        let refDate = task.referenceDate ?? task.createdAt ?? Date()
        guard
            let refWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: refDate)),
            let thisWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))
        else { return true }
        let weeksDiff = calendar.dateComponents([.weekOfYear], from: refWeekStart, to: thisWeekStart).weekOfYear ?? 0
        return weeksDiff % 2 == 0
    }

    // MARK: - ヘルパー

    static func parseWeekdays(_ str: String) -> [Int] {
        str.split(separator: ",").compactMap { Int($0) }
    }

    private func parseWeekdays(_ str: String) -> [Int] {
        SchedulerViewModel.parseWeekdays(str)
    }

    func timeRangeText(for task: ScheduledTask) -> String {
        String(format: "%02d:%02d〜%02d:%02d",
               task.startHour, task.startMinute,
               task.endHour, task.endMinute)
    }

    func frequencyText(for task: ScheduledTask) -> String {
        let freq = ScheduleFrequency(rawValue: task.frequency ?? "weekly") ?? .weekly
        guard freq != .daily else { return freq.displayName }

        let weekdays = parseWeekdays(task.weekdays ?? "")
        let dayNames = weekdays
            .sorted()
            .compactMap { weekdayShortName($0) }
            .joined(separator: "・")

        return "\(freq.displayName) [\(dayNames)]"
    }

    // Calendar.weekday: 1=日,2=月,...,7=土
    func weekdayShortName(_ weekday: Int) -> String? {
        let names = [1: "日", 2: "月", 3: "火", 4: "水", 5: "木", 6: "金", 7: "土"]
        return names[weekday]
    }

    // MARK: - 通知

    private func scheduleNotifications() {
        NotificationManager.shared.scheduleScheduledTaskNotifications(tasks: scheduledTasks)
    }
}
