functor ExactProbeFn(K:sig
  type cr
  val constant:int->cr
  val integer:IntInf.int->cr
  val divide:cr*cr->cr
  val multiply:cr*cr->cr
  val negative:cr->cr
  val sine:cr->cr
  val cosine:cr->cr
  val atan:cr->cr
  val bits:int->cr->IntInf.int
  val text:int->cr->string
end)=
struct
  fun fraction(n,d)=K.divide(K.integer n,K.integer d)
  val samples=[("pi",K.constant 0),("third",fraction(1,3)),("negative-third",fraction(~1,3)),("sqrt-half",K.constant 3),("sin-quarter",K.sine(K.constant 2)),("cos-quarter",K.cosine(K.constant 2)),("sin-negative-quarter",K.sine(K.negative(K.constant 2))),("atan-minus-five",K.atan(K.integer (~5))),("atan-minus-one",K.atan(K.integer (~1))),("atan-minus-half",K.atan(fraction(~1,2))),("atan-zero",K.atan(K.integer 0)),("atan-fifth",K.atan(fraction(1,5))),("atan-one",K.atan(K.integer 1)),("atan-five",K.atan(K.integer 5))]
  val _=List.app(fn(name,value)=>
    (List.app(fn p=>print(name^" bits "^Int.toString p^" "^IntInf.toString(K.bits p value)^"\n"))[0,1,2,8,32,137];
     print(name^" text "^K.text 40 value^"\n")))samples
end
structure NeedExact=BenchExactRealsFn(BenchNeed)
structure NeedProbe=ExactProbeFn(NeedExact)
structure StrictExact=BenchExactRealsFn(BenchStrict)
structure StrictProbe=ExactProbeFn(StrictExact)
