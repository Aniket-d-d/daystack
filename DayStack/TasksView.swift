import SwiftUI

// MARK: - TasksView

struct TasksView: View {
    @EnvironmentObject var store:  TaskStore
    let selectedDate: String
    let today:        String

    @State private var editingId:    Int64? = nil
    @State private var editingTitle: String = ""
    @State private var expandedId:   Int64? = nil
    @State private var isAdding:     Bool   = false
    @State private var newTitle:     String = ""
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

            // Scrollable task list
            List {
                ForEach(store.tasks) { task in
                    TaskRowView(
                        task:         task,
                        isPast:       isPast,
                        isExpanded:   expandedId == task.id,
                        isEditing:    editingId  == task.id,
                        editingTitle: editingId  == task.id ? $editingTitle : .constant(""),
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

                // Empty state
                if store.tasks.isEmpty {
                    Text(isPast ? "Nothing recorded." : "No tasks yet.")
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

            // Add task area — only for today and future
            if !isPast {
                Rectangle()
                    .fill(Color.dsBorder)
                    .frame(height: 1)
                    .padding(.horizontal, 8)

                if isAdding {
                    addTaskField
                } else {
                    addTaskButton
                }
            }
        }
        .onAppear {
            store.loadTasks(for: selectedDate)
        }
    }

    // MARK: - Add Task UI

    var addTaskButton: some View {
        Button {
            isAdding  = true
            newTitle  = ""
            addFieldFocused = true
        } label: {
            HStack {
                Spacer()
                Text("+ Add Task")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.dsTextDim)
                    .tracking(0.5)
                Spacer()
            }
            .padding(.vertical, 7)
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(
                        Color.dsTextDim,
                        style: StrokeStyle(lineWidth: 1, dash: [4])
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
                .onSubmit   { commitNew() }
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
        var t = task; t.completed.toggle()
        store.updateTask(t)
    }

    func startEdit(_ task: Task) {
        guard !isPast else { return }
        editingId    = task.id
        editingTitle = task.title
    }

    func saveTitle(_ task: Task) {
        let v = editingTitle.trimmingCharacters(in: .whitespaces)
        if !v.isEmpty {
            var t = task; t.title = v
            store.updateTask(t)
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
    let isPast:       Bool
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

    @State private var isHovered: Bool             = false
    @State private var notes:     String           = ""
    @State private var saveWork:  DispatchWorkItem? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            HStack(spacing: 5) {
                // Check / uncheck
                Button { onToggle() } label: {
                    Text(task.completed ? "✓" : "○")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(task.completed ? .dsGreen : .dsTextMuted)
                        .frame(width: 14, alignment: .center)
                }
                .buttonStyle(.plain)

                // Title — TextField when editing, Text otherwise
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

                // Expand (notes) button
                Button { onToggleExpand() } label: {
                    Text("›")
                        .font(.system(size: 15, design: .monospaced))
                        .foregroundColor(isExpanded ? .dsAccent : .dsTextDim)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.easeInOut(duration: 0.15), value: isExpanded)
                }
                .buttonStyle(.plain)
                .opacity(isHovered || isExpanded ? 1 : 0)

                // Delete (on hover, not while editing)
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

            // Notes text area (expanded)
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
                    .padding(.leading, 26)
                    .padding(.trailing,  5)
                    .padding(.bottom,    6)
                    .onAppear {
                        notes = task.notes
                    }
                    .onChange(of: notes) { newVal in
                        // Debounce: save 1s after last keystroke
                        saveWork?.cancel()
                        let work = DispatchWorkItem { onUpdateNotes(newVal) }
                        saveWork = work
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
                    }
            }
        }
        .onHover { isHovered = $0 }
        // Sync local title state when editing starts
        .onChange(of: isEditing) { editing in
            if editing { editingTitle = task.title }
        }
    }
}