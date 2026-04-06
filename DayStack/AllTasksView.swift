import SwiftUI

// MARK: - Filter

enum TaskFilter: String, CaseIterable {
    case all        = "All"
    case incomplete = "Incomplete"
    case completed  = "Completed"
}

// MARK: - AllTasksView

struct AllTasksView: View {
    @EnvironmentObject var store: TaskStore
    @State private var expandedId: Int64?    = nil
    @State private var filter:     TaskFilter = .all

    /// Called when user taps a footprint — navigates to that date
    let onNavigateToDate: (String) -> Void

    // ── Real tasks (not footprints), filtered, grouped by display date
    // Display date = completed_date if done, else task.date (already the active date)
    var grouped: [(String, [Task])] {
        let real = store.allTasks.filter { !$0.isFootprint }

        let filtered = real.filter { task in
            switch filter {
            case .all:        return true
            case .incomplete: return !task.completed
            case .completed:  return  task.completed
            }
        }

        // Display date: if completed use completedDate, else use task.date
        func displayDate(_ t: Task) -> String {
            t.completed && !t.completedDate.isEmpty ? t.completedDate : t.date
        }

        let dates = Array(Set(filtered.map { displayDate($0) })).sorted(by: >)
        return dates.map { d in (d, filtered.filter { displayDate($0) == d }) }
    }

    // ── Footprint tasks grouped by their date
    var footprintsByDate: [String: [Task]] {
        guard filter == .all else { return [:] }
        let fps = store.allTasks.filter { $0.isFootprint }
        var result: [String: [Task]] = [:]
        for fp in fps {
            result[fp.date, default: []].append(fp)
        }
        return result
    }

    // All dates that appear in either real tasks or footprints
    var allDates: [String] {
        var dates = Set(grouped.map { $0.0 })
        if filter == .all { footprintsByDate.keys.forEach { dates.insert($0) } }
        return dates.sorted(by: >)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Filter toggles
            HStack(spacing: 4) {
                ForEach(TaskFilter.allCases, id: \.self) { option in
                    Button {
                        filter     = option
                        expandedId = nil
                    } label: {
                        Text(option.rawValue)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(filter == option ? .dsAccent : .dsTextMuted)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(filter == option ? Color.dsAccentDim : Color.dsSurface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(filter == option
                                                    ? Color.dsAccentBorder
                                                    : Color.dsBorder, lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            Rectangle().fill(Color.dsBorder).frame(height: 1).padding(.horizontal, 8)

            // Task list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if allDates.isEmpty {
                        Text(emptyMessage)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.dsTextDim)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 32)
                    }

                    ForEach(allDates, id: \.self) { date in
                        // Date header
                        Text(formatDateLabel(date))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.dsTextDim)
                            .tracking(1)
                            .padding(.horizontal, 12)
                            .padding(.top, 10)
                            .padding(.bottom, 4)

                        // Real tasks for this date
                        let realForDate = grouped.first(where: { $0.0 == date })?.1 ?? []
                        ForEach(realForDate) { task in
                            AllTaskRow(
                                task:       task,
                                isExpanded: expandedId == task.id,
                                onToggleExpand: {
                                    expandedId = expandedId == task.id ? nil : task.id
                                }
                            )
                        }

                        // Footprint rows for this date
                        let footprintsForDate = footprintsByDate[date] ?? []
                        ForEach(footprintsForDate) { fp in
                            FootprintRow(task: fp) {
                                let activeDate = store.findActiveDate(forFootprint: fp.id)
                                onNavigateToDate(activeDate)
                            }
                        }

                        Rectangle()
                            .fill(Color.dsBorder)
                            .frame(height: 1)
                            .padding(.horizontal, 8)
                            .padding(.top, 6)
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .onAppear { store.loadAllTasks() }
    }

    var emptyMessage: String {
        switch filter {
        case .all:        return "No tasks recorded yet."
        case .incomplete: return "No incomplete tasks."
        case .completed:  return "No completed tasks."
        }
    }
}

// MARK: - FootprintRow

struct FootprintRow: View {
    let task:     Task
    let onTap:    () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Text("↩")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.dsAmber)
                    .frame(width: 16, alignment: .center)

                Text(task.title)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.dsAmber.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("carried forward")
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundColor(.dsAmber.opacity(0.55))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.dsAmber.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.dsAmber.opacity(0.2), lineWidth: 1)
                            )
                    )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isHovered ? Color.dsSurface : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("Tap to go to the date where this task currently lives")
    }
}

// MARK: - AllTaskRow (read-only)

struct AllTaskRow: View {
    let task:           Task
    let isExpanded:     Bool
    let onToggleExpand: () -> Void

    @EnvironmentObject var store: TaskStore
    @State private var isHovered: Bool               = false
    @State private var history:   [TaskHistoryEntry] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                // Status icon — read only, no tap
                Text(task.completed ? "✓" : "○")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(task.completed ? .dsGreen : .dsTextMuted)
                    .frame(width: 16, alignment: .center)

                Text(task.title)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(task.completed ? .dsTextDim : .dsText)
                    .strikethrough(task.completed, color: .dsTextDim)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Expand for notes + history
                Button { onToggleExpand() } label: {
                    Text("›")
                        .font(.system(size: 15, design: .monospaced))
                        .foregroundColor(isExpanded ? .dsAccent : .dsTextDim)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.easeInOut(duration: 0.15), value: isExpanded)
                }
                .buttonStyle(.plain)
                .opacity(isHovered || isExpanded ? 1 : 0)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(isHovered ? Color.dsSurface : Color.clear)
            .onHover { isHovered = $0 }

            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    // Notes — read only
                    if !task.notes.isEmpty {
                        Text(task.notes)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.dsTextMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color.dsInput)
                                    .overlay(RoundedRectangle(cornerRadius: 5)
                                        .stroke(Color.dsBorder, lineWidth: 1))
                            )
                    }

                    // History — only for carried forward tasks
                    if !history.isEmpty {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("── History")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.dsTextDim)
                            if let first = history.first {
                                historyRow(icon: "◎", label: "Created",   date: first.fromDate, color: .dsTextDim)
                            }
                            ForEach(history) { entry in
                                historyRow(icon: "↩", label: "Carried",   date: entry.toDate,   color: .dsAmber)
                            }
                            if task.completed && !task.completedDate.isEmpty {
                                historyRow(icon: "✓", label: "Completed", date: task.completedDate, color: .dsGreen)
                            }
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(.leading, 32)
                .padding(.trailing, 12)
                .padding(.bottom,    6)
                .onAppear {
                    history = store.loadHistory(for: task.id)
                }
            }
        }
    }

    @ViewBuilder
    func historyRow(icon: String, label: String, date: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Text(icon)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(color)
                .frame(width: 12, alignment: .center)
            Text("\(label)  \(formatShortDate(date))")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(color.opacity(0.85))
        }
    }
}