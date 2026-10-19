
 fun equalConstant left right=case(left,right)of
    (Truth,Truth)=>true|(Falsehood,Falsehood)=>true|(BoolType,BoolType)=>true
   |(Universe a,Universe b)=>equalInt a b|_=>false
 (* Source equality deliberately ignores alternative types and attributes. *)
 fun equalTerm left right=case(force left,force right)of
    (Sym(i,j,_,_),Sym(k,l,_,_))=>equalInt i k andalso equalInt j l
   |(App(a,b,_,_),App(c,d,_,_))=>equalTerm a c andalso equalTerm b d
   |(PairTerm(a,b,c,_,_),PairTerm(d,e,f,_,_))=>equalTerm a d andalso equalTerm b e andalso equalTerm c f
   |(Binder(a,b,c,_,_),Binder(d,e,f,_,_))=>a=d andalso equalDeclaration b e andalso equalTerm c f
   |(Constant(a,_,_),Constant(b,_,_))=>equalConstant a b
   |(Unary(a,b,_,_),Unary(c,d,_,_))=>a=c andalso equalTerm b d
   |(Binary(a,b,c,_,_),Binary(d,e,f,_,_))=>a=d andalso equalTerm b e andalso equalTerm c f
   |(Cond(a,b,c,_,_),Cond(d,e,f,_,_))=>equalDeclaration a d andalso equalTerm b e andalso equalTerm c f
   |(Const(a,b,c,_,_),Const(d,e,f,_,_))=>equalInt a d andalso equalInt b e andalso equalInt c f
   |(Recurse(xs,x,_,_),Recurse(ys,y,_,_))=>equalLists equalTerm xs ys andalso equalTerm x y
   |_=>false
 and equalDeclaration left right=case(force left,force right)of
    (SymbolDec(a,_),SymbolDec(b,_))=>equalTerm a b
   |(AxiomDec(a,_),AxiomDec(b,_))=>equalTerm a b
   |(Def(a,b,_),Def(c,d,_))=>equalTerm a c andalso equalTerm b d
   |(Data(ds,xs,_),Data(es,ys,_))=>equalLists equalDeclaration ds es andalso equalLists(equalLists equalTerm)xs ys
   |(DecPair(a,b,_),DecPair(c,d,_))=>equalDeclaration a c andalso equalDeclaration b d|_=>false
 and equalSignature left right=case(force left,force right)of
    (EmptySig _,EmptySig _)=>true
   |(Extend(a,b,_),Extend(c,d,_))=>equalDeclaration a c andalso equalSignature b d
   |(Combine(a,b,i,_,_),Combine(c,d,j,_,_))=>equalInt i j andalso equalSignature a c andalso equalSignature b d
   |(Share(a,i,j,k,_,_),Share(b,l,m,n,_,_))=>
       equalInt i l andalso equalInt j m andalso equalInt j m andalso equalSignature a b
   |_=>false
 fun selectTerm term indices=L.delay(fn()=>
   let fun termAt indices term declarations=case force indices of F.Nil=>(term,declarations)
         |F.Cons(index,rest)=>case force term of
            App(a,b,_,_)=>termAt rest(nth(fromNative[a,b])index)declarations
           |PairTerm(a,b,_,_,_)=>termAt rest(nth(fromNative[a,b])index)declarations
           |Binder(_,dec,body,_,_)=>if equalInt index(int 0)then decAt rest dec declarations
                else if equalInt index(int 1)then termAt rest body(F.cons(dec,declarations))else raise Match
           |Unary(_,body,_,_)=>if equalInt index(int 0)then termAt rest body declarations else raise Match
           |Binary(_,a,b,_,_)=>termAt rest(nth(fromNative[a,b])index)declarations
           |Cond(dec,a,b,_,_)=>
                (case force dec of AxiomDec(body,info)=>
                  if equalInt index(int 0)then decAt rest dec declarations
                  else let val current=if equalInt index(int 1)then dec
                             else if equalInt index(int 2)then cell(AxiomDec(cell(Unary(NotU,body,F.empty(),info)),F.empty()))
                             else raise Fail"sel_trm"
                       in termAt rest(nth(fromNative[a,b])(subtract index(int 1)))(F.cons(current,declarations))end
                 |_=>raise Match)
           |Recurse(terms,_,_,_)=>termAt rest(nth terms index)declarations|_=>raise Match
       and decAt indices dec declarations=case force indices of F.Nil=>raise Match
         |F.Cons(index,rest)=>case force dec of
             SymbolDec(body,_)=>if equalInt index(int 0)then termAt rest body declarations else raise Match
            |AxiomDec(body,_)=>if equalInt index(int 0)then termAt rest body declarations else raise Match
            |DecPair(a,b,_)=>if equalInt index(int 0)then decAt rest a declarations
                 else if equalInt index(int 1)then decAt rest b(F.cons(a,declarations))else raise Match
            |_=>raise Match
   in termAt indices term(F.empty())end)
