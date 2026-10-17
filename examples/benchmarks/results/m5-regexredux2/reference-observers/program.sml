structure BenchRegexRedux2 =
struct
  structure R=BenchRegexReduxStr
  val variants=["agggtaaa\\|tttaccct","[cgt]gggtaaa\\|tttaccc[acg]",
    "a[act]ggtaaa\\|tttacc[agt]t","ag[act]gtaaa\\|tttac[agt]ct",
    "agg[act]taaa\\|ttta[agt]cct","aggg[acg]aaa\\|ttt[cgt]ccct",
    "agggt[cgt]aa\\|tt[acg]accct","agggta[cgt]a\\|t[acg]taccct",
    "agggtaa[cgt]\\|[acg]ttaccct"]
  val substitutions=[("tHa[Nt]","<4>"),("aND\\|caN\\|Ha[DS]\\|WaS","<3>"),
    ("a[NSt]\\|BY","<2>"),("<[^>]*>","|"),("|[^|][^|]*|","-")]
  fun displayPattern pattern=String.translate(fn #"\\"=>""|c=>String.str c)pattern
  fun calculate input=
    let val dna=R.replace(R.compile "^>.*$\\|\n")""input
        val rows=List.map(fn pattern=>displayPattern pattern^" "^Int.toString(R.count(R.compile pattern)dna)^"\n")variants
        val after=List.foldl(fn((pattern,replacement),current)=>R.replace(R.compile pattern)replacement current)dna substitutions
    in String.concat rows^"\n"^Int.toString(String.size input)^"\n"^Int.toString(String.size dna)^"\n"^
       Int.toString(String.size after)^"\n"end
  fun read path=let val f=TextIO.openIn path val text=TextIO.inputAll f val _=TextIO.closeIn f in text end
  fun run[input,reference]=
    let val actual=calculate(read input)val expected=read reference
    in if actual=expected then Int.toString(String.size actual)else raise Fail "incorrect result: regexredux output"end
    |run _=raise Fail "expected FASTA input and regexredux reference"
end
