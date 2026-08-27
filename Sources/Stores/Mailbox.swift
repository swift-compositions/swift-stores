internal import Deque
internal import Queue_Primitive

struct Mailbox<Element: Sendable>: ~Copyable {
    private var storage: Queue<Element>.DoubleEnded

    init() {
        self.storage = Queue<Element>.DoubleEnded()
    }
}

extension Mailbox {

    var isEmpty: Bool {
        storage.isEmpty
    }

    mutating func post(_ element: consuming Element) {
        storage.push(element, to: .back)
    }

    mutating func next() -> Element? {
        storage.pop(from: .front)
    }
}
