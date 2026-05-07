import SwiftUI

/// AIメニュー選択画面（✨ AI タブのメイン）
struct AIMenuView: View {

    @StateObject private var viewModel = AIViewModel()
    @State private var selectedMenu: AIMenuType?
    @State private var showConsent = false
    @State private var showPurchasePrompt = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 16) {
                        // チケット残数バー
                        ticketHeader

                        // メニューカード
                        menuCards

                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }

                // バナー広告
                BannerAdView()
                    .frame(height: 50)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(Text("ai.menu.title"))
            .onAppear { viewModel.refreshFromCoreData() }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: AIHistoryView()) {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                }
            }
            .sheet(isPresented: $showConsent) {
                AIConsentMenuView(viewModel: viewModel)
            }
            .alert("ai.menu.noTicketTitle", isPresented: $showPurchasePrompt) {
                Button("common.cancel", role: .cancel) {}
            } message: {
                Text("ai.menu.noTicketMessage")
            }
        }
    }

    // MARK: - チケットヘッダー

    private var ticketHeader: some View {
        HStack {
            // 無料チケット数
            HStack(spacing: 4) {
                Image(systemName: "gift.fill")
                    .font(.caption)
                    .foregroundColor(.indigo)
                Text(String(format: NSLocalizedString("ai.menu.freeTicketCount", comment: ""), viewModel.freeTicketCount))
                    .font(.caption.bold())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 20).fill(Color.indigo.opacity(0.1)))

            // 購入チケット数
            HStack(spacing: 4) {
                Image(systemName: "ticket.fill")
                    .font(.caption)
                    .foregroundColor(.indigo)
                Text(String(format: NSLocalizedString("ai.menu.paidTicketCount", comment: ""), viewModel.paidTicketCount))
                    .font(.caption.bold())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 20).fill(Color.indigo.opacity(0.1)))

            Spacer()

            // 購入ボタン（マイページへ誘導）
            NavigationLink(destination: MyPageView()) {
                Text("ai.menu.buy")
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.indigo)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - メニューカード

    private var menuCards: some View {
        VStack(spacing: 12) {
            let hasTickets = viewModel.ticketCount > 0

            VStack(spacing: 0) {
                // 悩み相談
                NavigationLink(destination: AIConsultationView(viewModel: viewModel)) {
                    AIMenuCard(
                        icon: "brain.head.profile",
                        titleKey: "ai.menu.consultation.title",
                        descKey: "ai.menu.consultation.desc",
                        isEnabled: hasTickets
                    )
                }
                .buttonStyle(.plain)
                .disabled(!hasTickets)
                .onTapGesture {
                    if !viewModel.isAIConsentGiven { showConsent = true }
                }

                Divider().padding(.leading, 68)

                // 書籍要約
                NavigationLink(destination: AISummaryView(viewModel: viewModel)) {
                    AIMenuCard(
                        icon: "book.closed.fill",
                        titleKey: "ai.menu.summary.title",
                        descKey: "ai.menu.summary.desc",
                        isEnabled: hasTickets
                    )
                }
                .buttonStyle(.plain)
                .disabled(!hasTickets)

            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
            )

            // チケットなし時の警告
            if !hasTickets {
                Text("ai.menu.noTicket")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
            }

            // 参照書籍数
            let count = viewModel.booksWithMemosCount
            if count > 0 {
                Text(String(format: NSLocalizedString("ai.menu.bookRefCount", comment: ""), count))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            }
        }
    }
}

// MARK: - AIメニューカード

private struct AIMenuCard: View {
    let icon: String
    let titleKey: String
    let descKey: String
    let isEnabled: Bool

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isEnabled ? .indigo : .gray)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(titleKey))
                    .font(.headline)
                    .foregroundColor(isEnabled ? .primary : .secondary)
                Text(LocalizedStringKey(descKey))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .opacity(isEnabled ? 1.0 : 0.5)
    }
}

// MARK: - AI同意ビュー（メニュー用ラッパー）

struct AIConsentMenuView: View {
    @ObservedObject var viewModel: AIViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isChecked = false

    private var privacyPolicyURL: URL {
        let isJapanese = Locale.current.language.languageCode?.identifier == "ja"
        return URL(string: isJapanese
            ? "https://it-master.jp/biblion/privacy-policy.html"
            : "https://it-master.jp/biblion/privacy-policy-en.html")!
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Spacer()
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 60))
                            .foregroundColor(.indigo)
                        Spacer()
                    }
                    .padding(.top)

                    Text("ai.consentTitle")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity, alignment: .center)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("ai.consentBody")
                            .font(.body)
                            .lineSpacing(4)
                        Link(destination: privacyPolicyURL) {
                            Label("settings.privacyPolicy", systemImage: "link")
                                .font(.footnote)
                                .foregroundColor(.indigo)
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))

                    HStack(alignment: .top, spacing: 12) {
                        Button { isChecked.toggle() } label: {
                            Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                                .font(.title3)
                                .foregroundColor(isChecked ? .indigo : .gray)
                        }
                        .buttonStyle(.plain)
                        Text("ai.consentCheck")
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                            .onTapGesture { isChecked.toggle() }
                    }

                    Button {
                        CoreDataManager.shared.setAIConsent(true)
                        viewModel.refreshFromCoreData()
                        dismiss()
                    } label: {
                        Text("ai.consentConfirm")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isChecked ? Color.indigo : Color(.systemGray4))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(!isChecked)
                }
                .padding(.horizontal, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    AIMenuView()
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
}
