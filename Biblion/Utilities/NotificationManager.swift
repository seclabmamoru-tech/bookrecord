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

    // MARK: - プライベートメソッド

    /// 毎日指定時刻にローカル通知を登録する
    private func scheduleDaily(hour: Int, minute: Int, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = "Biblion"
        content.body = NSLocalizedString("notification.body", comment: "タスク確認通知本文")
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
