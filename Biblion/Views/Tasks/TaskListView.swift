import SwiftUI

/// タスクリスト画面（プランに応じた上限制御）
struct TaskListView: View {

    @EnvironmentObject var viewModel: TaskViewModel
    @State private var showAddTask = false
    @State private var editingTask: TaskEntity?

    private var currentPlan: PlanType {
        let plan = CoreDataManager.shared.fetchOrCreateUserPlan()
        return PlanType(rawValue: plan.planType ?? "free") ?? .free
    }

    /// プランに応じたタスク追加可否（Freeは最大4件、Basic/Premiumは無制限）
    private var canAddTaskByPlan: Bool {
        if let limit = PlanLimits.taskLimit(for: currentPlan) {
            return viewModel.tasks.count < limit
        }
        return true
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 説明文
                Text("task.description")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 4)

                // 操作ヒント
                HStack {
                    Text("task.hint.edit")
                    Spacer()
                    Text("task.hint.manage")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.systemGroupedBackground))

                // タスクリスト
                List {
                    ForEach(viewModel.tasks, id: \.id) { task in
                        TaskRow(task: task, viewModel: viewModel)
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    editingTask = task
                                } label: {
                                    Label("common.edit", systemImage: "pencil")
                                }
                                .tint(.indigo)
                            }
                    }
                    .onMove { source, destination in
                        viewModel.reorderTasks(from: source, to: destination)
                    }
                    .onDelete { indexSet in
                        indexSet.forEach { index in
                            viewModel.deleteTask(viewModel.tasks[index])
                        }
                    }
                }
                .listStyle(.insetGrouped)

                // バナー広告
                BannerAdView()
                    .frame(height: 50)
            }
            .navigationTitle(Text("task.title"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    // プランに応じた上限チェック
                    if canAddTaskByPlan {
                        Button {
                            showAddTask = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddTask) {
                AddEditTaskView()
                    .environmentObject(viewModel)
            }
            .sheet(item: $editingTask) { task in
                AddEditTaskView(task: task)
                    .environmentObject(viewModel)
            }
        }
        .onAppear {
            viewModel.fetchTasks()
        }
    }
}

// MARK: - タスク行

private struct TaskRow: View {
    let task: TaskEntity
    @ObservedObject var viewModel: TaskViewModel
    @State private var showStats = false

    private var isDone: Bool {
        viewModel.isTodayDone(for: task)
    }

    var body: some View {
        HStack(spacing: 12) {
            // タスクタイトル（タップで週次統計へ遷移）
            NavigationLink(destination: TaskWeeklyStatsView(task: task).environmentObject(viewModel)) {
                Text(task.title ?? "")
                    .font(.body)
            }

            Spacer()

            // 当日の実行記録ボタン
            Button {
                viewModel.toggleToday(for: task)
            } label: {
                Text(isDone ? "task.done" : "task.notDone")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(isDone ? Color.green.opacity(0.15) : Color(.systemGray5))
                    .foregroundColor(isDone ? .green : .secondary)
                    .clipShape(Capsule())
                    .animation(.easeInOut(duration: 0.2), value: isDone)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    TaskListView()
        .environmentObject(TaskViewModel())
}
