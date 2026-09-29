public import Store

extension Store.Work {

    struct Record: Sendable {
        let cancellation: Store.Cancellation.ID?
        let task: Task<Void, Never>
    }
}
