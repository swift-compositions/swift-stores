public import Store_Reduction

extension Store {

    public enum Error: Swift.Error, Sendable, Equatable {

        case notMounted

        case rootAlreadyMounted

        case nameOccupied(String)
    }
}
