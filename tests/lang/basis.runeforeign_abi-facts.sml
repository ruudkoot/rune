val facts=RuneForeign.abiFacts()
val target=RuneForeign.target()
fun fact name=case List.find(fn{name=n,...}=>n=name)(#scalars facts) of SOME f=>f | NONE=>raise Fail "missing native C fact"
val ()=if #architecture facts<>"" andalso #charBits facts=8 andalso List.length(#scalars facts)=10 andalso
  #size(fact "pointer")= #pointerBytes target andalso #size(fact "float")=4 andalso #size(fact "double")=8 andalso
  #size(fact "bool")=1 andalso List.all(fn{name,size,alignment}=>name<>"" andalso size>0 andalso alignment>0 andalso size mod alignment=0)(#scalars facts)
  then print "PASS native C ABI facts\n" else raise Fail "invalid native C facts"
