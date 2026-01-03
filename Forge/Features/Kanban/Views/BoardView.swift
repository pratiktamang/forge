import SwiftUI

// Type alias to disambiguate Swift's Task from our Task model
private typealias AsyncTask = _Concurrency.Task

struct BoardView: View {
    @StateObject private var viewModel: BoardViewModel
    @State private var isAddingColumn = false
    @State private var newColumnTitle = ""
    @State private var expandedColumnIndex = 1 // Default to second column (To Do)

    init(boardId: String) {
        _viewModel = StateObject(wrappedValue: BoardViewModel(boardId: boardId))
    }

    private var leftColumns: [BoardColumn] {
        guard expandedColumnIndex > 0 else { return [] }
        return Array(viewModel.columns.prefix(expandedColumnIndex))
    }

    private var expandedColumn: BoardColumn? {
        guard !viewModel.columns.isEmpty,
              expandedColumnIndex >= 0,
              expandedColumnIndex < viewModel.columns.count else { return nil }
        return viewModel.columns[expandedColumnIndex]
    }

    private var rightColumns: [BoardColumn] {
        guard expandedColumnIndex < viewModel.columns.count - 1 else { return [] }
        return Array(viewModel.columns.suffix(from: expandedColumnIndex + 1))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Board header
            boardHeader

            // Columns
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.columns.isEmpty {
                emptyState
            } else {
                columnsView
            }
        }
        .background(AppTheme.contentBackground)
        .onAppear {
            viewModel.startObserving()
        }
        .onDisappear {
            viewModel.stopObserving()
        }
    }

    // MARK: - Board Header

    private var boardHeader: some View {
        HStack {
            if let board = viewModel.board {
                Text(board.title)
                    .font(.headline)
            }

            Spacer()

            // Current column name
            if let column = expandedColumn {
                Text(column.title.uppercased())
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: { isAddingColumn = true }) {
                Label("Add Column", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .popover(isPresented: $isAddingColumn) {
                addColumnPopover
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Columns View

    private var columnsView: some View {
        HStack(alignment: .top, spacing: 0) {
            // Left collapsed columns
            HStack(spacing: 8) {
                ForEach(Array(leftColumns.enumerated()), id: \.element.id) { index, column in
                    collapsedColumnTab(column: column, index: index)
                }
            }
            .padding(.leading, 16)

            Spacer(minLength: 16)

            // Expanded column in center
            if let column = expandedColumn {
                expandedColumnView(column: column)
                    .frame(maxWidth: 600)
            }

            Spacer(minLength: 16)

            // Right collapsed columns
            HStack(spacing: 8) {
                ForEach(Array(rightColumns.enumerated()), id: \.element.id) { index, column in
                    let actualIndex = expandedColumnIndex + 1 + index
                    collapsedColumnTab(column: column, index: actualIndex)
                }
            }
            .padding(.trailing, 16)
        }
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private func collapsedColumnTab(column: BoardColumn, index: Int) -> some View {
        let taskCount = viewModel.tasks(for: column).count
        let color = column.color.flatMap { Color(hex: $0) } ?? .secondary

        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                expandedColumnIndex = index
            }
        }) {
            VStack(spacing: 8) {
                // Task count badge
                Text("\(taskCount)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(color)
                    )

                // Vertical column name
                Text(column.title.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(-90))
                    .fixedSize()
                    .frame(width: 20)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.secondary.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func expandedColumnView(column: BoardColumn) -> some View {
        BoardColumnView(
            column: column,
            tasks: viewModel.tasks(for: column),
            isOverWipLimit: viewModel.isOverWipLimit(column: column),
            onAddTask: { title in
                AsyncTask { await viewModel.addTask(title: title, to: column) }
            },
            onMoveTask: { taskId in
                AsyncTask { await viewModel.moveTask(taskId, to: column) }
            },
            onDeleteColumn: {
                AsyncTask { await viewModel.deleteColumn(column) }
            },
            onUpdateColumn: { updated in
                AsyncTask { await viewModel.updateColumn(updated) }
            }
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.3.group")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No columns yet")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Add columns to organize your tasks")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button(action: { isAddingColumn = true }) {
                Label("Add Column", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Add Column

    private var addColumnButton: some View {
        Button(action: { isAddingColumn = true }) {
            VStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.title2)
                Text("Add Column")
                    .font(.caption)
            }
            .foregroundColor(.secondary)
            .frame(width: 250, height: 100)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    private var addColumnPopover: some View {
        VStack(spacing: 12) {
            Text("Add Column")
                .font(.headline)

            TextField("Column name", text: $newColumnTitle)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") {
                    isAddingColumn = false
                    newColumnTitle = ""
                }

                Button("Add") {
                    guard !newColumnTitle.isEmpty else { return }
                    AsyncTask {
                        await viewModel.addColumn(title: newColumnTitle)
                        newColumnTitle = ""
                        isAddingColumn = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(newColumnTitle.isEmpty)
            }
        }
        .padding()
        .frame(width: 250)
    }
}

// MARK: - Preview

#Preview {
    BoardView(boardId: "preview")
}
