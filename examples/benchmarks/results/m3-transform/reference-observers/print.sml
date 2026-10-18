 fun cat values=concat(list values)
 fun separated render separator values=D.delay(fn()=>case D.force values of F.Nil=>F.Nil
   |F.Cons(x,rest)=>D.force(append(render(D.force x))(concat(map(fn x=>append separator(render x))rest))))
 fun indent values=D.delay(fn()=>case D.force values of F.Nil=>F.Nil
   |F.Cons(c,rest)=>if D.force c= #"\n"then
       if null rest then F.Cons(c,empty())
       else F.Cons(c,cons #" "(cons #" "(indent rest)))
     else F.Cons(c,indent rest))
 fun printProgram program=separated printDef(text"\n")program
 and printDef definition=D.delay(fn()=>D.force(
   case D.force definition of
      Caf(vars,expr)=>
       if not(null vars)andalso null(tail vars)then cat[head vars,text"\t= ",printExpr expr,text";"]
       else cat[text"(",separated(fn v=>v)(text",")vars,text")\t= ",printExpr expr,text";"]
     |Def(name,vars,expr,wherePart)=>
       (case D.force wherePart of NoWhere=>cat[name,text" ",separated(fn v=>v)(text" ")vars,text"\t= ",printExpr expr,text";"]
        |Where definitions=>cat[name,text" ",separated(fn v=>v)(text" ")vars,text"\n= ",printExpr expr,
           indent(cat[text"\nwhere\n",printProgram definitions]),text";"])))
 and printExpr expr=D.delay(fn()=>D.force(
   case D.force expr of
      Tail(_,e)=>cat[text"(tl ",printExpr e,text")"]
     |Cons(_,state,e)=>cat[text"((:) ",printExpr state,text" ",printExpr e,text")"]
     |Map(_,name,args)=>cat[text"(map_",number(fromInt(F.length args)),text" ",name,text" ",printExprs args,text")"]
     |Maps(_,first,last,state,args)=>cat[text"(maps_",number(fromInt(F.length args)),text" ",first,text" ",last,
         text" ",printExpr state,text" ",printExprs args,text")"]
     |Ap(name,args)=>cat[text"(",name,text" ",printExprs args,text")"]
     |Tuple values=>if null values then text"()"else
         if null(tail values)then printExpr(head values)
         else cat[text"(",separated printExpr(text",")values,text")"]
     |Var name=>name|Lit value=>value))
 and printExprs exprs=separated printExpr(text" ")exprs
