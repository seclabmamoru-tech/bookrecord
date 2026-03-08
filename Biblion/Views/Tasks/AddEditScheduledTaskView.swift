import SwiftUI

/// スケジュールタスクの追加・編集フォーム
struct AddEditScheduledTaskView: View {

    @ObservedObject var viewModel: SchedulerViewModel
    var editingTask: ScheduledTask? = nil

    @Environment(\.dismiss) private var dismiss

    // フォーム状態
    @State private var selectedTaskTitle: String = ""
    @State private var startTime: Date = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var endTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var frequency: ScheduleFrequency = .weekly
    @State private var selectedWeekdays: Set<Int> = [2, 3, 4, 5, 6] // 月〜金

    private var existingTaskTitles: [String] {
        CoreDataManager.shared.fetchTasks().compactMap { $0.title }.filter { !$0.isEmpty }
    }

    private var isEditing: Bool { editingTask != nil }

    private var canSave: Bool {
        !selectedTaskTitle.isEmpty && (frequency == .daily || !selectedWeekdays.isEmpty)
    }

    var body: some View {
        NavigationStack {
            Form {
                // タスク名
                Section {
                    if existingTaskTitles.isEmpty {
                        Text("scheduler.noTasksAvailable")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    } else {
                        Picker("scheduler.taskName", selection: $selectedTaskTitle) {
                            ForEach(existingTaskTitles, id: \.self) { title in
                                Text(title).tag(title)
                            }
                        }
                    }
                } header: {
                    Text("scheduler.taskName")
                }

                // 時刻
                Section {
                    DatePicker(
                        "scheduler.startTime",
                        selection: $startTime,
                        displayedComponents: .hourAndMinute
                    )
                    DatePicker(
                        "scheduler.endTime",
                        selection: $endTime,
                        displayedComponents: .hourAndMinute
                    )
                } header: {
                    Text("scheduler.time")
                }

                // 周期
                Section {
                    Picker("scheduler.frequency", selection: $frequency) {
                        ForEach(ScheduleFrequency.allCases, id: \.self) { f in
                            Text(f.displayName).tag(f)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("scheduler.frequency")
                }

                // 曜日（毎日以外）
                if frequency != .daily {
                    Section {
                        WeekdaySelectorView(selectedWeekdays: $selectedWeekdays)
                    } header: {
                        Text("scheduler.weekdays")
                    } footer: {
                        if selectedWeekdays.isEmpty {
                            Text("scheduler.weekdaysRequired")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle(Text(isEditing ? "scheduler.editTitle" : "scheduler.addTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.save") { save() }
                        .disabled(!canSave)
                        .bold()
                }
            }
            .onAppear { loadEditingTask() }
        }
    }

    // MARK: - 読み込み

    private func loadEditingTask() {
        if let task = editingTask {
            selectedTaskTitle = task.taskTitle ?? ""
            let cal = Calendar.current
            var startComp = DateComponents()
            startComp.hour = Int(task.startHour)
            startComp.minute = Int(task.startMinute)
            startTime = cal.date(from: startComp) ?? startTime

            var endComp = DateComponents()
            endComp.hour = Int(task.endHour)
            endComp.minute = Int(task.endMinute)
            endTime = cal.date(from: endComp) ?? endTime

            frequency = ScheduleFrequency(rawValue: task.frequency ?? "weekly") ?? .weekly
            selectedWeekdays = Set(SchedulerViewModel.parseWeekdays(task.weekdays ?? ""))
        } else {
            // 新規: 既存タスクの先頭をデフォルト選択
            selectedTaskTitle = existingTaskTitles.first ?? ""
        }
    }

    // MARK: - 保存

    private func save() {
        let cal = Calendar.current
        let startH = cal.component(.hour, from: startTime)
        let startM = cal.component(.minute, from: startTime)
        let endH = cal.component(.hour, from: endTime)
        let endM = cal.component(.minute, from: endTime)
        let weekdays = Array(selectedWeekdays).sorted()

        if let task = editingTask {
            viewModel.updateScheduledTask(
                task,
                taskTitle: selectedTaskTitle,
                startHour: startH, startMinute: startM,
                endHour: endH, endMinute: endM,
                frequency: frequency,
                weekdays: weekdays
            )
        } else {
            viewModel.addScheduledTask(
                taskTitle: selectedTaskTitle,
                startHour: startH, startMinute: startM,
                endHour: endH, endMinute: endM,
                frequency: frequency,
                weekdays: weekdays
            )
        }
        dismiss()
    }
}

// MARK: - 曜日選択コンポーネント

private struct WeekdaySelectorView: View {

    @Binding var selectedWeekdays: Set<Int>

    // Calendar.weekday: 1=日,2=月,...,7=土 で月〜日の順に表示
    private let weekdays: [(Int, String)] = [
        (2, "月"), (3, "火"), (4, "水"), (5, "木"), (6, "金"), (7, "土"), (1, "日")
    ]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(weekdays, id: \.0) { (value, name) in
                Button {
                    if selectedWeekdays.contains(value) {
                        selectedWeekdays.remove(value)
                    } else {
                        selectedWeekdays.insert(value)
                    }
                } label: {
                    Text(name)
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 36, height: 36)
                        .background(selectedWeekdays.contains(value) ? Color.blue : Color(.systemGray5))
                        .foregroundColor(selectedWeekdays.contains(value) ? .white : .primary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}
