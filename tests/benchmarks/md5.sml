structure MD5BenchTests =
struct
  val vectors = [
    ("", "d41d8cd98f00b204e9800998ecf8427e"),
    ("a", "0cc175b9c0f1b6a831c399e269772661"),
    ("abc", "900150983cd24fb0d6963f7d28e17f72"),
    ("message digest", "f96b697d7cb7938d525a2f31aaf161d0"),
    ("abcdefghijklmnopqrstuvwxyz", "c3fcd3d76192e4007dfb496cca67e13b"),
    ("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789", "d174ab98d277d9f5a5611c2c9f419d9f"),
    ("12345678901234567890123456789012345678901234567890123456789012345678901234567890", "57edf4a22be3c955ac49da2e2107b67a")]
  val _ = List.app (fn (text, digest) => T.check ("benchmark.md5/RFC1321", fn () =>
    MD5.toHexString (MD5.final (MD5.update (MD5.init, Byte.stringToBytes text))) = digest)) vectors
  val _ = T.check ("benchmark.md5/block-boundary", fn () =>
    let val text = Word8Vector.tabulate (65, Word8.fromInt)
        val once = MD5.update (MD5.init, text)
        val split = MD5.update (MD5.update (MD5.init, Word8VectorSlice.vector (Word8VectorSlice.slice(text,0,SOME 64))),
                               Word8VectorSlice.vector (Word8VectorSlice.slice(text,64,NONE)))
    in MD5.toHexString (MD5.final once) = MD5.toHexString (MD5.final split) end)
end
