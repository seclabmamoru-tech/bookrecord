import SwiftUI

/// スケジューラー画面 - 1週間のカレンダー表示
struct TaskSchedulerView: View {

    @StateObject private var viewModel = SchedulerViewModel()
    @State private var weekOffset = 0
    @State private var showManager = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                weekNavigationBar
                Divider()
                calendarGrid
            }
            .navigationTitle(Text("scheduler.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showManager = true
                    } label: {
                        Text("scheduler.manage")
                            .font(.subheadline)
                    }
                }
            }
            .sheet(isPresented: $showManager, onDismiss: {
                viewModel.fetchScheduledTasks()
            }) {
                ScheduledTaskManagerView(viewModel: viewModel)
            }
        }
    }

    // MARK: - 週ナビゲーションバー

    private var weekNavigationBar: some View {
        HStack {
            Button {
                weekOffset -= 1
            } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline.bold())
                    .frame(width: 44, height: 44)
            }

            Spacer()

            Text(weekRangeText)
                .font(.subheadline.bold())

            Spacer()

            Button {
                weekOffset += 1
            } label: {
                Image(systemName: "chevron.right")
                    .font(.subheadline.bold())
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 8)
        .background(Color(.systemBackground))
    }

    // MARK: - カレンダーグリッド

    private var calendarGrid: some View {
        let dates = viewModel.weekDates(offset: weekOffset)
        return ScrollView(.vertical, showsIndicators: false) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(dates, id: \.self) { date in
                    DayColumnView(
                        date: date,
                        tasks: viewModel.scheduledTasks(for: date),
                        isToday: Calendar.current.isDateInToday(date)
                    )
                }
            }
        }
    }

    // MARK: - 週範囲テキスト

    private var weekRangeText: String {
        let dates = viewModel.weekDates(offset: weekOffset)
        guard let first = dates.first, let last = dates.last else { return "" }
        let fmt = DateFormatter()
        fmt.dateFormat = "M/d"
        if weekOffset == 0 {
            return NSLocalizedString("scheduler.thisWeek", comment: "")
                + "  \(fmt.string(from: first))〜\(fmt.string(from: last))"
        }
        return "\(fmt.string(from: first)) 〜 \(fmt.string(from: last))"
    }
}

// MARK: - 日付カラム

private struct DayColumnView: View {
    let date: Date
    let tasks: [ScheduledTask]
    let isToday: Bool

    private var dayName: String {
        let names = [1: "日", 2: "月", 3: "火", 4: "水", 5: "木", 6: "金", 7: "土"]
        let weekday = Calendar.current.component(.weekday, from: date)
        return names[weekday] ?? ""
    }

    private var dayNumber: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "d"
        return fmt.string(from: date)
    }

    private var headerForeground: Color {
        if isToday { return .white }
        let weekday = Calendar.current.component(.weekday, from: date)
        if weekday == 1 { return .red }
        if weekday == 7 { return .blue }
        return .primary
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── ヘッダー ──
            VStack(spacing: 2) {
                Text(dayName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isToday ? .white : .secondary)

                ZStack {
                    if isToday {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 26, height: 26)
                    }
                    Text(dayNumber)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(headerForeground)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(isToday ? Color.blue.opacity(0.1) : Color(.systemGroupedBackground))

            Divider()

            // ── タスクチップ ──
            VStack(spacing: 4) {
                ForEach(tasks, id: \.id) { task in
                    VStack(spacing: 1) {
                        Text(task.taskTitle ?? "")
                            .font(.system(size: 9, weight: .medium))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(String(format: "%02d:%02d", task.startHour, task.startMinute))
                            .font(.system(size: 8))
                            .foregroundColor(.blue.opacity(0.8))
                    }
                    .padding(.horizontal, 3)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.12))
                    .foregroundColor(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                }

                if tasks.isEmpty {
                    Color.clear.frame(height: 20)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 2)
            .padding(.top, 6)
            .padding(.bottom, 4)
        }
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .top)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .fill(Color(.separator).opacity(0.4))
                .frame(width: 0.5),
            alignment: .trailing
        )
    }
}
