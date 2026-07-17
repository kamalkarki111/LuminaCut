import Foundation

final class HistoryManager: ObservableObject {
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false

    private var undoStack: [VideoProject] = []
    private var redoStack: [VideoProject] = []
    private let maxDepth = 60

    func push(_ project: VideoProject) {
        if undoStack.last == project { return }
        undoStack.append(project)
        if undoStack.count > maxDepth {
            undoStack.removeFirst(undoStack.count - maxDepth)
        }
        redoStack.removeAll()
        update()
    }

    func undo(current: VideoProject) -> VideoProject? {
        guard let prev = undoStack.popLast() else { return nil }
        redoStack.append(current)
        update()
        return prev
    }

    func redo(current: VideoProject) -> VideoProject? {
        guard let next = redoStack.popLast() else { return nil }
        undoStack.append(current)
        update()
        return next
    }

    func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
        update()
    }

    private func update() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }
}
