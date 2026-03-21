import SwiftUI
import Combine
import UserNotifications

/// 読書リマインダー通知設定 ViewModel
@MainActor
final class NotificationSettingsViewModel: ObservableObject {

    // MARK: - UserDefaults キー

    private enum Keys {
        static let isEnabled   = "readingReminder.isEnabled"
        static let weekdays    = "readingReminder.weekdays"
        static let hour        = "readingReminder.hour"
        static let minute      = "readingReminder.minute"
        static let morningMemoEnabled = "morningMemo.isEnabled"
        static let morningMemoHour    = "morningMemo.hour"
        static let morningMemoMinute  = "morningMemo.minute"
    }

    // MARK: - Published プロパティ

    /// 通知の有効/無効
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Keys.isEnabled)
            applySettings()
        }
    }

    /// 選択された曜日（Calendar.weekday 準拠: 1=日, 2=月, ..., 7=土）
    @Published var selectedWeekdays: Set<Int> {
        didSet {
            UserDefaults.standard.set(Array(selectedWeekdays), forKey: Keys.weekdays)
            applySettings()
        }
    }

    /// 通知時刻
    @Published var notificationTime: Date {
        didSet {
            let cal = Calendar.current
            UserDefaults.standard.set(cal.component(.hour, from: notificationTime), forKey: Keys.hour)
            UserDefaults.standard.set(cal.component(.minute, from: notificationTime), forKey: Keys.minute)
            applySettings()
        }
    }

    /// 朝のメモ通知の有効/無効
    @Published var morningMemoEnabled: Bool {
        didSet {
            UserDefaults.standard.set(morningMemoEnabled, forKey: Keys.morningMemoEnabled)
            if !morningMemoEnabled {
                NotificationManager.shared.removeMorningMemoNotification()
            }
        }
    }

    /// 朝のメモ通知時刻
    @Published var morningMemoTime: Date {
        didSet {
            let cal = Calendar.current
            UserDefaults.standard.set(cal.component(.hour, from: morningMemoTime), forKey: Keys.morningMemoHour)
            UserDefaults.standard.set(cal.component(.minute, from: morningMemoTime), forKey: Keys.morningMemoMinute)
        }
    }

    /// 通知許可ステータス
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    // MARK: - 初期化

    init() {
        let defaults = UserDefaults.standard
        isEnabled        = defaults.bool(forKey: Keys.isEnabled)
        selectedWeekdays = Set(defaults.array(forKey: Keys.weekdays) as? [Int] ?? [])

        let hour   = defaults.object(forKey: Keys.hour)   != nil ? defaults.integer(forKey: Keys.hour)   : 8
        let minute = defaults.object(forKey: Keys.minute) != nil ? defaults.integer(forKey: Keys.minute) : 0
        notificationTime = NotificationSettingsViewModel.makeTime(hour: hour, minute: minute)

        morningMemoEnabled = defaults.bool(forKey: Keys.morningMemoEnabled)
        let mHour   = defaults.object(forKey: Keys.morningMemoHour)   != nil ? defaults.integer(forKey: Keys.morningMemoHour)   : 8
        let mMinute = defaults.object(forKey: Keys.morningMemoMinute) != nil ? defaults.integer(forKey: Keys.morningMemoMinute) : 0
        morningMemoTime = NotificationSettingsViewModel.makeTime(hour: mHour, minute: mMinute)

        Task { await refreshAuthorizationStatus() }
    }

    // MARK: - 公開メソッド

    /// 通知許可ステータスを更新する
    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    /// 通知許可をリクエストしてから設定を適用する
    func requestAuthorizationAndApply() {
        NotificationManager.shared.requestAuthorization()
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            await refreshAuthorizationStatus()
            applySettings()
        }
    }

    /// 朝のメモ通知の時刻設定を取得する（hour, minute）
    var morningMemoHourAndMinute: (hour: Int, minute: Int) {
        let cal = Calendar.current
        return (
            cal.component(.hour, from: morningMemoTime),
            cal.component(.minute, from: morningMemoTime)
        )
    }

    /// 曜日の選択状態をトグルする
    func toggleWeekday(_ weekday: Int) {
        if selectedWeekdays.contains(weekday) {
            selectedWeekdays.remove(weekday)
        } else {
            selectedWeekdays.insert(weekday)
        }
    }

    // MARK: - プライベートメソッド

    /// 設定に応じて通知を登録/削除する
    private func applySettings() {
        guard isEnabled, !selectedWeekdays.isEmpty else {
            NotificationManager.shared.removeReadingReminders()
            return
        }
        let cal = Calendar.current
        let hour   = cal.component(.hour,   from: notificationTime)
        let minute = cal.component(.minute, from: notificationTime)
        NotificationManager.shared.scheduleReadingReminders(
            weekdays: Array(selectedWeekdays),
            hour: hour,
            minute: minute
        )
    }

    /// 指定した時刻の Date を生成する（日付部分は今日）
    private static func makeTime(hour: Int, minute: Int) -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour   = hour
        comps.minute = minute
        comps.second = 0
        return Calendar.current.date(from: comps) ?? Date()
    }
}
