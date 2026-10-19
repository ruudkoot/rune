 fun quoteName value="\""^string value^"\""
 fun showList show values="["^String.concatWith","(List.map show(F.toList values))^"]"
 fun namesShown values="["^String.concatWith","(List.map quoteName(
   let fun collect xs=case force xs of F.Nil=>[]|F.Cons(x,rest)=>x::collect rest
   in collect values end))^"]"
 fun observeTypeExpr value=case force value of TDefVar n=>"V"^quoteName n
   |TDefCons(n,args)=>"C("^quoteName n^","^showList(fn node=>observeTypeExpr(cell node))args^")"
 fun observeTypeDefinition(n,vars,constructors)=
   "("^String.concatWith","[quoteName n,namesShown vars,
     showList(fn(c,args)=>"("^quoteName c^","^showList(fn node=>observeTypeExpr(cell node))args^")")constructors]^")"
 fun observeCore value=case force value of EVar n=>"V"^quoteName n
   |ENum n=>"N"^signed n|EConstr n=>"C"^quoteName n
   |EAp(a,b)=>"A("^observeCore a^","^observeCore b^")"
   |ELet(recursive,bindings,body)=>"L("^String.concatWith","[
       if force recursive then"True"else"False",
       showList(fn(n,e)=>"("^quoteName n^","^observeCore e^")")bindings,observeCore body]^")"
   |ECase(e,alternatives)=>"K("^observeCore e^","^showList(fn(n,alt)=>
       let val(args,e)=force alt in"("^quoteName n^",("^namesShown args^","^observeCore e^"))"end)alternatives^")"
   |ELam(args,body)=>"F("^namesShown args^","^observeCore body^")"
 fun observeProgram value=let val(types,definitions)=force value
   in"("^showList observeTypeDefinition types^","^showList(fn(n,value)=>
      let val(args,body)=force value
      in"("^quoteName n^",("^namesShown args^","^observeCore body^"))"end)definitions^")"end
 fun showDomain d value=
   let val node=force value
       val body=case node of Two=>"Two"
         |Lift1 ds=>"Lift1 "^showList(fn node=>showDomain 0(cell node))ds
         |Lift2 ds=>"Lift2 "^showList(fn node=>showDomain 0(cell node))ds
         |Func(ds,res)=>"Func "^showList(fn node=>showDomain 0(cell node))ds^" "^showDomain 11 res
   in case node of Two=>body|_=>if d>10 then"("^body^")"else body end
 fun observeTable table=showList(fn(domain,size)=>"("^showDomain 0 domain^","^signed size^")")table
