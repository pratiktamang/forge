import SwiftUI

private typealias AsyncTask = _Concurrency.Task

struct PerspectiveEditorSheet: View {
    @StateObject private var viewModel: PerspectiveEditorViewModel
    @Environment(\.dismiss) private var dismiss

    init(perspective: Perspective? = nil) {
        _viewModel = StateObject(wrappedValue: PerspectiveEditorViewModel(perspective: perspective))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    basicInfoSection
                    filterSection
                    sortSection
                }
                .padding()
            }

            Divider()

            // Footer
            footer
        }
        .frame(width: 450, height: 600)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text(viewModel.isEditing ? "Edit Perspective" : "New Perspective")
                .font(.headline)
            Spacer()
        }
        .padding()
    }

    // MARK: - Basic Info

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Basic Info")
                .font(.headline)

            TextField("Title", text: $viewModel.title)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 16) {
                // Icon picker
                VStack(alignment: .leading, spacing: 4) {
                    Text("Icon")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    iconPicker
                }

                // Color picker
                VStack(alignment: .leading, spacing: 4) {
                    Text("Color")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    colorPicker
                }
            }
        }
    }

    private var iconPicker: some View {
        let icons = [
            "line.3.horizontal.decrease.circle",
            "star.fill",
            "flag.fill",
            "calendar.badge.clock",
            "exclamationmark.circle.fill",
            "person.fill.questionmark",
            "moon.stars.fill",
            "bolt.fill",
            "flame.fill",
            "target"
        ]

        return HStack(spacing: 8) {
            ForEach(icons, id: \.self) { icon in
                Button(action: { viewModel.icon = icon }) {
                    Image(systemName: icon)
                        .foregroundColor(viewModel.icon == icon ? .accentColor : .secondary)
                        .frame(width: 28, height: 28)
                        .background(viewModel.icon == icon ? Color.accentColor.opacity(0.1) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var colorPicker: some View {
        let colors = ["#EF4444", "#F59E0B", "#22C55E", "#3B82F6", "#8B5CF6", "#EC4899"]

        return HStack(spacing: 8) {
            ForEach(colors, id: \.self) { color in
                Button(action: { viewModel.color = color }) {
                    Circle()
                        .fill(Color(hex: color))
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(Color.primary, lineWidth: viewModel.color == color ? 2 : 0)
                        )
                }
                .buttonStyle(.plain)
            }

            // Clear color button
            Button(action: { viewModel.color = "" }) {
                Circle()
                    .stroke(Color.secondary, style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Image(systemName: "xmark")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Filters

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Filters")
                .font(.headline)

            // Status filter
            VStack(alignment: .leading, spacing: 8) {
                Text("Status")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                FlowLayout(spacing: 8) {
                    ForEach(TaskStatus.allCases.filter { $0 != .completed && $0 != .cancelled }, id: \.self) { status in
                        FilterChip(
                            label: status.displayName,
                            isSelected: viewModel.selectedStatuses.contains(status),
                            action: {
                                if viewModel.selectedStatuses.contains(status) {
                                    viewModel.selectedStatuses.remove(status)
                                } else {
                                    viewModel.selectedStatuses.insert(status)
                                }
                            }
                        )
                    }
                }
            }

            // Due date filter
            VStack(alignment: .leading, spacing: 8) {
                Text("Due Date")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                FlowLayout(spacing: 8) {
                    ForEach(DateRangeFilter.allCases, id: \.self) { range in
                        FilterChip(
                            label: range.displayName,
                            isSelected: viewModel.dueDateRange == range,
                            action: {
                                viewModel.dueDateRange = viewModel.dueDateRange == range ? nil : range
                            }
                        )
                    }
                }
            }

            // Flagged filter
            Toggle("Flagged only", isOn: Binding(
                get: { viewModel.isFlagged == true },
                set: { viewModel.isFlagged = $0 ? true : nil }
            ))

            // Show completed
            Toggle("Show completed tasks", isOn: $viewModel.showCompleted)
        }
    }

    // MARK: - Sort

    private var sortSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sort")
                .font(.headline)

            Picker("Sort by", selection: $viewModel.sortBy) {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.menu)

            Picker("Order", selection: $viewModel.sortAscending) {
                Text("Ascending").tag(true)
                Text("Descending").tag(false)
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.plain)

            Spacer()

            Button(viewModel.isEditing ? "Save" : "Create") {
                AsyncTask {
                    if await viewModel.save() {
                        dismiss()
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.title.isEmpty || viewModel.isSaving)
        }
        .padding()
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let label: String
    var color: Color = .accentColor
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? color.opacity(0.2) : Color.secondary.opacity(0.1))
                .foregroundColor(isSelected ? color : .secondary)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? color : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)

        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var positions: [CGPoint] = []
        var size: CGSize = .zero

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: currentX, y: currentY))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
                self.size.width = max(self.size.width, currentX)
            }

            self.size.height = currentY + lineHeight
        }
    }
}

// MARK: - Preview

#Preview {
    PerspectiveEditorSheet()
}
