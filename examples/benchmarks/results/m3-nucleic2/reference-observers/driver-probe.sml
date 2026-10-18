structure K=BenchNucleic2Fn(structure D=BenchNeed val shared=false)
structure Check=BenchNucleic2CheckFn(K)
val _=if Check.run["3"]="3"then print"PASS source smoke repetitions\n"else raise Fail"smoke driver"
structure Poison=BenchNucleic2CheckFn(struct fun compute _=raise Fail"unexpected search"end)
val _=if Poison.run["0"]="0"andalso Poison.run["~1"]="0"then print"PASS source nonpositive repetition no-op\n"else raise Fail"no-op"
structure Perturbed=BenchNucleic2CheckFn(struct
 fun compute _=33.7975921630859375*(1.0+0.000004)
end)
val _=(Perturbed.run["1"];raise Fail"perturbed maximum accepted")
  handle Fail message=>if message="incorrect result: nucleic2 maximum atom distance"then print"PASS perturbed maximum rejected\n"
    else raise Fail message
val _=if not(Check.valid(0.0/0.0))andalso not(Check.valid(1.0/0.0))then print"PASS nonfinite maximum rejected\n"
  else raise Fail"nonfinite checker"
