/// Platform-neutral string ordering: lexicographic comparison of UTF-8 bytes.
///
/// Swift's `<` on `String` uses Unicode canonical ordering and Kotlin's uses UTF-16 code units;
/// both agree with byte order for ASCII slugs, but every sort that feeds selection uses this
/// function so the order is defined independently of either platform.
@inlinable
public func utf8Less(_ a: String, _ b: String) -> Bool {
    a.utf8.lexicographicallyPrecedes(b.utf8)
}
