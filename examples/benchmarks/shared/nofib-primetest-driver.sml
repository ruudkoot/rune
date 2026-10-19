functor BenchPrimeTestDriverFn(K:sig val process:int->string list->string end) =
struct
  fun lines text =
    if text=""then[]else
      let val rows=String.fields(fn c=>c= #"\n")text
      in if String.sub(text,String.size text-1)= #"\n"then List.rev(tl(List.rev rows))else rows end
  fun run [path] =
    let val input=TextIO.openIn path val text=TextIO.inputAll input val _=TextIO.closeIn input
    in K.process 100(lines text)end
    |run _=raise Fail "primetest expects a candidate input file"
end
