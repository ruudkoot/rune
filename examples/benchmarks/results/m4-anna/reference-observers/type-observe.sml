 fun observeTVName variable=let val(xs,ys)=force variable
   in"("^showList(fn n=>signed(cell n))xs^","^showList(fn n=>signed(cell n))ys^")"end
 fun observeType expression=case force expression of
    TVar variable=>"V"^observeTVName variable
   |TArr(a,b)=>"A("^observeType a^","^observeType b^")"
   |TCons(n,args)=>"C("^quoteName n^","^showList(fn node=>observeType(cell node))args^")"
 fun observeTyped(tree:typedAnnotation)=
   let val(t,node)=force tree
       val value=case force node of AVar n=>"V"^quoteName n|ANum n=>"N"^signed n
         |AConstr n=>"C"^quoteName n
         |AAp(a,b)=>"A("^observeTyped a^","^observeTyped b^")"
         |ALam(args,e)=>"F("^namesShown args^","^observeTyped e^")"
         |ALet(recursive,definitions,e)=>"L("^String.concatWith","[
             if force recursive then"True"else"False",
             showList(fn(n,e)=>"("^quoteName n^","^observeTyped e^")")definitions,observeTyped e]^")"
         |ACase(e,alternatives)=>"K("^observeTyped e^","^showList(fn(tag,value)=>
             let val(args,e)=force value
             in"("^quoteName tag^",("^namesShown args^","^observeTyped e^"))"end)alternatives^")"
   in"("^observeType t^","^value^")"end
