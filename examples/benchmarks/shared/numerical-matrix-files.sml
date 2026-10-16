structure BenchMatrixFiles =
struct
  type matrix=RealArray.array array
  fun tokens path=let val input=TextIO.openIn path val text=TextIO.inputAll input
    in TextIO.closeIn input;String.tokens Char.isSpace text end
  fun real text=case Real.fromString text of SOME x=>
      if Real.isFinite x then x else raise Fail "nonfinite matrix input"
    | NONE=>raise Fail "invalid matrix real"
  fun load path=case tokens path of m::n::rest=>
    let val rows=BenchInput.between(1,2730)(BenchInput.integer m)
        val columns=BenchInput.between(1,30)(BenchInput.integer n)
        fun fields 0 xs acc=(RealArray.fromList(List.rev acc),xs)
          | fields count(x::xs)acc=fields(count-1)xs(real x::acc)
          | fields _ [] _=raise Fail "short matrix row"
        fun row 0 [] acc=Array.fromList(List.rev acc)
          | row 0 _ _=raise Fail "extra matrix fields"
          | row count xs acc=let val(values,tail)=fields columns xs []
            in row(count-1)tail(values::acc)end
    in row rows rest []end
    | _=>raise Fail "missing matrix dimensions"
  fun size(a:matrix)=let val rows=Array.length a
    in(rows,if rows=0 then 0 else RealArray.length(Array.sub(a,0)))end
  fun prefix a rows=
    let val _=BenchInput.between(1,Array.length a)rows
    in Array.tabulate(rows,fn i=>Array.sub(a,i))end
  fun check absolute relative expected actual=
    let val(rows,columns)=size expected
        val _=if size actual=(rows,columns)then()else raise Fail "matrix result dimensions differ"
        fun fields i j=if j=columns then()else
          if BenchInput.closeReal(RealArray.sub(Array.sub(actual,i),j),
             RealArray.sub(Array.sub(expected,i),j),absolute,relative)
          then fields i(j+1)else raise Fail "matrix result differs"
        fun row i=if i=rows then()else(fields i 0;row(i+1))
    in row 0 end
end
