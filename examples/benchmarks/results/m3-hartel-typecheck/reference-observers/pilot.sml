structure Lazy=BenchHartelTypecheckProgramFn(struct val eagerChildren=false end)
structure Strict=BenchHartelTypecheckProgramFn(struct val eagerChildren=true end)
val _=print(Lazy.allRows())
val _=print"STRICT\n"
val _=print(Strict.allRows())
val _=print("SUM "^Lazy.benchmark 1)
val _=print("STRICT SUM "^Strict.benchmark 1)
