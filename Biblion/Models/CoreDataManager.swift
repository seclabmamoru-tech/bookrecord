import CoreData
import Foundation

/// CoreData の CRUD 操作を集約するシングルトンマネージャー
final class CoreDataManager {

    static let shared = CoreDataManager()

    // MARK: - CoreData スタック

    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "Biblion")
        if let description = container.persistentStoreDescriptions.first {
            description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        }
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("CoreData ストアの読み込みに失敗しました: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return container
    }()

    var context: NSManagedObjectContext {
        persistentContainer.viewContext
    }

    private init() {}

    // MARK: - 保存

    func save() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            print("CoreData の保存に失敗しました: \(error)")
        }
    }

    // MARK: - Book CRUD

    @discardableResult
    func addBook(
        title: String,
        author: String,
        genre: String,
        status: String,
        startDate: Date?,
        endDate: Date?,
        coverImageData: Data?
    ) -> Book {
        let book = Book(context: context)
        book.id = UUID()
        book.title = title
        book.author = author
        book.genre = genre
        book.status = status
        book.startDate = startDate
        book.endDate = endDate
        book.coverImageData = coverImageData
        book.totalReadingMinutes = 0
        book.createdAt = Date()
        save()
        return book
    }

    func updateBook(_ book: Book) {
        save()
    }

    func deleteBook(_ book: Book) {
        fetchMemos(for: book).forEach { context.delete($0) }
        fetchReadingSessions(for: book).forEach { context.delete($0) }
        context.delete(book)
        save()
    }

    func fetchBooks() -> [Book] {
        let request: NSFetchRequest<Book> = Book.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Book.createdAt, ascending: false)
        ]
        return (try? context.fetch(request)) ?? []
    }

    // MARK: - Memo CRUD

    @discardableResult
    func addMemo(content: String, to book: Book, sortOrder: Int32) -> Memo {
        let memo = Memo(context: context)
        memo.id = UUID()
        memo.content = content
        memo.sortOrder = sortOrder
        memo.createdAt = Date()
        memo.book = book
        save()
        return memo
    }

    func updateMemo(_ memo: Memo) {
        save()
    }

    func deleteMemo(_ memo: Memo) {
        context.delete(memo)
        save()
    }

    func fetchMemos(for book: Book) -> [Memo] {
        let request: NSFetchRequest<Memo> = Memo.fetchRequest()
        request.predicate = NSPredicate(format: "book == %@", book)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Memo.sortOrder, ascending: true)
        ]
        return (try? context.fetch(request)) ?? []
    }

    // MARK: - ReadingSession CRUD

    /// durationMinutes フィールドには実際の秒数を保存する（フィールド名は旧来の名称）
    @discardableResult
    func addReadingSession(book: Book, durationSeconds: Int32, date: Date) -> ReadingSession {
        let session = ReadingSession(context: context)
        session.id = UUID()
        session.date = date
        session.durationMinutes = durationSeconds   // 秒数を格納
        session.book = book
        book.totalReadingMinutes += durationSeconds // 累計も秒数で管理
        save()
        return session
    }

    func deleteReadingSession(_ session: ReadingSession) {
        if let book = session.book {
            book.totalReadingMinutes -= session.durationMinutes
        }
        context.delete(session)
        save()
    }

    func fetchReadingSessions(for book: Book) -> [ReadingSession] {
        let request: NSFetchRequest<ReadingSession> = ReadingSession.fetchRequest()
        request.predicate = NSPredicate(format: "book == %@", book)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ReadingSession.date, ascending: false)
        ]
        return (try? context.fetch(request)) ?? []
    }

    // MARK: - TaskEntity CRUD

    @discardableResult
    func addTask(title: String, sortOrder: Int32) -> TaskEntity {
        let task = TaskEntity(context: context)
        task.id = UUID()
        task.title = title
        task.sortOrder = sortOrder
        task.createdAt = Date()
        save()
        return task
    }

    func updateTask(_ task: TaskEntity) {
        save()
    }

    func deleteTask(_ task: TaskEntity) {
        context.delete(task)
        save()
    }

    func fetchTasks() -> [TaskEntity] {
        let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \TaskEntity.sortOrder, ascending: true)
        ]
        return (try? context.fetch(request)) ?? []
    }

    // MARK: - TaskRecord CRUD

    func setTaskRecord(task: TaskEntity, date: Date, isDone: Bool) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        let request: NSFetchRequest<TaskRecord> = TaskRecord.fetchRequest()
        request.predicate = NSPredicate(
            format: "task == %@ AND date >= %@ AND date < %@",
            task,
            startOfDay as NSDate,
            endOfDay as NSDate
        )

        if let existing = (try? context.fetch(request))?.first {
            existing.isDone = isDone
        } else {
            let record = TaskRecord(context: context)
            record.id = UUID()
            record.date = startOfDay
            record.isDone = isDone
            record.task = task
        }
        save()
    }

    func fetchTaskRecords(for task: TaskEntity) -> [TaskRecord] {
        let request: NSFetchRequest<TaskRecord> = TaskRecord.fetchRequest()
        request.predicate = NSPredicate(format: "task == %@", task)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \TaskRecord.date, ascending: false)
        ]
        return (try? context.fetch(request)) ?? []
    }

    /// 当日のタスク記録を取得する
    func todayRecord(for task: TaskEntity) -> TaskRecord? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return nil }

        let request: NSFetchRequest<TaskRecord> = TaskRecord.fetchRequest()
        request.predicate = NSPredicate(
            format: "task == %@ AND date >= %@ AND date < %@",
            task,
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        return (try? context.fetch(request))?.first
    }

    // MARK: - UserPlan CRUD

    /// UserPlanを取得、なければ作成して返す（アプリ内に1レコードのみ）
    @discardableResult
    func fetchOrCreateUserPlan() -> UserPlan {
        let request: NSFetchRequest<UserPlan> = UserPlan.fetchRequest()
        request.fetchLimit = 1
        if let existing = (try? context.fetch(request))?.first {
            migrateTicketCountIfNeeded(existing)
            return existing
        }
        // 新規作成（初回起動）
        let plan = UserPlan(context: context)
        plan.id = UUID()
        plan.planType = "free"
        plan.ticketCount = 0
        plan.freeTicketGranted = false
        plan.isAIConsentGiven = false
        plan.updatedAt = Date()

        // UserDefaults からの同意マイグレーション
        if UserDefaults.standard.bool(forKey: "aiConsentGranted") {
            plan.isAIConsentGiven = true
            UserDefaults.standard.removeObject(forKey: "aiConsentGranted")
        }
        save()
        return plan
    }

    /// 旧 ticketCount → freeTicketCount マイグレーション（既存インストール向け）
    private func migrateTicketCountIfNeeded(_ plan: UserPlan) {
        guard plan.freeTicketCount == 0 && plan.planTicketCount == 0 && plan.purchasedTicketCount == 0,
              plan.ticketCount > 0 else { return }
        plan.freeTicketCount = plan.ticketCount
        plan.ticketCount = 0
        save()
    }

    /// 初回無料チケット付与（未付与の場合のみ100枚付与）
    func grantFreeTicketsIfNeeded() {
        let plan = fetchOrCreateUserPlan()
        if !plan.freeTicketGranted {
            plan.freeTicketCount = 100
            plan.freeTicketGranted = true
            plan.updatedAt = Date()
            save()
        } else if plan.freeTicketCount < 100 {
            // 旧バージョンで少ない枚数が付与された場合は100枚に更新
            plan.freeTicketCount = 100
            plan.updatedAt = Date()
            save()
        }
    }

    /// プラン情報を更新
    func updateUserPlan(planType: String, expiresAt: Date?) {
        let plan = fetchOrCreateUserPlan()
        plan.planType = planType
        plan.expiresAt = expiresAt
        plan.updatedAt = Date()
        save()
    }

    /// AI同意状態を更新
    func setAIConsent(_ granted: Bool) {
        let plan = fetchOrCreateUserPlan()
        plan.isAIConsentGiven = granted
        plan.updatedAt = Date()
        save()
    }

    /// 全チケット合計数
    var totalTicketCount: Int32 {
        let plan = fetchOrCreateUserPlan()
        return plan.freeTicketCount + plan.planTicketCount + plan.purchasedTicketCount
    }

    /// チケットを消費（成功時のみ呼ぶ）
    /// - Returns: true if a free ticket was consumed (→ show AI ad), false otherwise
    @discardableResult
    func consumeTicket() -> Bool {
        let plan = fetchOrCreateUserPlan()
        plan.updatedAt = Date()
        if plan.freeTicketCount > 0 {
            plan.freeTicketCount -= 1
            save()
            return true
        } else if plan.planTicketCount > 0 {
            plan.planTicketCount -= 1
            save()
            return false
        } else if plan.purchasedTicketCount > 0 {
            plan.purchasedTicketCount -= 1
            save()
            return false
        }
        return false
    }

    /// プランチケットを追加（月次付与）
    func addPlanTickets(_ count: Int32) {
        let plan = fetchOrCreateUserPlan()
        plan.planTicketCount += count
        plan.updatedAt = Date()
        save()
    }

    /// 購入チケットを追加
    func addPurchasedTickets(_ count: Int32) {
        let plan = fetchOrCreateUserPlan()
        plan.purchasedTicketCount += count
        plan.updatedAt = Date()
        save()
    }

    // MARK: - ScheduledTask CRUD

    @discardableResult
    func addScheduledTask(
        taskTitle: String,
        startHour: Int16,
        startMinute: Int16,
        endHour: Int16,
        endMinute: Int16,
        frequency: String,
        weekdays: String,
        referenceDate: Date
    ) -> ScheduledTask {
        let task = ScheduledTask(context: context)
        task.id = UUID()
        task.taskTitle = taskTitle
        task.startHour = startHour
        task.startMinute = startMinute
        task.endHour = endHour
        task.endMinute = endMinute
        task.frequency = frequency
        task.weekdays = weekdays
        task.referenceDate = referenceDate
        task.createdAt = Date()
        save()
        return task
    }

    func updateScheduledTask(_ task: ScheduledTask) {
        save()
    }

    func deleteScheduledTask(_ task: ScheduledTask) {
        context.delete(task)
        save()
    }

    func fetchScheduledTasks() -> [ScheduledTask] {
        let request: NSFetchRequest<ScheduledTask> = ScheduledTask.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ScheduledTask.createdAt, ascending: true)
        ]
        return (try? context.fetch(request)) ?? []
    }

    // MARK: - AIHistory CRUD

    @discardableResult
    func addAIHistory(
        menuType: String,
        inputText: String,
        outputText: String,
        ticketsUsed: Int32 = 1
    ) -> AIHistory {
        let history = AIHistory(context: context)
        history.id = UUID()
        history.menuType = menuType
        history.inputText = inputText
        history.outputText = outputText
        history.ticketsUsed = ticketsUsed
        history.createdAt = Date()
        save()
        return history
    }

    func fetchAIHistory() -> [AIHistory] {
        let request: NSFetchRequest<AIHistory> = AIHistory.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \AIHistory.createdAt, ascending: false)
        ]
        return (try? context.fetch(request)) ?? []
    }
}
