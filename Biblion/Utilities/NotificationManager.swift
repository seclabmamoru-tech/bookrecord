import Foundation
import UserNotifications

/// ローカル通知を管理するシングルトンクラス
final class NotificationManager {

    static let shared = NotificationManager()

    private init() {}

    // MARK: - 通知許可申請

    /// アプリ初回起動時に通知許可を申請する
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("通知許可の申請に失敗しました: \(error.localizedDescription)")
            }
            if granted {
                print("通知が許可されました")
            }
        }
    }

    // MARK: - 通知スケジュール

    /// タスクの有無に応じて通知をスケジュールする
    /// - Parameter hasTasks: タスクが存在するか
    func scheduleNotifications(hasTasks: Bool) {
        // 既存の通知をすべて削除
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        // タスクがない場合はスケジュールしない
        guard hasTasks else { return }

        // 12:00 の通知
        scheduleDaily(hour: 12, minute: 0, identifier: "biblion_noon")
        // 22:00 の通知
        scheduleDaily(hour: 22, minute: 0, identifier: "biblion_evening")
    }

    // MARK: - スケジュールタスク通知

    /// スケジュールタスクの通知を登録する（既存のスケジュール通知を置き換える）
    func scheduleScheduledTaskNotifications(tasks: [ScheduledTask]) {
        // 既存のスケジュールタスク通知を削除
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let scheduledIDs = requests
                .map { $0.identifier }
                .filter { $0.hasPrefix("scheduled_task_") }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: scheduledIDs)

            for task in tasks {
                self.registerNotifications(for: task)
            }
        }
    }

    private func registerNotifications(for task: ScheduledTask) {
        guard let id = task.id,
              let title = task.taskTitle, !title.isEmpty,
              let freq = task.frequency
        else { return }

        let hour = Int(task.startHour)
        let minute = Int(task.startMinute)
        let baseID = "scheduled_task_\(id.uuidString)"

        switch freq {
        case ScheduleFrequency.daily.rawValue:
            scheduleWeeklyRepeating(
                identifier: "\(baseID)_daily",
                title: title,
                hour: hour,
                minute: minute,
                weekday: nil
            )

        case ScheduleFrequency.weekly.rawValue:
            let weekdays = SchedulerViewModel.parseWeekdays(task.weekdays ?? "")
            for weekday in weekdays {
                scheduleWeeklyRepeating(
                    identifier: "\(baseID)_wd\(weekday)",
                    title: title,
                    hour: hour,
                    minute: minute,
                    weekday: weekday
                )
            }

        case ScheduleFrequency.biweekly.rawValue:
            // 隔週: 今後14日間の対象日に個別登録
            let weekdays = SchedulerViewModel.parseWeekdays(task.weekdays ?? "")
            let refDate = task.referenceDate ?? task.createdAt ?? Date()
            let calendar = Calendar.current
            let now = Date()
            for dayOffset in 0..<14 {
                guard let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
                let wd = calendar.component(.weekday, from: targetDate)
                guard weekdays.contains(wd) else { continue }
                guard let refWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: refDate)),
                      let thisWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: targetDate))
                else { continue }
                let weeksDiff = calendar.dateComponents([.weekOfYear], from: refWeekStart, to: thisWeekStart).weekOfYear ?? 0
                guard weeksDiff % 2 == 0 else { continue }

                var components = calendar.dateComponents([.year, .month, .day], from: targetDate)
                components.hour = hour
                components.minute = minute
                let fireDate = calendar.date(from: components) ?? targetDate
                guard fireDate > now else { continue }

                scheduleDateSpecific(
                    identifier: "\(baseID)_bw_\(dayOffset)",
                    title: title,
                    fireDate: fireDate
                )
            }

        default:
            break
        }
    }

    /// 毎週（または毎日）繰り返し通知を登録する
    private func scheduleWeeklyRepeating(identifier: String, title: String, hour: Int, minute: Int, weekday: Int?) {
        let content = UNMutableNotificationContent()
        content.title = "Biblion"
        content.body = title
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        if let wd = weekday {
            dateComponents.weekday = wd
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("スケジュール通知の登録に失敗しました(\(identifier)): \(error.localizedDescription)")
            }
        }
    }

    /// 特定日時の通知を1回だけ登録する（隔週用）
    private func scheduleDateSpecific(identifier: String, title: String, fireDate: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Biblion"
        content.body = title
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("日時指定通知の登録に失敗しました(\(identifier)): \(error.localizedDescription)")
            }
        }
    }

    // MARK: - プライベートメソッド

    /// 毎日指定時刻にローカル通知を登録する
    private func scheduleDaily(hour: Int, minute: Int, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = "Biblion"
        content.body = NSString.localizedUserNotificationString(forKey: "notification.body", arguments: nil)
        content.sound = .default
        content.badge = 1

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("通知のスケジュールに失敗しました（\(identifier)）: \(error.localizedDescription)")
            }
        }
    }
}
