internal import Tree_Keyed

extension Registry {

    enum Error: Swift.Error, Sendable, Equatable {

        case stale

        case rootOccupied

        case nameOccupied(String)
    }
}

extension Registry.Error {

    init(_ error: __TreeKeyedError<String>) {
        switch error {
        case .invalidPosition:
            self = .stale

        case .rootOccupied:
            self = .rootOccupied

        case .keyOccupied(let key):
            self = .nameOccupied(key)

        case .cannotRemoveNonLeaf:
            self = .stale
        }
    }
}
