structure FulsomNormalPilot=struct
 structure N=BenchFulsomFn(BenchNeed)
 structure E=BenchFulsomFn(BenchStrict)
 structure NC=BenchFulsomCheckFn(N)
 structure EC=BenchFulsomCheckFn(E)
 fun raw label run=print(label^" "^run["9","depth-9.hex"]^"\n")
 fun hashed label run=print(label^" "^run["1000","5","depth-5.hex","8553150556328418559"]^"\n")
 val _=raw "need/raw9" NC.runRaw
 val _=raw "strict/raw9" EC.runRaw
 val _=hashed "need/1000x5" NC.runHashed
 val _=hashed "strict/1000x5" EC.runHashed
end
