import SwiftUI

private typealias AsyncTask = _Concurrency.Task

struct AddHabitSheet: View {
    @ObservedObject var viewModel: HabitListViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var frequencyType: FrequencyType = .daily
    @State private var selectedDays: Set<Int> = [2, 3, 4, 5, 6] // Mon-Fri by default
    @State private var selectedColor: String = "3B82F6"
    @State private var selectedIcon: String = "checkmark.circle"

    private let availableColors = [
        "3B82F6", // Blue
        "10B981", // Green
        "F59E0B", // Amber
        "EF4444", // Red
        "8B5CF6", // Purple
        "EC4899", // Pink
        "06B6D4", // Cyan
        "F97316", // Orange
    ]

    private let availableIcons = [
        "checkmark.circle",
        "star.fill",
        "heart.fill",
        "flame.fill",
        "bolt.fill",
        "moon.fill",
        "sun.max.fill",
        "drop.fill",
        "leaf.fill",
        "book.fill",
        "pencil",
        "brain.head.profile",
        "figure.run",
        "figure.walk",
        "dumbbell.fill",
        "cup.and.saucer.fill",
        "bed.double.fill",
        "pills.fill",
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Text("New Habit")
                    .font(.headline)

                Spacer()

                Button("Create") { createHabit() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(title.isEmpty)
            }
            .padding()

            Divider()

            // Form content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Title
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        TextField("Habit name", text: $title)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description (optional)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        TextField("Add a description...", text: $description, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...4)
                    }

                    // Frequency
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Frequency")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Picker("Frequency", selection: $frequencyType) {
                            Text("Daily").tag(FrequencyType.daily)
                            Text("Weekly").tag(FrequencyType.weekly)
                            Text("Custom").tag(FrequencyType.custom)
                        }
                        .pickerStyle(.segmented)

                        if frequencyType != .daily {
                            dayPicker
                        }
                    }

                    // Icon
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Icon")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        iconPicker
                    }

                    // Color
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Color")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        colorPicker
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 420, height: 550)
    }

    // MARK: - Day Picker

    private var dayPicker: some View {
        HStack(spacing: 8) {
            ForEach(1...7, id: \.self) { day in
                let isSelected = selectedDays.contains(day)
                Button(action: {
                    if isSelected {
                        selectedDays.remove(day)
                    } else {
                        selectedDays.insert(day)
                    }
                }) {
                    Text(shortDayName(for: day))
                        .font(.caption.weight(.medium))
                        .frame(width: 36, height: 36)
                        .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.2))
                        .foregroundColor(isSelected ? .white : .primary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Icon Picker

    private var iconPicker: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
            ForEach(availableIcons, id: \.self) { icon in
                let isSelected = selectedIcon == icon
                Button(action: { selectedIcon = icon }) {
                    Image(systemName: icon)
                        .font(.title3)
                        .frame(width: 40, height: 40)
                        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                        .foregroundColor(isSelected ? Color(hex: selectedColor) : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Color Picker

    private var colorPicker: some View {
        HStack(spacing: 12) {
            ForEach(availableColors, id: \.self) { color in
                let isSelected = selectedColor == color
                Button(action: { selectedColor = color }) {
                    Circle()
                        .fill(Color(hex: color))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle()
                                .stroke(Color.primary, lineWidth: isSelected ? 3 : 0)
                                .padding(isSelected ? -3 : 0)
                        )
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                                .opacity(isSelected ? 1 : 0)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

    private func shortDayName(for weekday: Int) -> String {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        let index = weekday - 1
        guard index >= 0 && index < symbols.count else { return "?" }
        return symbols[index]
    }

    private func createHabit() {
        guard !title.isEmpty else { return }

        let frequencyDays: [Int]? = frequencyType == .daily ? nil : Array(selectedDays).sorted()

        AsyncTask {
            await viewModel.createHabit(
                title: title,
                description: description.isEmpty ? nil : description,
                frequencyType: frequencyType,
                frequencyDays: frequencyDays,
                color: selectedColor,
                icon: selectedIcon
            )
            dismiss()
        }
    }
}

// MARK: - Preview

#Preview {
    AddHabitSheet(viewModel: HabitListViewModel())
}
