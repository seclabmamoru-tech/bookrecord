import SwiftUI

/// タスク追加・編集画面
struct AddEditTaskView: View {

    @EnvironmentObject var viewModel: TaskViewModel
    @Environment(\.dismiss) private var dismiss

    // 編集対象のタスク（nil の場合は新規追加）
    var task: TaskEntity?

    @State private var taskTitle = ""

    private var isEditing: Bool { task != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(LocalizedStringKey("task.add"), text: $taskTitle)
                        .submitLabel(.done)
                        .onSubmit { saveTask() }
                }
            }
            .navigationTitle(isEditing ? Text("common.edit") : Text("task.add"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("memo.save") { saveTask() }
                        .bold()
                        .disabled(taskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .onAppear {
            if let task = task {
                taskTitle = task.title ?? ""
            }
        }
    }

    // MARK: - 保存

    private func saveTask() {
        let trimmed = taskTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        if let task = task {
            viewModel.updateTask(task, title: trimmed)
        } else {
            viewModel.addTask(title: trimmed)
        }
        dismiss()
    }
}

#Preview {
    AddEditTaskView()
        .environmentObject(TaskViewModel())
}
