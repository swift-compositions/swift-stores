extension Registry {

    enum Error: Swift.Error, Sendable, Equatable {

        case stale

        case rootOccupied

        case nameOccupied(String)
    }
}
