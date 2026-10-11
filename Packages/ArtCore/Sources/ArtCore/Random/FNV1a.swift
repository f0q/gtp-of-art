/// FNV-1a 64-bit hash over the UTF-8 bytes of `string`.
///
/// `h = 0xCBF29CE484222325; for byte in utf8 { h = (h XOR byte) × 0x100000001B3 mod 2^64 }`.
public func fnv1a64(_ string: String) -> UInt64 {
    fnv1a64(bytes: string.utf8)
}

/// FNV-1a 64-bit hash over an arbitrary byte sequence.
public func fnv1a64<S: Sequence>(bytes: S) -> UInt64 where S.Element == UInt8 {
    var hash: UInt64 = 0xCBF2_9CE4_8422_2325
    for byte in bytes {
        hash ^= UInt64(byte)
        hash &*= 0x0000_0100_0000_01B3
    }
    return hash
}
