structure PiProgress =
struct
 val count=case TextIO.inputLine TextIO.stdIn of SOME text=>(case Int.fromString text of SOME v=>v |NONE=>raise Fail "count") |NONE=>raise Fail "input"
 val digits=ref 0
 fun emit text=(TextIO.output(TextIO.stdOut,text);TextIO.flushOut TextIO.stdOut;
   if String.size text=1 then(digits:= !digits+1;if !digits mod 10=0 then TextIO.output(TextIO.stdErr,"progress "^Int.toString(!digits)^"\n")else())else())
 val _=BenchZarithPi.run count emit
end
