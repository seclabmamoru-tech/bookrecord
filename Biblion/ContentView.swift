import SwiftUI

/// アプリのルートビュー（4タブ構成）
struct ContentView: View {

    @EnvironmentObject var homeViewModel: HomeViewModel
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @EnvironmentObject var taskViewModel: TaskViewModel
    @EnvironmentObject var aiInsightViewModel: AIInsightViewModel

    @State private var showSettings = false

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

            // AI相談タブ（設定ボタン付き）
            NavigationStack {
                AIInsightView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                showSettings = true
                            } label: {
                                Image(systemName: "gearshape.fill")
                            }
                        }
                    }
            }
            .tabItem {
                Label("tab.ai", systemImage: "brain.head.profile")
            }
        }
        .accentColor(.indigo)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(aiInsightViewModel)
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
        .environmentObject(HomeViewModel())
        .environmentObject(LibraryViewModel())
        .environmentObject(TaskViewModel())
        .environmentObject(AIInsightViewModel())
}
