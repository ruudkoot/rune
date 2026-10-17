structure KernelNeed=BenchGamtebFn(BenchNeed)
structure DriverNeed=BenchGamtebDriverFn(KernelNeed)
structure KernelStrict=BenchGamtebFn(BenchStrict)
structure DriverStrict=BenchGamtebDriverFn(KernelStrict)
structure Main=struct
 val base="tests/out/benchmarks/gamteb-originals/"
 val _=print("Need normal "^DriverNeed.run["200","1000",base^"1000.reference"]^"\n")
 val _=print("Strict normal "^DriverStrict.run["200","1000",base^"1000.reference"]^"\n")
 val _=print("Need large "^DriverNeed.run["200","5000",base^"5000.reference"]^"\n")
 val _=print("Strict large "^DriverStrict.run["200","5000",base^"5000.reference"]^"\n")
end
