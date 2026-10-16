structure Progress =
struct
 fun emit text=(TextIO.output(TextIO.stdOut,text);TextIO.flushOut TextIO.stdOut)
 val _=BenchPiDigitsFive.run 128 emit
 val _=emit "END\n"
end
