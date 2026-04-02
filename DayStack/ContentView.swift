import SwiftUI

// MARK: - View States

enum DSView { case tasks, calendar, all }

// MARK: - ContentView

struct ContentView: View {
    @EnvironmentObject var store: TaskStore

    @State private var selectedDate     = todayStr()
    @State private var today            = todayStr()
    @State private var currentView: DSView = .tasks
    @State private var calYear          = Calendar.current.component(.year,  from: Date())
    @State private var calMonth         = Calendar.current.component(.month, from: Date())
    @State private var incompleteDates  = Set<String>()

    var body: some View {
        ZStack {
            // Glass background
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dsBackground.opacity(0.88))
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.dsBorder, lineWidth: 1)

            VStack(spacing: 0) {
                // Top cyan accent line
                LinearGradient(
                    colors: [.clear, Color.dsAccent.opacity(0.5), .clear],
                    startPoint: .leading,
                    endPoint:   .trailing
                )
                .frame(height: 1)

                // Navigation bar
                topBar
                    .padding(.horizontal, 8)
                    .padding(.top, 6)

                // Divider
                Rectangle()
                    .fill(Color.dsBorder)
                    .frame(height: 1)
                    .padding(.horizontal, 8)
                    .padding(.top, 6)

                // Routed content
                Group {
                    switch currentView {
                    case .tasks:
                        TasksView(selectedDate: selectedDate, today: today)
                            .id(selectedDate)  // reset state when date changes

                    case .calendar:
                        CalendarView(
                            year:            $calYear,
                            month:           $calMonth,
                            today:           today,
                            selectedDate:    selectedDate,
                            incompleteDates: incompleteDates
                        ) { date in
                            selectedDate = date
                            currentView  = .tasks
                            store.loadTasks(for: date)
                        }

                    case .all:
                        AllTasksView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 220, maxWidth: .infinity, minHeight: 300, maxHeight: .infinity)
        .onAppear {
            store.loadTasks(for: selectedDate)
        }
        // Right-click → Quit
        .contextMenu {
            Button("Quit DayStack") { NSApp.terminate(nil) }
        }
        // Midnight refresh — check every 60s
        .onReceive(
            Timer.publish(every: 60, on: .main, in: .common).autoconnect()
        ) { _ in
            let newToday = todayStr()
            if newToday != today { today = newToday }
        }
        // Reload incomplete dots when calendar month changes
        .onChange(of: calYear)  { _ in reloadDots() }
        .onChange(of: calMonth) { _ in reloadDots() }
    }

    // MARK: - Top Bar

    @ViewBuilder
    var topBar: some View {
        if currentView == .all {
            HStack(spacing: 8) {
                Button("← Back") {
                    currentView = .tasks
                }
                .buttonStyle(DSTinyButton())

                Text("All Tasks")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.dsTextMuted)
                    .textCase(.uppercase)
                    .tracking(2)

                Spacer()
            }
        } else {
            HStack(spacing: 4) {
                // Month / close calendar button
                Button(currentView == .calendar ? "✕" : "Month") {
                    if currentView == .calendar {
                        currentView = .tasks
                    } else {
                        reloadDots()
                        currentView = .calendar
                    }
                }
                .buttonStyle(DSTinyButton(active: currentView == .calendar))

                // Week strip
                weekStrip

                // All Tasks button
                Button("All") {
                    store.loadAllTasks()
                    currentView = .all
                }
                .buttonStyle(DSTinyButton())
            }
        }
    }

    // MARK: - Week Strip

    var weekStrip: some View {
        HStack(spacing: 1) {
            ForEach(-3...3, id: \.self) { offset in
                weekDayCell(offset: offset)
            }
        }
    }

    @ViewBuilder
    func weekDayCell(offset: Int) -> some View {
        let date    = addDays(today, offset)
        let d       = strToDate(date)
        let cal     = Calendar.current
        let dayNum  = cal.component(.day,     from: d)
        let wdIdx   = cal.component(.weekday, from: d) - 1  // 0=Sun
        let names   = ["Su","Mo","Tu","We","Th","Fr","Sa"]
        let dayName = names[wdIdx]
        let isToday = date == today
        let isSel   = date == selectedDate && currentView == .tasks

        Button {
            selectedDate = date
            currentView  = .tasks
            store.loadTasks(for: date)
        } label: {
            VStack(spacing: 2) {
                Text(dayName)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(isToday || isSel ? .dsAccent : .dsTextDim)
                    .tracking(0.5)

                Text("\(dayNum)")
                    .font(.system(
                        size: 12,
                        weight: isSel ? .bold : .regular,
                        design: .monospaced
                    ))
                    .foregroundColor(isToday || isSel ? .dsAccent : .dsTextMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isSel ? Color.dsAccentDim : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func reloadDots() {
        incompleteDates = store.incompleteDates(year: calYear, month: calMonth)
    }
}