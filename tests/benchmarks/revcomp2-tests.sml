structure ReverseComplementTests =
struct
  structure C=RevcompCheck
  fun rejects f=(f();false)handle Fail _=>true
  val _=List.app(fn index=>T.check("revcomp2/source-edge-"^Int.toString index,fn()=>
    let val base="edge-"^Int.toString index
        val count=C.run(base^".input")(base^".output")
        val input=BinIO.openIn(base^".output")val expected=Word8Vector.length(BinIO.inputAll input)
        val _=BinIO.closeIn input
    in count=expected end))(List.tabulate(11,fn i=>i))
  val _=T.check("revcomp2/complete-generated-smoke",fn()=>C.run "smoke.fasta" "smoke.output"=10245)
  val _=T.check("revcomp2/corrupted-output-rejected",fn()=>rejects(fn()=>ignore(C.run "smoke.fasta" "wrong.output")))
  val _=T.check("revcomp2/truncated-output-rejected",fn()=>rejects(fn()=>ignore(C.run "smoke.fasta" "truncated.output")))
  val _=T.check("revcomp2/extra-output-rejected",fn()=>rejects(fn()=>ignore(C.run "smoke.fasta" "extra.output")))
end
