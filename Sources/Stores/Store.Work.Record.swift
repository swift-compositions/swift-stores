public import Store_Reduction

extension Store.Work {

    struct Record: Sendable {
        let cancellation: Store.Cancellation.ID?
        let task: Task<Void, Never>
    }
}
