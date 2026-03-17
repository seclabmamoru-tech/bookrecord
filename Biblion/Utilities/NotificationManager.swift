import Foundation
import UserNotifications

/// ローカル通知を管理するシングルトンクラス
final class NotificationManager {

    static let shared = NotificationManager()

    /// 読書リマインダー通知の識別子プレフィックス
    private let readingReminderPrefix = "biblion_reading_weekday_"

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
        // タスク通知の識別子のみ削除して再登録
        let taskIdentifiers = ["biblion_noon", "biblion_evening"]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: taskIdentifiers)

        // タスクがない場合はスケジュールしない
        guard hasTasks else { return }

        // 12:00 の通知
        scheduleDaily(hour: 12, minute: 0, identifier: "biblion_noon")
        // 22:00 の通知
        scheduleDaily(hour: 22, minute: 0, identifier: "biblion_evening")
    }

    // MARK: - 読書リマインダー

    /// 読書リマインダー通知をスケジュールする
    /// - Parameters:
    ///   - weekdays: 通知する曜日の配列（1=日, 2=月, ..., 7=土 / Calendar.weekday 準拠）
    ///   - hour: 通知時刻（時）
    ///   - minute: 通知時刻（分）
    func scheduleReadingReminders(weekdays: [Int], hour: Int, minute: Int) {
        // 既存の読書リマインダー通知をすべて削除
        removeReadingReminders()

        for weekday in weekdays {
            let identifier = "\(readingReminderPrefix)\(weekday)"
            scheduleWeekly(weekday: weekday, hour: hour, minute: minute, identifier: identifier)
        }
    }

    /// 読書リマインダー通知をすべて削除する
    func removeReadingReminders() {
        let identifiers = (1...7).map { "\(readingReminderPrefix)\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
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

    /// 毎週指定曜日・時刻にローカル通知を登録する
    private func scheduleWeekly(weekday: Int, hour: Int, minute: Int, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = "Biblion"
        content.body = NSString.localizedUserNotificationString(forKey: "notification.reading.body", arguments: nil)
        content.sound = .default
        content.badge = 1

        var dateComponents = DateComponents()
        dateComponents.weekday = weekday
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
