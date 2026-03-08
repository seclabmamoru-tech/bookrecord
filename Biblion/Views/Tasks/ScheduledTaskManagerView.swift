import SwiftUI

/// スケジュール済みタスクの管理画面
struct ScheduledTaskManagerView: View {

    @ObservedObject var viewModel: SchedulerViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var editingTask: ScheduledTask?
    @State private var showAddTask = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.scheduledTasks.isEmpty {
                    emptyState
                } else {
                    taskList
                }
            }
            .navigationTitle(Text("scheduler.manageTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text("common.close")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddTask = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddTask, onDismiss: {
                viewModel.fetchScheduledTasks()
            }) {
                AddEditScheduledTaskView(viewModel: viewModel)
            }
            .sheet(item: $editingTask, onDismiss: {
                viewModel.fetchScheduledTasks()
            }) { task in
                AddEditScheduledTaskView(viewModel: viewModel, editingTask: task)
            }
        }
    }

    // MARK: - タスクリスト

    private var taskList: some View {
        List {
            ForEach(viewModel.scheduledTasks, id: \.id) { task in
                Button {
                    editingTask = task
                } label: {
                    ScheduledTaskRow(task: task, viewModel: viewModel)
                }
                .buttonStyle(.plain)
            }
            .onDelete { indexSet in
                indexSet.forEach { i in
                    viewModel.deleteScheduledTask(viewModel.scheduledTasks[i])
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - 空状態

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("scheduler.noSchedules")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button {
                showAddTask = true
            } label: {
                Text("scheduler.addSchedule")
                    .font(.subheadline.bold())
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - スケジュールタスク行

private struct ScheduledTaskRow: View {
    let task: ScheduledTask
    let viewModel: SchedulerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(task.taskTitle ?? "")
                .font(.body)
                .foregroundColor(.primary)

            HStack(spacing: 8) {
                Label(viewModel.timeRangeText(for: task), systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("·")
                    .foregroundColor(.secondary)

                Text(viewModel.frequencyText(for: task))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
