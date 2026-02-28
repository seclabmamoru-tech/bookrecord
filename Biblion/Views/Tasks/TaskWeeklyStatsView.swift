import SwiftUI
import Charts

/// タスク週次統計画面（棒グラフ＋今週のカレンダー）
struct TaskWeeklyStatsView: View {

    @EnvironmentObject var viewModel: TaskViewModel

    let task: TaskEntity

    var weeklyStats: [(String, Double)] {
        viewModel.weeklyStats(for: task)
    }

    var thisWeekRecords: [(Date, Bool)] {
        viewModel.thisWeekRecords(for: task)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 4週間の実行率棒グラフ
                weeklyChartSection

                // 今週の実行カレンダー
                weeklyCalendarSection
            }
            .padding()
        }
        .navigationTitle(task.title ?? "")
        .navigationBarTitleDisplayMode(.large)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - 週次実行率グラフ

    private var weeklyChartSection: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                Label("task.weeklyStats", systemImage: "chart.bar.fill")
                    .font(.headline)

                Chart {
                    ForEach(weeklyStats, id: \.0) { item in
                        BarMark(
                            x: .value("Week", item.0),
                            y: .value("Rate", item.1)
                        )
                        .foregroundStyle(Color.indigo)
                        .cornerRadius(4)
                        .annotation(position: .top) {
                            Text("\(Int(item.1))%")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(height: 180)
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                        AxisValueLabel {
                            if let v = value.as(Int.self) {
                                Text("\(v)%").font(.caption2)
                            }
                        }
                        AxisGridLine()
                    }
                }
            }
        }
    }

    // MARK: - 今週のカレンダー

    private var weeklyCalendarSection: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                Label("task.thisWeek", systemImage: "calendar")
                    .font(.headline)

                HStack(spacing: 6) {
                    ForEach(thisWeekRecords, id: \.0) { record in
                        DayCell(date: record.0, isDone: record.1)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - 日付セル

private struct DayCell: View {
    let date: Date
    let isDone: Bool

    private var dayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }

    private var dateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(dayLabel)
                .font(.caption2)
                .foregroundColor(.secondary)

            ZStack {
                Circle()
                    .fill(isDone ? Color.indigo : Color(.systemGray5))
                    .frame(width: 36, height: 36)

                if isToday && !isDone {
                    Circle()
                        .strokeBorder(Color.indigo, lineWidth: 2)
                        .frame(width: 36, height: 36)
                }

                Text(dateLabel)
                    .font(.caption.bold())
                    .foregroundColor(isDone ? .white : .primary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationStack {
        TaskWeeklyStatsView(task: TaskEntity())
            .environmentObject(TaskViewModel())
    }
}
