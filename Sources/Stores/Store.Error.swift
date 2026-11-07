public import Store

extension Store {

    public enum Error: Swift.Error, Sendable, Equatable {

        case notMounted

        case rootAlreadyMounted

        case nameOccupied(String)
    }
}

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
