(* GHC 9.4.7 binary32 primitive observations; original source and bit fixtures retained. *)
functor BenchNucleic2PrecisionTestsFn(structure K:sig
 structure R:sig val add:real*real->real val mul:real*real->real val divide:real*real->real val sqrt:real->real val round:real->real val negative:real->real end
 end val label:string)=struct
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
 val _=List.app(fn(name,actual,word)=>T.check("nucleic2/"^label^"/precision-"^name,fn()=>
   let val expected=BenchNucleic2Oracle.decode word
   in Real.==(actual,expected)andalso Real.signBit actual=Real.signBit expected end))cases
end
