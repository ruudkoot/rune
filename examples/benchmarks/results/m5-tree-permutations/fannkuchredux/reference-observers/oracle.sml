structure FannkuchReference =
struct
 val n=case TextIO.inputLine TextIO.stdIn of SOME text=>(case Int.fromString text of SOME n=>n |NONE=>raise Fail "n") |NONE=>raise Fail "input"
 val(maximum,checksum)=FannkuchKernel.fannkuch n
 val _=TextIO.output(TextIO.stdOut,Int.toString maximum^" "^Int.toString checksum^"\n")
end
