module Main where
import GHC.Float(castFloatToWord32)
tests :: [(String,Float)]
tests=[
 ("add-round",16777216+1),
 ("add-odd",16777218+1),
 ("multiply",(1+2**(-23))*(1+2**(-23))),
 ("divide",1/3),
 ("sqrt",sqrt 2),
 ("round-even",realToFrac(1.000000059604644775390625::Double)),
 ("round-odd",realToFrac(1.000000178813934326171875::Double)),
 ("round-negative",realToFrac(-1.000000059604644775390625::Double)),
 ("round-binade",realToFrac(1.999999940395355224609375::Double)),
 ("negative-zero",negate 0)]
main=mapM_(print . \(n,x)->(n,castFloatToWord32 x))tests
