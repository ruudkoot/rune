structure BenchManyBodyCheck =
struct
  fun read path =
    let val input=TextIO.openIn path val text=TextIO.inputAll input val _=TextIO.closeIn input
    in List.map(fn token=>case Real.fromString token of SOME x=>x
      | NONE=>raise Fail "invalid many-body reference")(String.tokens Char.isSpace text)end
  fun matches count actual expected =
    List.length actual=2+7*count andalso List.length expected=2+7*count andalso
    ListPair.allEq(fn(a,b)=>BenchInput.closeReal(a,b,1.0E~9,1.0E~11))(actual,expected)
  fun run [stepsText,countText,path] =
    let val steps=BenchInput.between(0,500)(BenchInput.integer stepsText)
        val count=BenchInput.between(1,1024)(BenchInput.integer countText)
        val expected=read path val actual=BenchManyBody.compute steps count
    in if matches count actual expected then
      Int.toString steps^":"^Int.toString count^":"^Int.toString(List.length actual)
      else raise Fail "incorrect result: complete many-body state differs"end
    | run _ = raise Fail "many-body expects steps, body count and a complete state reference"
end
