structure NeedSched=BenchSchedFn(BenchNeed)
structure StrictSched=BenchSchedFn(BenchStrict)
val _=List.app(fn n=>
 print(Int.toString n^" lazy "^NeedSched.main n^Int.toString n^" strict "^StrictSched.main n))
 [0,1,2,3,7,10,11,12,14]
