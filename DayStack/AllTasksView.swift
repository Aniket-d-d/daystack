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
    @State private var filter: TaskFilter    = .all

    /// Tasks filtered then grouped by date, newest first
    var grouped: [(String, [Task])] {
        let filtered = store.allTasks.filter { task in
            switch filter {
            case .all:        return true
            case .incomplete: return !task.completed
            case .completed:  return  task.completed
            }
        }
        let dates = Array(Set(filtered.map { $0.date })).sorted(by: >)
        return dates.map { date in
            (date, filtered.filter { $0.date == date })
        }
    }

    var body: some View {
        VStack(spacing: 0) {

            // ── Filter toggle bar
            HStack(spacing: 4) {
                ForEach(TaskFilter.allCases, id: \.self) { option in
                    Button {
                        filter = option
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
                                            .stroke(
                                                filter == option ? Color.dsAccentBorder : Color.dsBorder,
                                                lineWidth: 1
                                            )
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            Rectangle()
                .fill(Color.dsBorder)
                .frame(height: 1)
                .padding(.horizontal, 8)

            // ── Task list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if grouped.isEmpty {
                        Text(emptyMessage)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.dsTextDim)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 32)
                    }

                    ForEach(grouped, id: \.0) { (date, tasks) in
                        // Date header
                        Text(formatDateLabel(date))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.dsTextDim)
                            .tracking(1)
                            .padding(.horizontal, 12)
                            .padding(.top, 10)
                            .padding(.bottom, 4)

                        // Task rows
                        ForEach(tasks) { task in
                            AllTaskRow(
                                task:           task,
                                isExpanded:     expandedId == task.id,
                                onToggle: {
                                    var t = task; t.completed.toggle()
                                    store.updateTask(t)
                                },
                                onToggleExpand: {
                                    expandedId = expandedId == task.id ? nil : task.id
                                },
                                onUpdateNotes: { notes in
                                    var t = task; t.notes = notes
                                    store.updateTask(t)
                                }
                            )
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

// MARK: - AllTaskRow

struct AllTaskRow: View {
    let task:           Task
    let isExpanded:     Bool
    let onToggle:       () -> Void
    let onToggleExpand: () -> Void
    let onUpdateNotes:  (String) -> Void

    @State private var isHovered: Bool             = false
    @State private var notes:     String           = ""
    @State private var saveWork:  DispatchWorkItem? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                // Toggle
                Button { onToggle() } label: {
                    Text(task.completed ? "✓" : "○")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(task.completed ? .dsGreen : .dsTextMuted)
                        .frame(width: 16, alignment: .center)
                }
                .buttonStyle(.plain)

                // Title
                Text(task.title)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(task.completed ? .dsTextDim : .dsText)
                    .strikethrough(task.completed, color: .dsTextDim)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Expand
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
            .padding(.vertical,   6)
            .padding(.horizontal, 12)
            .background(isHovered ? Color.dsSurface : Color.clear)
            .onHover { isHovered = $0 }

            if isExpanded {
                TextEditor(text: $notes)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.dsTextMuted)
                    .scrollContentBackground(.hidden)
                    .background(Color.dsInput)
                    .cornerRadius(5)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.dsBorder, lineWidth: 1)
                    )
                    .frame(minHeight: 60, maxHeight: 90)
                    .padding(.leading, 32)
                    .padding(.trailing, 12)
                    .padding(.bottom,    6)
                    .onAppear { notes = task.notes }
                    .onChange(of: notes) { newVal in
                        saveWork?.cancel()
                        let work = DispatchWorkItem { onUpdateNotes(newVal) }
                        saveWork = work
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
                    }
            }
        }
    }
}