import SwiftUI

// MARK: - TasksView

struct TasksView: View {
    @EnvironmentObject var store: TaskStore
    let selectedDate: String
    let today:        String

    @State private var editingId:        Int64?  = nil
    @State private var editingTitle:     String  = ""
    @State private var expandedId:       Int64?  = nil
    @State private var isAdding:         Bool    = false
    @State private var newTitle:         String  = ""
    @State private var showCarryForward: Bool    = false
    @FocusState private var addFieldFocused: Bool

    var isPast: Bool { selectedDate < today }

    var body: some View {
        VStack(spacing: 0) {
            // Date header
            HStack {
                Text(formatHeader(selectedDate))
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundColor(.dsTextMuted)
                    .tracking(1.5)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 6)

            // Task list
            List {
                ForEach(store.tasks) { task in
                    TaskRowView(
                        task:          task,
                        isExpanded:    expandedId == task.id,
                        isEditing:     editingId  == task.id,
                        editingTitle:  editingId  == task.id ? $editingTitle : .constant(""),
                        onToggle:        { toggle(task) },
                        onTapTitle:      { startEdit(task) },
                        onSaveTitle:     { saveTitle(task) },
                        onCancelEdit:    { editingId = nil },
                        onToggleExpand:  { expandedId = expandedId == task.id ? nil : task.id },
                        onDelete:        { delete(task) },
                        onUpdateNotes:   { notes in updateNotes(task, notes) }
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 1, leading: 6, bottom: 1, trailing: 6))
                }
                .onMove { from, to in
                    guard !isPast else { return }
                    var t = store.tasks
                    t.move(fromOffsets: from, toOffset: to)
                    store.reorderTasks(t)
                }

                if store.tasks.isEmpty {
                    Text("No tasks yet.")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.dsTextDim)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 24)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)

            // Bottom action area — available on all dates
            Rectangle()
                .fill(Color.dsBorder)
                .frame(height: 1)
                .padding(.horizontal, 8)

            if isAdding {
                addTaskField
            } else {
                bottomActions
            }
        }
        .onAppear {
            store.loadTasks(for: selectedDate)
        }
        // Carry Forward sheet
        .sheet(isPresented: $showCarryForward) {
            CarryForwardSheet(targetDate: selectedDate, isPresented: $showCarryForward)
                .environmentObject(store)
        }
    }

    // MARK: - Bottom Actions (Add + Carry Forward)

    var bottomActions: some View {
        HStack(spacing: 6) {
            // + Add Task
            Button {
                isAdding        = true
                newTitle        = ""
                addFieldFocused = true
            } label: {
                Text("+ Add Task")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.dsTextDim)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(Color.dsTextDim,
                                    style: StrokeStyle(lineWidth: 1, dash: [4]))
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // ↩ Carry Forward
            Button {
                store.loadIncompleteOldTasks(before: selectedDate)
                showCarryForward = true
            } label: {
                Text("↩")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.dsAmber)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Color.dsAmber.opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(Color.dsAmber.opacity(0.35), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
            .help("Carry forward incomplete tasks from previous days")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
    }

    var addTaskField: some View {
        HStack(spacing: 8) {
            TextField("Task name…", text: $newTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.dsAccent)
                .focused($addFieldFocused)
                .onSubmit      { commitNew() }
                .onExitCommand { cancelNew() }

            Button("✕") { cancelNew() }
                .buttonStyle(.plain)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.dsTextDim)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(Color.dsSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(Color.dsAccentBorder, lineWidth: 1)
                )
        )
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
    }

    // MARK: - Actions

    func toggle(_ task: Task) {
        var t = task
        t.completed.toggle()
        t.completedDate = t.completed ? selectedDate : ""
        store.updateTask(t)
    }

    func startEdit(_ task: Task) {
        // Editing now allowed on all dates including past
        editingId    = task.id
        editingTitle = task.title
    }

    func saveTitle(_ task: Task) {
        let v = editingTitle.trimmingCharacters(in: .whitespaces)
        if !v.isEmpty {
            // Update title across the entire carry-forward chain
            store.updateTitleInChain(chainId: task.chainId, newTitle: v)
        }
        editingId = nil
    }

    func delete(_ task: Task) {
        if expandedId == task.id { expandedId = nil }
        if editingId  == task.id { editingId  = nil }
        store.deleteTask(task, date: selectedDate)
    }

    func updateNotes(_ task: Task, _ notes: String) {
        var t = task; t.notes = notes
        store.updateTask(t)
    }

    func commitNew() {
        let v = newTitle.trimmingCharacters(in: .whitespaces)
        if !v.isEmpty { store.addTask(date: selectedDate, title: v) }
        isAdding = false
        newTitle = ""
    }

    func cancelNew() {
        isAdding = false
        newTitle = ""
    }
}

// MARK: - TaskRowView

struct TaskRowView: View {
    let task:         Task
    let isExpanded:   Bool
    let isEditing:    Bool
    @Binding var editingTitle: String

    let onToggle:       () -> Void
    let onTapTitle:     () -> Void
    let onSaveTitle:    () -> Void
    let onCancelEdit:   () -> Void
    let onToggleExpand: () -> Void
    let onDelete:       () -> Void
    let onUpdateNotes:  (String) -> Void

    @EnvironmentObject var store: TaskStore
    @State private var isHovered: Bool             = false
    @State private var notes:     String           = ""
    @State private var saveWork:  DispatchWorkItem? = nil
    @State private var history:   [TaskHistoryEntry] = []

    var body: some View {
        if task.isFootprint {
            footprintView
        } else {
            activeView
        }
    }

    // Read-only dim row for carried-forward tasks on their original date
    var footprintView: some View {
        HStack(spacing: 8) {
            Text("↩")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.dsAmber.opacity(0.6))
                .frame(width: 14, alignment: .center)
            Text(task.title)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.dsAmber.opacity(0.45))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("carry forwarded")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.dsAmber.opacity(0.4))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.dsAmber.opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.dsAmber.opacity(0.15), lineWidth: 1))
                )
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 5)
    }

    var activeView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            HStack(spacing: 5) {
                // Check
                Button { onToggle() } label: {
                    Text(task.completed ? "✓" : "○")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(task.completed ? .dsGreen : .dsTextMuted)
                        .frame(width: 14, alignment: .center)
                }
                .buttonStyle(.plain)

                // Title — always editable
                if isEditing {
                    TextField("", text: $editingTitle)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.dsAccent)
                        .onSubmit    { onSaveTitle() }
                        .onExitCommand { onCancelEdit() }
                } else {
                    Text(task.title)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(task.completed ? .dsTextDim : .dsText)
                        .strikethrough(task.completed, color: .dsTextDim)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onTapGesture { onTapTitle() }
                }

                // Expand button
                Button { onToggleExpand() } label: {
                    Text("›")
                        .font(.system(size: 15, design: .monospaced))
                        .foregroundColor(isExpanded ? .dsAccent : .dsTextDim)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.easeInOut(duration: 0.15), value: isExpanded)
                }
                .buttonStyle(.plain)
                .opacity(isHovered || isExpanded ? 1 : 0)

                // Delete
                if isHovered && !isEditing {
                    Button { onDelete() } label: {
                        Text("✕")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.dsRed)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical,   6)
            .padding(.horizontal, 5)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(isHovered || isExpanded ? Color.dsSurface : Color.clear)
            )

            // Expanded: notes + history
            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    // Notes
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
                        .frame(minHeight: 54, maxHeight: 90)
                        .onChange(of: notes) { newVal in
                            saveWork?.cancel()
                            let work = DispatchWorkItem { onUpdateNotes(newVal) }
                            saveWork = work
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
                        }

                    // History — only shown if task has carry forward entries
                    if !history.isEmpty {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("── History")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.dsTextDim)

                            // First entry shows original creation date
                            if let first = history.first {
                                historyRow(icon: "◎", label: "Created", date: first.fromDate, color: .dsTextDim)
                            }

                            // Each carry forward
                            ForEach(history) { entry in
                                historyRow(icon: "↩", label: "Carried", date: entry.toDate, color: .dsAmber)
                            }

                            // Completion date if done
                            if task.completed && !task.completedDate.isEmpty {
                                historyRow(icon: "✓", label: "Completed", date: task.completedDate, color: .dsGreen)
                            }
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(.leading, 22)
                .padding(.trailing,  5)
                .padding(.bottom,    6)
                .onAppear {
                    notes   = task.notes
                    history = store.loadHistory(for: task.id)
                }
            }
        }
        .onHover { isHovered = $0 }
        .onChange(of: isEditing) { editing in
            if editing { editingTitle = task.title }
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

// MARK: - Carry Forward Sheet

struct CarryForwardSheet: View {
    @EnvironmentObject var store: TaskStore
    let targetDate: String   // the date we are carrying tasks INTO
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("↩  Carry Forward")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.dsAccent)
                    .tracking(1)
                Spacer()
                Button("✕") { isPresented = false }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.dsTextDim)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Rectangle()
                .fill(Color.dsBorder)
                .frame(height: 1)

            if store.incompleteOldTasks.isEmpty {
                Text("No incomplete tasks from previous days.")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.dsTextDim)
                    .multilineTextAlignment(.center)
                    .padding(24)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(store.incompleteOldTasks, id: \.0) { (date, tasks) in
                            // Date group header
                            Text(formatDateLabel(date))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.dsTextDim)
                                .tracking(0.8)
                                .padding(.horizontal, 14)
                                .padding(.top, 10)
                                .padding(.bottom, 4)

                            ForEach(tasks) { task in
                                CarryForwardRow(task: task, today: targetDate) {
                                    store.carryForward(task: task, toDate: targetDate)
                                }
                            }

                            Rectangle()
                                .fill(Color.dsBorder)
                                .frame(height: 1)
                                .padding(.horizontal, 10)
                                .padding(.top, 6)
                        }
                    }
                    .padding(.bottom, 10)
                }
            }
        }
        .frame(width: 290, height: 380)
        .background(Color.dsBackground.opacity(0.98))
    }
}

// MARK: - CarryForwardRow

struct CarryForwardRow: View {
    let task:       Task
    let today:      String   // targetDate — the date we are carrying into
    let onAdd:      () -> Void

    @State private var added:     Bool = false
    @State private var isHovered: Bool = false

    @EnvironmentObject var store: TaskStore

    var alreadyAdded: Bool {
        store.tasks.contains { $0.title == task.title && $0.date == today }
    }

    var body: some View {
        HStack(spacing: 8) {
            Text("○")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.dsTextDim)
                .frame(width: 14, alignment: .center)

            Text(task.title)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(added || alreadyAdded ? .dsTextDim : .dsText)
                .strikethrough(added || alreadyAdded)
                .frame(maxWidth: .infinity, alignment: .leading)

            if added || alreadyAdded {
                Text("Added")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.dsGreen)
            } else {
                Button {
                    onAdd()
                    added = true
                } label: {
                    Text("+ Add")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.dsAccent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.dsAccentDim)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(Color.dsAccentBorder, lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(isHovered ? Color.dsSurface : Color.clear)
        .onHover { isHovered = $0 }
    }
}