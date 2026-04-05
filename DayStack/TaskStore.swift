import Foundation
import SQLite3

class TaskStore: ObservableObject {

    @Published var tasks:              [Task]             = []
    @Published var allTasks:           [Task]             = []
    @Published var incompleteOldTasks: [(String, [Task])] = []

    private var db: OpaquePointer?
    private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    // MARK: - Init

    init() {
        openDB()
        createSchema()
        migrateSchema()
    }

    deinit { sqlite3_close(db) }

    // MARK: - Setup

    private func openDB() {
        let url = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .appendingPathComponent("daystack.db")
        if sqlite3_open(url.path, &db) != SQLITE_OK {
            print("DayStack: could not open DB")
        }
    }

    private func createSchema() {
        sqlite3_exec(db, """
        CREATE TABLE IF NOT EXISTS tasks (
            id               INTEGER PRIMARY KEY AUTOINCREMENT,
            date             TEXT    NOT NULL,
            title            TEXT    NOT NULL DEFAULT '',
            notes            TEXT    NOT NULL DEFAULT '',
            completed        INTEGER NOT NULL DEFAULT 0,
            completed_date   TEXT    NOT NULL DEFAULT '',
            order_index      INTEGER NOT NULL DEFAULT 0,
            is_footprint     INTEGER NOT NULL DEFAULT 0,
            forwarded_to_id  INTEGER NOT NULL DEFAULT 0,
            chain_id         INTEGER NOT NULL DEFAULT 0,
            created_at       INTEGER NOT NULL DEFAULT (strftime('%s','now'))
        );
        CREATE INDEX IF NOT EXISTS idx_tasks_date    ON tasks(date);
        CREATE INDEX IF NOT EXISTS idx_tasks_chain   ON tasks(chain_id);
        CREATE TABLE IF NOT EXISTS task_history (
            id        INTEGER PRIMARY KEY AUTOINCREMENT,
            task_id   INTEGER NOT NULL,
            from_date TEXT    NOT NULL,
            to_date   TEXT    NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_history_task ON task_history(task_id);
        """, nil, nil, nil)
    }

    private func migrateSchema() {
        sqlite3_exec(db, "ALTER TABLE tasks ADD COLUMN completed_date  TEXT    NOT NULL DEFAULT ''", nil, nil, nil)
        sqlite3_exec(db, "ALTER TABLE tasks ADD COLUMN is_footprint    INTEGER NOT NULL DEFAULT 0",  nil, nil, nil)
        sqlite3_exec(db, "ALTER TABLE tasks ADD COLUMN forwarded_to_id INTEGER NOT NULL DEFAULT 0",  nil, nil, nil)
        sqlite3_exec(db, "ALTER TABLE tasks ADD COLUMN chain_id        INTEGER NOT NULL DEFAULT 0",  nil, nil, nil)
        // Back-fill chain_id = id for any tasks that have chain_id = 0
        sqlite3_exec(db, "UPDATE tasks SET chain_id = id WHERE chain_id = 0", nil, nil, nil)
    }

    // MARK: - Helpers

    private func str(_ s: OpaquePointer?, _ col: Int32) -> String {
        guard let p = sqlite3_column_text(s, col) else { return "" }
        return String(cString: p)
    }

    private func bind(_ s: OpaquePointer?, _ col: Int32, _ v: String) {
        sqlite3_bind_text(s, col, v, -1, SQLITE_TRANSIENT)
    }

    // SELECT column order:
    // 0=id 1=date 2=title 3=notes 4=completed 5=completed_date
    // 6=order_index 7=is_footprint 8=forwarded_to_id 9=chain_id
    private let cols = """
        id, date, title, notes, completed, completed_date,
        order_index, is_footprint, forwarded_to_id, chain_id
    """

    private func taskFrom(_ s: OpaquePointer?) -> Task {
        Task(
            id:            sqlite3_column_int64(s, 0),
            title:         str(s, 2),
            notes:         str(s, 3),
            completed:     sqlite3_column_int(s, 4) != 0,
            completedDate: str(s, 5),
            orderIndex:    Int(sqlite3_column_int(s, 6)),
            date:          str(s, 1),
            isFootprint:   sqlite3_column_int(s, 7) != 0,
            forwardedToId: sqlite3_column_int64(s, 8),
            chainId:       sqlite3_column_int64(s, 9)
        )
    }

    // MARK: - Load

    func loadTasks(for date: String) {
        var result: [Task] = []
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db,
            "SELECT \(cols) FROM tasks WHERE date=? ORDER BY order_index ASC, created_at ASC",
            -1, &stmt, nil) == SQLITE_OK {
            bind(stmt, 1, date)
            while sqlite3_step(stmt) == SQLITE_ROW { result.append(taskFrom(stmt)) }
        }
        sqlite3_finalize(stmt)
        DispatchQueue.main.async { self.tasks = result }
    }

    func loadAllTasks() {
        var result: [Task] = []
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db,
            "SELECT \(cols) FROM tasks ORDER BY date DESC, order_index ASC, created_at ASC",
            -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW { result.append(taskFrom(stmt)) }
        }
        sqlite3_finalize(stmt)
        DispatchQueue.main.async { self.allTasks = result }
    }

    func loadIncompleteOldTasks(before today: String) {
        var result: [Task] = []
        var stmt: OpaquePointer?
        // Only non-footprint incomplete tasks can be carried forward
        if sqlite3_prepare_v2(db,
            "SELECT \(cols) FROM tasks WHERE date<? AND completed=0 AND is_footprint=0 ORDER BY date DESC, order_index ASC",
            -1, &stmt, nil) == SQLITE_OK {
            bind(stmt, 1, today)
            while sqlite3_step(stmt) == SQLITE_ROW { result.append(taskFrom(stmt)) }
        }
        sqlite3_finalize(stmt)
        let dates   = Array(Set(result.map { $0.date })).sorted(by: >)
        let grouped = dates.map { d in (d, result.filter { $0.date == d }) }
        DispatchQueue.main.async { self.incompleteOldTasks = grouped }
    }

    // MARK: - Add

    func addTask(date: String, title: String) {
        var maxOrder: Int32 = -1
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT MAX(order_index) FROM tasks WHERE date=?", -1, &stmt, nil) == SQLITE_OK {
            bind(stmt, 1, date)
            if sqlite3_step(stmt) == SQLITE_ROW { maxOrder = sqlite3_column_int(stmt, 0) }
        }
        sqlite3_finalize(stmt)

        if sqlite3_prepare_v2(db,
            "INSERT INTO tasks (date, title, order_index) VALUES (?,?,?)",
            -1, &stmt, nil) == SQLITE_OK {
            bind(stmt, 1, date)
            bind(stmt, 2, title)
            sqlite3_bind_int(stmt, 3, maxOrder + 1)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)

        // Set chain_id = id for a brand new task
        let newId = sqlite3_last_insert_rowid(db)
        sqlite3_exec(db, "UPDATE tasks SET chain_id=\(newId) WHERE id=\(newId)", nil, nil, nil)
        loadTasks(for: date)
    }

    // MARK: - Update

    func updateTask(_ task: Task) {
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db,
            "UPDATE tasks SET title=?, notes=?, completed=?, completed_date=? WHERE id=?",
            -1, &stmt, nil) == SQLITE_OK {
            bind(stmt, 1, task.title)
            bind(stmt, 2, task.notes)
            sqlite3_bind_int  (stmt, 3, task.completed ? 1 : 0)
            bind(stmt, 4, task.completedDate)
            sqlite3_bind_int64(stmt, 5, task.id)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
        DispatchQueue.main.async {
            if let i = self.tasks.firstIndex(where:    { $0.id == task.id }) { self.tasks[i]    = task }
            if let i = self.allTasks.firstIndex(where: { $0.id == task.id }) { self.allTasks[i] = task }
        }
    }

    /// Rename every task in the same carry-forward chain
    func updateTitleInChain(chainId: Int64, newTitle: String) {
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db,
            "UPDATE tasks SET title=? WHERE chain_id=?",
            -1, &stmt, nil) == SQLITE_OK {
            bind(stmt, 1, newTitle)
            sqlite3_bind_int64(stmt, 2, chainId)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
        // Reflect in memory
        DispatchQueue.main.async {
            for i in self.tasks.indices    where self.tasks[i].chainId    == chainId { self.tasks[i].title    = newTitle }
            for i in self.allTasks.indices where self.allTasks[i].chainId == chainId { self.allTasks[i].title = newTitle }
        }
    }

    // MARK: - Delete

    func deleteTask(_ task: Task, date: String) {
        var stmt: OpaquePointer?

        // ── Step 1: Find who was pointing TO this task (the previous footprint)
        // That task has forwarded_to_id = task.id
        var previousId: Int64 = 0
        if sqlite3_prepare_v2(db,
            "SELECT id FROM tasks WHERE forwarded_to_id=?",
            -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, task.id)
            if sqlite3_step(stmt) == SQLITE_ROW {
                previousId = sqlite3_column_int64(stmt, 0)
            }
        }
        sqlite3_finalize(stmt)

        // ── Step 2: Collect all tasks FORWARD from this task (this + everything it points to)
        // These all get deleted since they came after the deletion point
        var toDelete: [Int64] = []
        var currentId: Int64 = task.id
        var visited = Set<Int64>()
        while currentId != 0 && !visited.contains(currentId) {
            visited.insert(currentId)
            toDelete.append(currentId)
            var nextId: Int64 = 0
            if sqlite3_prepare_v2(db,
                "SELECT forwarded_to_id FROM tasks WHERE id=?",
                -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_int64(stmt, 1, currentId)
                if sqlite3_step(stmt) == SQLITE_ROW {
                    nextId = sqlite3_column_int64(stmt, 0)
                }
            }
            sqlite3_finalize(stmt)
            currentId = nextId
        }

        // ── Step 3: Delete all forward tasks and their history
        for deleteId in toDelete {
            sqlite3_prepare_v2(db, "DELETE FROM tasks        WHERE id=?",      -1, &stmt, nil)
            sqlite3_bind_int64(stmt, 1, deleteId); sqlite3_step(stmt); sqlite3_finalize(stmt)
            sqlite3_prepare_v2(db, "DELETE FROM task_history WHERE task_id=?", -1, &stmt, nil)
            sqlite3_bind_int64(stmt, 1, deleteId); sqlite3_step(stmt); sqlite3_finalize(stmt)
        }

        // ── Step 4: Restore the previous footprint to a live task
        // (clear is_footprint and forwarded_to_id so it becomes active again)
        if previousId != 0 {
            if sqlite3_prepare_v2(db,
                "UPDATE tasks SET is_footprint=0, forwarded_to_id=0 WHERE id=?",
                -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_int64(stmt, 1, previousId)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }

        loadTasks(for: date)
    }

    // MARK: - Reorder

    func reorderTasks(_ ordered: [Task]) {
        var stmt: OpaquePointer?
        for (i, task) in ordered.enumerated() {
            if sqlite3_prepare_v2(db, "UPDATE tasks SET order_index=? WHERE id=?", -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_int  (stmt, 1, Int32(i))
                sqlite3_bind_int64(stmt, 2, task.id)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
        DispatchQueue.main.async { self.tasks = ordered }
    }

    // MARK: - Carry Forward

    func carryForward(task: Task, toDate: String) {
        var stmt: OpaquePointer?

        // 1. Get max order for today
        var maxOrder: Int32 = -1
        if sqlite3_prepare_v2(db, "SELECT MAX(order_index) FROM tasks WHERE date=?", -1, &stmt, nil) == SQLITE_OK {
            bind(stmt, 1, toDate)
            if sqlite3_step(stmt) == SQLITE_ROW { maxOrder = sqlite3_column_int(stmt, 0) }
        }
        sqlite3_finalize(stmt)

        // 2. Insert new task — same chain_id as source
        var newId: Int64 = 0
        if sqlite3_prepare_v2(db,
            "INSERT INTO tasks (date, title, notes, order_index, chain_id) VALUES (?,?,?,?,?)",
            -1, &stmt, nil) == SQLITE_OK {
            bind(stmt, 1, toDate)
            bind(stmt, 2, task.title)
            bind(stmt, 3, task.notes)
            sqlite3_bind_int  (stmt, 4, maxOrder + 1)
            sqlite3_bind_int64(stmt, 5, task.chainId)   // ← same chain
            sqlite3_step(stmt)
            newId = sqlite3_last_insert_rowid(db)
        }
        sqlite3_finalize(stmt)

        // 3. Mark source as footprint
        if sqlite3_prepare_v2(db,
            "UPDATE tasks SET is_footprint=1, forwarded_to_id=? WHERE id=?",
            -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, newId)
            sqlite3_bind_int64(stmt, 2, task.id)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)

        // 4. Copy existing history to new task
        for entry in loadHistory(for: task.id) {
            if sqlite3_prepare_v2(db,
                "INSERT INTO task_history (task_id, from_date, to_date) VALUES (?,?,?)",
                -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_int64(stmt, 1, newId)
                bind(stmt, 2, entry.fromDate)
                bind(stmt, 3, entry.toDate)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }

        // 5. New history entry: from task.date → toDate
        if sqlite3_prepare_v2(db,
            "INSERT INTO task_history (task_id, from_date, to_date) VALUES (?,?,?)",
            -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, newId)
            bind(stmt, 2, task.date)
            bind(stmt, 3, toDate)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)

        loadTasks(for: toDate)
        loadIncompleteOldTasks(before: toDate)
    }

    // MARK: - History

    func loadHistory(for taskId: Int64) -> [TaskHistoryEntry] {
        var result: [TaskHistoryEntry] = []
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db,
            "SELECT id, task_id, from_date, to_date FROM task_history WHERE task_id=? ORDER BY id ASC",
            -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, taskId)
            while sqlite3_step(stmt) == SQLITE_ROW {
                result.append(TaskHistoryEntry(
                    id: sqlite3_column_int64(stmt, 0),
                    taskId: sqlite3_column_int64(stmt, 1),
                    fromDate: str(stmt, 2),
                    toDate: str(stmt, 3)
                ))
            }
        }
        sqlite3_finalize(stmt)
        return result
    }

    // MARK: - Calendar

    func incompleteDates(year: Int, month: Int) -> Set<String> {
        let prefix = String(format: "%04d-%02d", year, month)
        var dates  = Set<String>()
        var stmt: OpaquePointer?
        // Footprints are NOT counted as incomplete
        if sqlite3_prepare_v2(db,
            "SELECT DISTINCT date FROM tasks WHERE date LIKE ? AND completed=0 AND is_footprint=0",
            -1, &stmt, nil) == SQLITE_OK {
            bind(stmt, 1, prefix + "%")
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let p = sqlite3_column_text(stmt, 0) { dates.insert(String(cString: p)) }
            }
        }
        sqlite3_finalize(stmt)
        return dates
    }

    // MARK: - Active date for footprint navigation

    func findActiveDate(forFootprint taskId: Int64) -> String {
        var currentId = taskId
        var visited   = Set<Int64>()
        while !visited.contains(currentId) {
            visited.insert(currentId)
            var stmt: OpaquePointer?
            var forwardedTo: Int64 = 0
            var isFootprint = false
            var date        = ""
            var completedDate = ""
            var completed   = false
            if sqlite3_prepare_v2(db,
                "SELECT forwarded_to_id, is_footprint, date, completed_date, completed FROM tasks WHERE id=?",
                -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_int64(stmt, 1, currentId)
                if sqlite3_step(stmt) == SQLITE_ROW {
                    forwardedTo   = sqlite3_column_int64(stmt, 0)
                    isFootprint   = sqlite3_column_int(stmt, 1) != 0
                    date          = str(stmt, 2)
                    completedDate = str(stmt, 3)
                    completed     = sqlite3_column_int(stmt, 4) != 0
                }
            }
            sqlite3_finalize(stmt)
            if !isFootprint || forwardedTo == 0 {
                if completed && !completedDate.isEmpty { return completedDate }
                return date
            }
            currentId = forwardedTo
        }
        return todayStr()
    }
}