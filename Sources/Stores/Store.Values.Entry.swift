public import Store_Reduction

extension Store.Values {

    struct Entry: Sendable {
        let identity: ObjectIdentifier

        let value: any Sendable
    }
}
