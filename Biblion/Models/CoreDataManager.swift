import CoreData
import Foundation

/// CoreData の CRUD 操作を集約するシングルトンマネージャー
final class CoreDataManager {

    static let shared = CoreDataManager()

    // MARK: - CoreData スタック

    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "Biblion")
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
}
