structure ChecksumBenchTests =
struct
  val _ = T.check ("benchmark.checksum/nonzero-little-endian", fn () =>
    let val input = Word8Array.tabulate (8, fn i => Word8.fromInt (i + 1))
    in Benchmark.checksum (input, 0, 1) = 0wx1410 end)
  val _ = T.check ("benchmark.checksum/packed-word-boundaries", fn () =>
    let val input = Word8Array.tabulate (256, Word8.fromInt)
        fun sum (i, result) = if i = 256 then result else
          sum (i + 2, Word32.+ (result, Word32.fromInt (i + 256 * (i + 1))))
    in Benchmark.checksum (input, 0, 63) = sum (0, 0w0) end)
  val _ = T.check ("benchmark.checksum/modular-addition", fn () =>
    Benchmark.checkOne (0wxFFFFFFFF, 0wxFFFE0002) = 0w0)
end
