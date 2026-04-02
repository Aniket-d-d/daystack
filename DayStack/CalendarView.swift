import SwiftUI

struct CalendarView: View {
    @Binding var year:  Int
    @Binding var month: Int

    let today:           String
    let selectedDate:    String
    let incompleteDates: Set<String>
    let onSelectDate:    (String) -> Void

    private let dayNames = ["Mo","Tu","We","Th","Fr","Sa","Su"]

    // MARK: - Computed

    private var monthTitle: String {
        let c = DateComponents(year: year, month: month)
        guard let d = Calendar.current.date(from: c) else { return "" }
        let f = DateFormatter()
        f.dateFormat = "MMMM"
        return f.string(from: d).uppercased()
    }

    private var daysInMonth: Int {
        let c = DateComponents(year: year, month: month)
        guard let d = Calendar.current.date(from: c) else { return 30 }
        return Calendar.current.range(of: .day, in: .month, for: d)?.count ?? 30
    }

    /// Returns leading empty cells (0 = Mon, …, 6 = Sun)
    private var leadingBlanks: Int {
        let c = DateComponents(year: year, month: month, day: 1)
        guard let d = Calendar.current.date(from: c) else { return 0 }
        let wd = Calendar.current.component(.weekday, from: d)  // 1=Sun
        return (wd + 5) % 7   // shift so Mon = 0
    }

    // MARK: - View

    var body: some View {
        VStack(spacing: 0) {
            // Header: ‹ Month Year ›
            HStack {
                navButton("‹") { prevMonth() }
                Spacer()
                Text("\(monthTitle) \(String(year))")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.dsTextMuted)
                    .tracking(1.5)
                Spacer()
                navButton("›") { nextMonth() }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 6)

            // Day-name row + date grid
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7),
                spacing: 2
            ) {
                // Day name headers
                ForEach(dayNames, id: \.self) { name in
                    Text(name)
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundColor(.dsTextDim)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 2)
                }

                // Leading blanks
                ForEach(0..<leadingBlanks, id: \.self) { _ in
                    Color.clear.frame(height: 26)
                }

                // Day cells
                ForEach(1...daysInMonth, id: \.self) { day in
                    dayCell(day: day)
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Day Cell

    @ViewBuilder
    func dayCell(day: Int) -> some View {
        let dateStr = String(format: "%04d-%02d-%02d", year, month, day)
        let isToday = dateStr == today
        let isSel   = dateStr == selectedDate
        let hasDot  = incompleteDates.contains(dateStr)

        Button { onSelectDate(dateStr) } label: {
            ZStack(alignment: .bottom) {
                Text("\(day)")
                    .font(.system(
                        size: 12,
                        weight: (isToday || isSel) ? .bold : .regular,
                        design: .monospaced
                    ))
                    .foregroundColor(
                        isSel   ? .dsAccent :
                        isToday ? .dsAccent :
                        .dsTextMuted
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(isSel ? Color.dsAccentDim : Color.clear)
                    )

                // Red dot = has incomplete tasks
                if hasDot {
                    Circle()
                        .fill(Color.dsRed)
                        .frame(width: 3, height: 3)
                        .padding(.bottom, 2)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Navigation Buttons

    func navButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 17, design: .monospaced))
                .foregroundColor(.dsTextMuted)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.dsBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Month Navigation

    private func prevMonth() {
        var m = month - 1
        var y = year
        if m < 1 { m = 12; y -= 1 }
        month = m; year = y
    }

    private func nextMonth() {
        var m = month + 1
        var y = year
        if m > 12 { m = 1; y += 1 }
        month = m; year = y
    }
}
