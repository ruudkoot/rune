structure KernelNeed=BenchMkhprogFn(BenchNeed)
structure DriverNeed=BenchMkhprogDriverFn(KernelNeed)
structure KernelStrict=BenchMkhprogFn(BenchStrict)
structure DriverStrict=BenchMkhprogDriverFn(KernelStrict)
structure Main=struct
 val base="tests/out/benchmarks/mkhprog-originals/"
 val _=print("Need normal "^DriverNeed.run["3800",base^"default.input",base^"default.hashes"]^"\n")
 val _=TextIO.flushOut TextIO.stdOut
 val _=print("Strict normal "^DriverStrict.run["3800",base^"default.input",base^"default.hashes"]^"\n")
 val _=TextIO.flushOut TextIO.stdOut
end
