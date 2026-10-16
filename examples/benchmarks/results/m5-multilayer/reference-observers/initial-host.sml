structure Pilot =
struct
  structure K=BenchMultilayer
  val random=BenchOCamlRandom.default()
  fun draw()=BenchOCamlRandom.real random 2.0-1.0
  val layers=K.initialize draw 34 2
  fun fields(K.Layer{weight,bias,...})=
    List.concat(Array.foldr(fn(row,rest)=>RealArray.foldr(op ::)[]row::rest)[]weight)@
      RealArray.foldr(op ::)[]bias
  val actual=List.concat(List.map fields layers)
  val input=TextIO.openIn "initial-parameters.txt"
  val text=TextIO.inputAll input val _=TextIO.closeIn input
  val expected=List.map(fn s=>case Real.fromString s of SOME x=>x|NONE=>raise Fail "invalid initial reference")
    (String.tokens Char.isSpace text)
  fun check [] [] index=print("PASS "^Int.toString index^" exact initial parameter values\n")
    | check(x::xs)(y::ys)index=if Real.==(x,y)then check xs ys(index+1)
      else (print "INITIAL DIFFERENCE\n"; raise Fail("initial parameter "^Int.toString index^" observed "^Real.toString x^" expected "^Real.toString y))
    | check _ _ _=raise Fail "initial parameter count differs"
  val _=check actual expected 0
end
