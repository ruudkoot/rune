structure K=BenchNucleic2Fn(structure D=BenchNeed val shared=false)
val cases:(string*real*Word32.word)list=[("add-round",K.R.add(16777216.0,1.0),0wx4B800000),
("add-odd",K.R.add(16777218.0,1.0),0wx4B800002),
("multiply",K.R.mul(1.00000011920928955078125,1.00000011920928955078125),0wx3F800002),
("divide",K.R.divide(1.0,3.0),0wx3EAAAAAB),
("sqrt",K.R.sqrt 2.0,0wx3FB504F3),
("round-even",K.R.round 1.000000059604644775390625,0wx3F800000),
("round-odd",K.R.round 1.000000178813934326171875,0wx3F800002),
("round-negative",K.R.round(~1.000000059604644775390625),0wxBF800000),
("round-binade",K.R.round 1.999999940395355224609375,0wx40000000),
("negative-zero",K.R.negative 0.0,0wx80000000)]
val _=List.app(fn(name,value,word)=>
 let val expected=BenchNucleic2Oracle.decode word
 in if Real.==(value,expected)andalso Real.signBit value=Real.signBit expected then print("PASS binary32 "^name^"\n")
    else raise Fail("binary32 primitive "^name)end)cases
