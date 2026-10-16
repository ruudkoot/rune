structure Packed64 = BenchKnucleotidePackedFn (struct val threshold = 31 end)
structure Packed32 = BenchKnucleotidePackedFn (struct val threshold = 15 end)
structure Check64 = PackedNucleotideCheckFn (Packed64)
structure Check32 = PackedNucleotideCheckFn (Packed32)
structure PackedTests =
struct
  fun read path =
    let val input = TextIO.openIn path val text = TextIO.inputAll input
        val _ = TextIO.closeIn input
    in text end
  val _ = T.check ("packed/full-smoke-64", fn () => Check64.run "smoke.fasta" "smoke.output" > 0)
  val _ = T.check ("packed/full-smoke-32", fn () => Check32.run "smoke.fasta" "smoke.output" > 0)
  val _ = List.app (fn i =>
    let val prefix = "edge-" ^ Int.toString i
    in T.check ("packed/edge-64-" ^ Int.toString i, fn () => Check64.run (prefix ^ ".fasta") (prefix ^ ".output") > 0);
       T.check ("packed/edge-32-" ^ Int.toString i, fn () => Check32.run (prefix ^ ".fasta") (prefix ^ ".output") > 0)
    end) (List.tabulate (8, fn i => i))
  val _ = T.check ("packed/omits-final-window", fn () =>
    let val input = CharArray.tabulate (4, Char.chr)
        val table = Packed64.create ()
        val _ = Packed64.counts table 1 input
    in Packed64.fold table (fn (_, n, total) => n + total) 0 = 3
       andalso not (Option.isSome (Packed64.find table (Packed64.Small 0w3)))
    end)
  val _ = T.check ("packed/cumulative-aliases-64", fn () =>
    let val table = Packed64.create () val input = CharArray.array (20, #"\000")
        val _ = List.app (fn k => Packed64.counts table k input) [1,2,3,4,6,12,18]
    in case Packed64.find table (Packed64.Small 0w0) of SOME count => !count = 94 | NONE => false end)
  val _ = T.check ("packed/cumulative-aliases-32", fn () =>
    let val small = Packed32.create () val large = Packed32.create ()
        val input = CharArray.array (20, #"\000")
        val _ = List.app (fn k => Packed32.counts small k input) [1,2,3,4,6,12]
        val _ = Packed32.counts large 18 input
    in case (Packed32.find small (Packed32.Small 0w0), Packed32.find large (Packed32.Large (0w0,0w0))) of
         (SOME first,SOME second) => !first = 92 andalso !second = 2 | _ => false end)
  val _ = T.check ("packed/leading-zero-length-alias", fn () =>
    Packed64.equal (Packed64.packKey "A", Packed64.packKey "AAAA"))
  val _ = T.check ("packed/64-retains-high-bits", fn () =>
    case Packed64.packKey "GGTATTTTAATTTATAGT" of
      Packed64.Small value => Word64.>> (value, 0w32) <> 0w0 | _ => false)
  val _ = T.check ("packed/32-splits-after-fifteen", fn () =>
    case Packed32.packKey "GGTATTTTAATTTATAGT" of
      Packed32.Large (first, last) =>
        first = (case Packed32.packKey "GGTATTTTAATTTAT" of Packed32.Small x => x | _ => 0w0)
        andalso last = 0w13
    | _ => false)
  val _ = T.check ("packed/pair-hash-uses-first", fn () =>
    Packed32.hash (Packed32.Large (0w123,0w0)) = Packed32.hash (Packed32.Large (0w123,0w456)))
  val _ = T.check ("packed/source-collision-resize-order", fn () =>
    let val table : Packed64.table = {buckets = ref (Array.array (16, Packed64.Empty)), size = ref 0}
        val _ = List.app (fn i => Packed64.add table (Packed64.Small (Word64.fromInt (i * 1048576))))
          (List.tabulate (512, fn i => i))
        val keys = Packed64.fold table (fn (key, _, xs) =>
          case key of Packed64.Small value => Word64.toInt value :: xs | _ => xs) []
        fun join [] = "" | join [x] = Int.toString x | join (x::xs) = Int.toString x ^ " " ^ join xs
        val expected = hd (String.fields (fn c => c = #"\n") (read "packed-observer.output"))
    in join keys = expected andalso Array.length (!(#buckets table)) = 256 end)
  val _ = T.check ("packed/source-every-pass-statistics", fn () =>
    let val input = Packed64.dna "smoke.fasta" val small = Packed64.create () val large = Packed64.create ()
        fun line k =
          let val table = if k <= 31 then small else large
              val _ = Packed64.counts table k input
              val values = [k, !(#size small), !(#size large),
                Packed64.fold small (fn (_,n,t) => n+t) 0,
                Packed64.fold large (fn (_,n,t) => n+t) 0]
              fun join [] = "" | join [x] = Int.toString x | join (x::xs) = Int.toString x ^ " " ^ join xs
          in join values ^ "\n" end
        val actual = String.concat (List.map line [1,2,3,4,6,12,18])
        val text = read "packed-observer.output"
        val expected = String.extract (text, String.size (hd (String.fields (fn c => c = #"\n") text)) + 1, NONE)
    in actual = expected end)
  fun rejects reference = (ignore (Check64.run "smoke.fasta" reference); false)
    handle Fail text => String.isPrefix "incorrect result:" text
  val _ = T.check ("packed/wrong-output-rejected", fn () => rejects "wrong.output")
  val _ = T.check ("packed/truncated-output-rejected", fn () => rejects "truncated.output")
  val _ = T.check ("packed/extra-output-rejected", fn () => rejects "extra.output")
  fun bad path = (ignore (Packed64.dna path); false) handle _ => true
  val _ = T.check ("packed/missing-header-rejected", fn () => bad "missing-header.fasta")
  val _ = T.check ("packed/empty-later-line-rejected", fn () => bad "empty-later-line.fasta")
end
