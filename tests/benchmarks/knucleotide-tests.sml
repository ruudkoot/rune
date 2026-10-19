structure KnucleotideTests =
struct
  fun rejects f = (f (); false) handle Fail _ => true
  val _ = List.app (fn i => T.check ("knucleotide/source-edge-" ^ Int.toString i, fn () =>
    let val base = "edge-" ^ Int.toString i val file = BinIO.openIn (base ^ ".output")
        val expected = Word8Vector.length (BinIO.inputAll file) val _ = BinIO.closeIn file
    in KnucleotideCheck.run (base ^ ".fasta") (base ^ ".output") = expected end)) (List.tabulate (8, fn i => i))
  val _ = T.check ("knucleotide/complete-smoke", fn () =>
    let val file = BinIO.openIn "smoke.output" val size = Word8Vector.length (BinIO.inputAll file)
        val _ = BinIO.closeIn file
    in KnucleotideCheck.run "smoke.fasta" "smoke.output" = size end)
  val _ = T.check ("knucleotide/corrupt-rejected", fn () => rejects (fn () => ignore (KnucleotideCheck.run "smoke.fasta" "wrong.output")))
  val _ = T.check ("knucleotide/truncated-rejected", fn () => rejects (fn () => ignore (KnucleotideCheck.run "smoke.fasta" "truncated.output")))
  val _ = T.check ("knucleotide/extra-rejected", fn () => rejects (fn () => ignore (KnucleotideCheck.run "smoke.fasta" "extra.output")))
  val _ = T.check ("knucleotide/missing-header-rejected", fn () =>
    ((ignore (BenchKnucleotide.dna "missing-header.fasta"); false) handle IO.Io _ => true))
  val _ = T.check ("knucleotide/empty-later-line-rejected", fn () =>
    ((ignore (BenchKnucleotide.dna "empty-later-line.fasta"); false) handle Subscript => true))
  fun read path = let val file = TextIO.openIn path val text = TextIO.inputAll file
                  in TextIO.closeIn file; text end
  val _ = T.check ("knucleotide/collisions-resize-and-counts", fn () =>
    let val text = read "resize.dna"
        val dna = CharArray.tabulate (String.size text, fn i => String.sub (text, i))
        val table : BenchKnucleotide.table = {buckets = ref (Array.array (16, BenchKnucleotide.Empty)), size = ref 0}
        val _ = BenchKnucleotide.counts table 4 dna
        val expected = String.tokens (fn c => c = #"\n") (read "resize.counts")
        fun check line = case String.tokens Char.isSpace line of
          [key, count] =>
            let val key = CharArray.tabulate (String.size key, fn i => String.sub (key, i))
            in case (BenchKnucleotide.find table key, Int.fromString count) of
              (SOME actual, SOME n) => !actual = n | _ => false end
        | _ => false
    in !(#size table) = 256 andalso Array.length (!(#buckets table)) = 128 andalso List.all check expected end)
  val _ = T.check ("knucleotide/table-clear", fn () =>
    let val table = BenchKnucleotide.create ()
        val dna = CharArray.tabulate (8, fn i => String.sub ("ACGTACGT", i))
        val _ = BenchKnucleotide.counts table 1 dna
        val _ = BenchKnucleotide.counts table 2 dna
    in !(#size table) = 4 andalso BenchKnucleotide.fold table (fn (_, n, sum) => n + sum) 0 = 7 end)
end
