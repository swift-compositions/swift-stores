internal import Tree_Keyed

extension Registry {

    struct Handle: Hashable, Sendable {

        let position: __TreePosition

        init(_ position: __TreePosition) {
            self.position = position
        }
    }
}
