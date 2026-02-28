import SwiftUI

/// アプリのルートビュー（4タブ構成）
struct ContentView: View {

    @EnvironmentObject var homeViewModel: HomeViewModel
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @EnvironmentObject var taskViewModel: TaskViewModel
    @EnvironmentObject var aiInsightViewModel: AIInsightViewModel

    @State private var showSettings = false
    @State private var selectedTab = 0
    @State private var lastValidTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // ホームタブ
            HomeView()
                .tabItem {
                    Label("tab.home", systemImage: "house.fill")
                }
                .tag(0)

            // ライブラリタブ
            LibraryView()
                .tabItem {
                    Label("tab.library", systemImage: "books.vertical.fill")
                }
                .tag(1)

            // タスクタブ
            TaskListView()
                .tabItem {
                    Label("tab.tasks", systemImage: "checklist")
                }
                .tag(2)

            // AI相談タブ（Coming Soon・タップ無効）
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
                Label("ai.comingSoon", systemImage: "brain.head.profile")
            }
            .tag(3)
        }
        .accentColor(.indigo)
        .onChange(of: selectedTab) { newTab in
            if newTab == 3 {
                selectedTab = lastValidTab
            } else {
                lastValidTab = newTab
            }
        }
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
