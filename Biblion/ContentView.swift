import SwiftUI

/// アプリのルートビュー（4タブ構成）
struct ContentView: View {

    @EnvironmentObject var homeViewModel: HomeViewModel
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @EnvironmentObject var taskViewModel: TaskViewModel

    var body: some View {
        TabView {
            // ホームタブ
            HomeView()
                .tabItem {
                    Label("tab.home", systemImage: "house.fill")
                }

            // ライブラリタブ
            LibraryView()
                .tabItem {
                    Label("tab.library", systemImage: "books.vertical.fill")
                }

            // タスクタブ
            TaskListView()
                .tabItem {
                    Label("tab.tasks", systemImage: "checklist")
                }
        }
        .accentColor(.indigo)
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
        .environmentObject(HomeViewModel())
        .environmentObject(LibraryViewModel())
        .environmentObject(TaskViewModel())
}
