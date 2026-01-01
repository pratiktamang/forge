import SwiftUI

struct BoardView: View {
    @StateObject private var viewModel: BoardViewModel
    @State private var isAddingColumn = false
    @State private var newColumnTitle = ""

    init(boardId: String) {
        _viewModel = StateObject(wrappedValue: BoardViewModel(boardId: boardId))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Board header
            boardHeader

            Divider()

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
        .background(Color(nsColor: .windowBackgroundColor))
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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(viewModel.columns) { column in
                    BoardColumnView(
                        column: column,
                        tasks: viewModel.tasks(for: column),
                        isOverWipLimit: viewModel.isOverWipLimit(column: column),
                        onAddTask: { title in
                            Task { await viewModel.addTask(title: title, to: column) }
                        },
                        onMoveTask: { taskId in
                            Task { await viewModel.moveTask(taskId, to: column) }
                        },
                        onDeleteColumn: {
                            Task { await viewModel.deleteColumn(column) }
                        },
                        onUpdateColumn: { updated in
                            Task { await viewModel.updateColumn(updated) }
                        }
                    )
                }

                // Add column button at end
                addColumnButton
            }
            .padding(16)
        }
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
                    Task {
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
