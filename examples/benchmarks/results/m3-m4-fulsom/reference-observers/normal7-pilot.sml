structure FulsomNormalPilot=struct
 structure N=BenchFulsomFn(BenchNeed)
 structure E=BenchFulsomFn(BenchStrict)
 structure NC=BenchFulsomCheckFn(N)
 structure EC=BenchFulsomCheckFn(E)
 fun raw label run=print(label^" "^run["7","depth-7.hex"]^"\n")
 fun hashed label run=print(label^" "^run["1000","5","depth-5.hex","8553150556328418559"]^"\n")
 val _=raw "need/raw7" NC.runRaw
 val _=raw "strict/raw7" EC.runRaw
 val _=hashed "need/1000x5" NC.runHashed
 val _=hashed "strict/1000x5" EC.runHashed
end
