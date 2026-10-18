 fun quote value="\""^String.translate(fn #"\""=>"\\\""| #"\\"=>"\\\\"| #"\n"=>"\\n"| #"\r"=>"\\r"| #"\t"=>"\\t"|c=>String.str c)value^"\""
 fun showText value=String.implode(F.toList value)
 fun jsonText value=quote(showText value)
 fun arr values="["^String.concatWith","values^"]"
 fun dumpList render values=case D.force values of F.Nil=>arr[quote"[]"]
   |F.Cons(x,rest)=>arr[quote"(:)",render(D.force x),dumpList render rest]
 fun dumpExpr expr=case D.force expr of
     Tail(p,e)=>arr[quote"F_Tail",Int.toString(D.force p),dumpExpr e]
    |Cons(p,s,e)=>arr[quote"F_Cons",Int.toString(D.force p),dumpExpr s,dumpExpr e]
    |Map(p,name,args)=>arr[quote"F_Map",Int.toString(D.force p),jsonText name,dumpList dumpExpr args]
    |Maps(p,f,g,s,args)=>arr[quote"F_Maps",Int.toString(D.force p),jsonText f,jsonText g,dumpExpr s,dumpList dumpExpr args]
    |Ap(name,args)=>arr[quote"F_Ap",jsonText name,dumpList dumpExpr args]
    |Tuple args=>arr[quote"F_Tuple",dumpList dumpExpr args]
    |Var name=>arr[quote"F_Var",jsonText name]|Lit value=>arr[quote"F_Lit",jsonText value]
 fun dumpDef definition=case D.force definition of
      Caf(args,e)=>arr[quote"F_Caf",dumpList jsonText args,dumpExpr e]
     |Def(name,args,e,w)=>arr[quote"F_Def",jsonText name,dumpList jsonText args,dumpExpr e,dumpWhere w]
 and dumpWhere w=case D.force w of NoWhere=>arr[quote"C_NoWhere"]
    |Where program=>arr[quote"F_Where",dumpList dumpDef program]
 fun dumpProgram program=dumpList dumpDef program
