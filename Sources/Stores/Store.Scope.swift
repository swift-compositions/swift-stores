public import Dependencies
public import Store

extension Store {

    public struct Scope: Sendable {
        let apply: @Sendable (inout Dependency.Values) -> Void

        public init(_ apply: @escaping @Sendable (inout Dependency.Values) -> Void) {
            self.apply = apply
        }
    }
}

extension Store.Scope {

    public static var inherited: Self {
        .init { _ in }
    }
}

extension Store.Scope {

    func run<T, E: Swift.Error>(_ operation: () throws(E) -> T) throws(E) -> T {
        try withDependencies(apply, operation: operation)
    }

    func run<T, E: Swift.Error>(
        _ operation: nonisolated(nonsending) () async throws(E) -> T
    ) async throws(E) -> T {
        try await withDependencies(apply, operation: operation)
    }
}
