import SwiftUI

private typealias AsyncTask = _Concurrency.Task

struct HabitListView: View {
    @StateObject private var viewModel = HabitListViewModel()
    @EnvironmentObject var appState: AppState
    @State private var isAddingHabit = false

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.habits.isEmpty && !viewModel.isLoading {
                emptyState
            } else {
                VStack(spacing: 0) {
                    // Today's progress header
                    todayProgressHeader

                    Divider()

                    // Habit list
                    habitList
                }
            }
        }
        .navigationTitle("Habits")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { isAddingHabit = true }) {
                    Image(systemName: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        .sheet(isPresented: $isAddingHabit) {
            AddHabitSheet(viewModel: viewModel)
        }
        .onAppear {
            viewModel.startObserving()
        }
        .onDisappear {
            viewModel.stopObserving()
        }
    }

    // MARK: - Progress Header

    private var todayProgressHeader: some View {
        VStack(spacing: 12) {
            Text("Today")
                .font(.headline)
                .foregroundColor(.secondary)

            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 10)

                // Progress ring
                Circle()
                    .trim(from: 0, to: viewModel.todayProgress)
                    .stroke(
                        progressColor,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: viewModel.todayProgress)

                // Center text
                VStack(spacing: 2) {
                    Text("\(viewModel.todayCompletionCount)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    Text("of \(viewModel.habitsDueToday.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 100, height: 100)

            if viewModel.todayCompletionCount == viewModel.habitsDueToday.count && !viewModel.habitsDueToday.isEmpty {
                Label("All done!", systemImage: "checkmark.seal.fill")
                    .font(.subheadline)
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var progressColor: Color {
        if viewModel.todayProgress >= 1.0 {
            return .green
        } else if viewModel.todayProgress >= 0.5 {
            return .accentColor
        } else {
            return .orange
        }
    }

    // MARK: - Habit List

    private var habitList: some View {
        List(selection: $appState.selectedHabitId) {
            // Due Today section
            if !viewModel.habitsDueToday.isEmpty {
                Section("Due Today") {
                    ForEach(viewModel.habitsDueToday) { habit in
                        HabitRowView(
                            habit: habit,
                            isCompletedToday: viewModel.todayCompletions.contains(habit.id),
                            currentStreak: viewModel.streakInfo[habit.id]?.currentStreak ?? 0,
                            onToggleComplete: {
                                AsyncTask { await viewModel.toggleCompletion(habit: habit) }
                            }
                        )
                        .tag(habit.id)
                        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                    }
                    .onDelete { offsets in
                        deleteHabits(from: viewModel.habitsDueToday, at: offsets)
                    }
                }
            }

            // Not Due Today section
            if !viewModel.habitsNotDueToday.isEmpty {
                Section("Not Due Today") {
                    ForEach(viewModel.habitsNotDueToday) { habit in
                        HabitRowView(
                            habit: habit,
                            isCompletedToday: viewModel.todayCompletions.contains(habit.id),
                            currentStreak: viewModel.streakInfo[habit.id]?.currentStreak ?? 0,
                            onToggleComplete: {
                                AsyncTask { await viewModel.toggleCompletion(habit: habit) }
                            }
                        )
                        .tag(habit.id)
                        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                        .opacity(0.6)
                    }
                    .onDelete { offsets in
                        deleteHabits(from: viewModel.habitsNotDueToday, at: offsets)
                    }
                }
            }
        }
        .listStyle(.inset)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No habits yet")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Build positive routines by tracking\nyour daily habits")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: { isAddingHabit = true }) {
                Label("Create Habit", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func deleteHabits(from habits: [Habit], at offsets: IndexSet) {
        for index in offsets {
            let habit = habits[index]
            AsyncTask {
                await viewModel.deleteHabit(habit)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    HabitListView()
        .environmentObject(AppState())
}
