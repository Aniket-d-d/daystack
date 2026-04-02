import SwiftUI

// MARK: - Task Model

struct Task: Identifiable, Equatable, Hashable {
    let id:         Int64
    var title:      String
    var notes:      String
    var completed:  Bool
    var orderIndex: Int
    var date:       String   // "yyyy-MM-dd"
}

// MARK: - Date Utilities

func todayStr() -> String { dateToStr(Date()) }

func dateToStr(_ d: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: d)
}

func strToDate(_ s: String) -> Date {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    return f.date(from: s) ?? Date()
}

func addDays(_ s: String, _ n: Int) -> String {
    let d = strToDate(s)
    guard let result = Calendar.current.date(byAdding: .day, value: n, to: d) else { return s }
    return dateToStr(result)
}

func formatHeader(_ s: String) -> String {
    let f = DateFormatter()
    f.dateFormat = "EEE · dd MMM yyyy"
    return f.string(from: strToDate(s)).uppercased()
}

func formatDateLabel(_ s: String) -> String {
    let f = DateFormatter()
    f.dateFormat = "EEE, d MMM yyyy"
    return f.string(from: strToDate(s))
}

// MARK: - Color Palette

extension Color {
    static let dsBackground = Color(red: 0.043, green: 0.047, blue: 0.063)
    static let dsSurface    = Color(red: 0.075, green: 0.078, blue: 0.102)
    static let dsInput      = Color(red: 0.055, green: 0.059, blue: 0.079)
    static let dsBorder     = Color.white.opacity(0.06)

    static let dsAccent     = Color(red: 0.133, green: 0.827, blue: 0.933) // cyan
    static let dsAccentDim  = Color(red: 0.133, green: 0.827, blue: 0.933).opacity(0.12)
    static let dsAccentBorder = Color(red: 0.133, green: 0.827, blue: 0.933).opacity(0.35)

    static let dsText       = Color.white
    static let dsTextMuted  = Color.white.opacity(0.82)
    static let dsTextDim    = Color.white.opacity(0.65)

    static let dsGreen      = Color(red: 0.204, green: 0.827, blue: 0.600)
    static let dsRed        = Color(red: 0.973, green: 0.443, blue: 0.443)
}

// MARK: - Shared Button Style

struct DSTinyButton: ButtonStyle {
    var active: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11.5, design: .monospaced))
            .foregroundColor(active ? .dsAccent : .dsTextMuted)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(active ? Color.dsAccentDim : Color.dsSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(
                                active ? Color.dsAccentBorder : Color.dsBorder,
                                lineWidth: 1
                            )
                    )
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}