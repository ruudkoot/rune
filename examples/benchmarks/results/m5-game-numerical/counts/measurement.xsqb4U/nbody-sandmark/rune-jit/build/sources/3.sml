structure BenchRecordNBodyCheck =
struct
  structure N=BenchRecordNBody
  fun values path=
    let val input=TextIO.openIn path val text=TextIO.inputAll input
    in TextIO.closeIn input;List.map(fn s=>case Real.fromString s of
      SOME r=>r|NONE=>raise Fail "invalid nbody reference")
      (String.tokens Char.isSpace text)end
  fun matches absolute relative actual expected=
    List.length actual=37 andalso List.length expected=37 andalso
    ListPair.allEq(fn(a,b)=>BenchInput.closeReal(a,b,absolute,relative))(actual,expected)
  fun run steps path absolute relative=
    let val bodies=N.initial()val _=N.offset bodies val first=N.energy bodies
        val _=N.for 1 steps(fn _=>N.advance bodies 0.01)
        val actual=first::N.energy bodies::N.state bodies
        val expected=values path
    in if matches absolute relative actual expected then()
       else raise Fail "incorrect result: complete nbody state differs"end
end
