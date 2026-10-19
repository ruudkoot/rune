 (* Candidate continuations are control: constructing an unchosen callback
    must not execute the callback or build its following generator. *)
 fun chooseCont options=choose(list options)(fn selected=>fn env=>force selected()env)
 fun genTypes vnts flds n dp k=
   getTypeNames n(fn names=>allTypeNames(fn old=>
   cmap(rep n(genType vnts flds(F.append old names)dp))
   (fn types=>extendTypes(listPairs names types)k)))
 and genType vnts flds names dp k=upto(vnts-1)(fn count=>
   getConstructors(force count+1)(fn cs=>
   cmap(rep(force count)(genArgtypes flds names dp))
   (fn fields=>k(scalar(listPairs cs(F.cons(scalar(F.empty()),fields)))))))
 and genArgtypes flds names dp k=upto flds(fn count=>
   cmap(rep(force count)(genArgtype names dp))(fn args=>k(scalar args)))
 and genArgtype names dp k=if dp<=1 then genBase k else
   chooseCont[
     fn()=>upto(length names-1)(fn n=>k(scalar(NameType(nth names(force n))))),
     fn()=>genBase k,
     fn()=>genArgtype names(dp-1)(fn a=>k(scalar(ListType a))),
     fn()=>upto 4(fn n=>cmap(rep(force n)(genArgtype names(dp-1)))(fn ats=>k(scalar(TupleType ats)))),
     fn()=>genIxType names(dp-1)(fn a=>genArgtype names(dp-1)(fn b=>k(scalar(ArrayType(a,b)))))]
 and genBase k=chooseCont[
     fn()=>choose(list[IntType,IntegerType,FloatType,DoubleType])(fn kind=>k(base(NumType(force kind)))),
     fn()=>k(base BoolType),fn()=>k(base CharType)]
 and genIxType names dp k=if dp<=1 then genIxBase k else
     chooseCont[fn()=>genIxBase k,fn()=>upto 4(fn n=>
       cmap(rep(force n)(genIxType names(dp-1)))(fn ats=>k(scalar(TupleType ats))))]
 and genIxBase k=chooseCont[
     fn()=>choose(list[IntType,IntegerType])(fn kind=>k(base(NumType(force kind)))),
     fn()=>k(base BoolType),fn()=>k(base CharType)]
