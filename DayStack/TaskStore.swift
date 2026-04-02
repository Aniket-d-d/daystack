import Foundation
import SQLite3

// MARK: - TaskStore

class TaskStore: ObservableObject {

    @Published var tasks:    [Task] = []
    @Published var allTasks: [Task] = []

    private var db: OpaquePointer?

    // SQLITE_TRANSIENT tells SQLite to copy the string immediately
    // so it is safe after the call returns
    private let SQLITE_TRANSIENT = unsafeBitCast(
        -1, to: sqlite3_destructor_type.self
    )

    // MARK: - Init

    init() {
        openDB()
        createSchema()
    }

    deinit {
        sqlite3_close(db)
    }

    // MARK: - Setup

    /// Database is stored next to the .app bundle — inside the daystack folder.
    private func openDB() {
        let dbURL = Bundle.main.bundleURL
            .deletingLastPathComponent()          // folder containing DayStack.app
            .appendingPathComponent("daystack.db")

        if sqlite3_open(dbURL.path, &db) != SQLITE_OK {
            print("DayStack: Failed to open database at \(dbURL.path)")
        }
    }

    private func createSchema() {
        let sql = """
        CREATE TABLE IF NOT EXISTS tasks (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            date        TEXT    NOT NULL,
            title       TEXT    NOT NULL DEFAULT '',
            notes       TEXT    NOT NULL DEFAULT '',
            completed   INTEGER NOT NULL DEFAULT 0,
            order_index INTEGER NOT NULL DEFAULT 0,
            created_at  INTEGER NOT NULL DEFAULT (strftime('%s','now'))
        );
        CREATE INDEX IF NOT EXISTS idx_tasks_date ON tasks(date);
        """
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    // MARK: - Private Helpers

    private func str(_ stmt: OpaquePointer?, _ col: Int32) -> String {
        guard let ptr = sqlite3_column_text(stmt, col) else { return "" }
        return String(cString: ptr)
    }

    private func taskFrom(_ stmt: OpaquePointer?) -> Task {
        Task(
            id:         sqlite3_column_int64(stmt, 0),
            title:      str(stmt, 2),
            notes:      str(stmt, 3),
            completed:  sqlite3_column_int(stmt, 4) != 0,
            orderIndex: Int(sqlite3_column_int(stmt, 5)),
            date:       str(stmt, 1)
        )
    }

    private func bind(_ stmt: OpaquePointer?, _ col: Int32, _ s: String) {
        sqlite3_bind_text(stmt, col, s, -1, SQLITE_TRANSIENT)
    }

    // MARK: - Queries

    func loadTasks(for date: String) {
        var result: [Task] = []
        var stmt: OpaquePointer?
        let sql = """
        SELECT id, date, title, notes, completed, order_index
        FROM tasks WHERE date = ?
        ORDER BY order_index ASC, created_at ASC
        """
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            bind(stmt, 1, date)
            while sqlite3_step(stmt) == SQLITE_ROW {
                result.append(taskFrom(stmt))
            }
        }
        sqlite3_finalize(stmt)
        DispatchQueue.main.async { self.tasks = result }
    }

    func addTask(date: String, title: String) {
        // Get current max order index for this date
        var maxOrder: Int32 = -1
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT MAX(order_index) FROM tasks WHERE date = ?", -1, &stmt, nil) == SQLITE_OK {
            bind(stmt, 1, date)
            if sqlite3_step(stmt) == SQLITE_ROW {
                maxOrder = sqlite3_column_int(stmt, 0)
            }
        }
        sqlite3_finalize(stmt)

        // Insert
        if sqlite3_prepare_v2(db, "INSERT INTO tasks (date, title, order_index) VALUES (?,?,?)", -1, &stmt, nil) == SQLITE_OK {
            bind(stmt, 1, date)
            bind(stmt, 2, title)
            sqlite3_bind_int(stmt, 3, maxOrder + 1)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
        loadTasks(for: date)
    }

    func updateTask(_ task: Task) {
        var stmt: OpaquePointer?
        let sql = "UPDATE tasks SET title=?, notes=?, completed=? WHERE id=?"
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            bind(stmt, 1, task.title)
            bind(stmt, 2, task.notes)
            sqlite3_bind_int  (stmt, 3, task.completed ? 1 : 0)
            sqlite3_bind_int64(stmt, 4, task.id)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)

        // Reflect change in memory immediately
        DispatchQueue.main.async {
            if let i = self.tasks.firstIndex(where: { $0.id == task.id }) {
                self.tasks[i] = task
            }
            if let i = self.allTasks.firstIndex(where: { $0.id == task.id }) {
                self.allTasks[i] = task
            }
        }
    }

    func deleteTask(_ task: Task, date: String) {
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "DELETE FROM tasks WHERE id=?", -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, task.id)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
        loadTasks(for: date)
    }

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

    func loadAllTasks() {
        var result: [Task] = []
        var stmt: OpaquePointer?
        let sql = """
        SELECT id, date, title, notes, completed, order_index
        FROM tasks ORDER BY date DESC, order_index ASC, created_at ASC
        """
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                result.append(taskFrom(stmt))
            }
        }
        sqlite3_finalize(stmt)
        DispatchQueue.main.async { self.allTasks = result }
    }

    /// Returns dates in the given year/month that have at least one incomplete task.
    func incompleteDates(year: Int, month: Int) -> Set<String> {
        let prefix = String(format: "%04d-%02d", year, month)
        var dates  = Set<String>()
        var stmt: OpaquePointer?
        let sql = "SELECT DISTINCT date FROM tasks WHERE date LIKE ? AND completed=0"
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            bind(stmt, 1, prefix + "%")
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let ptr = sqlite3_column_text(stmt, 0) {
                    dates.insert(String(cString: ptr))
                }
            }
        }
        sqlite3_finalize(stmt)
        return dates
    }
}
