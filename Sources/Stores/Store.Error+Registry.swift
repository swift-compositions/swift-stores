public import Store_Reduction

extension Store.Error {

    init(_ error: Registry.Error) {
        switch error {
        case .stale:
            self = .notMounted

        case .rootOccupied:
            self = .rootAlreadyMounted

        case .nameOccupied(let name):
            self = .nameOccupied(name)
        }
    }
}
