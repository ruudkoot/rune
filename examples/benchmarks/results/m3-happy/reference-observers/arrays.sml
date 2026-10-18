 (* Boxed immutable control arrays. Element roots remain memoized in both
  * finite-data policies; values can contain D-controlled finite data. *)
 structure A=
 struct
   datatype 'a node=ArrayNode of int*int*'a L.delay Vector.vector
   type 'a array='a node L.delay
   fun build(low:int,high:int)initial updates=
     L.delay(fn()=>
       let val count=Int.max(0,high-low+1)
           val cells=Array.array(count,initial)
           fun put(index,value)=
             if index<low orelse index>high then raise Subscript
             else Array.update(cells,index-low,value)
           val _=List.app put(updates())
       in ArrayNode(low,high,Vector.tabulate(count,fn i=>Array.sub(cells,i)))end)
   fun array bounds updates=build bounds(L.delay(fn()=>raise Fail"undefined Happy array element"))updates
   fun accum combine initial(low:int,high:int)updates=
     L.delay(fn()=>
       let val count=Int.max(0,high-low+1)
           val cells=Array.array(count,initial)
           fun put(index,value)=
             if index<low orelse index>high then raise Subscript
             else Array.update(cells,index-low,combine(Array.sub(cells,index-low))value)
           val _=List.app put(updates())
       in ArrayNode(low,high,Vector.tabulate(count,fn i=>Array.sub(cells,i)))end)
   fun bounds array=let val ArrayNode(low,high,_)=L.force array in(low,high)end
   fun sub array index=
     let val ArrayNode(low,high,values)=L.force array
     in if index<low orelse index>high then raise Subscript
        else L.force(Vector.sub(values,index-low))end
   fun fromFinite bounds values=
     let val(low,_)=bounds
         fun entries i values=case D.force values of F.Nil=>[]
           |F.Cons(value,rest)=>(i,L.delay(fn()=>value))::entries(i+1)rest
     in array bounds(fn()=>entries low values)end
   fun assocs array=
     let val(low,high)=bounds array
         fun loop i=F.defer(fn()=>if i>high then F.empty()
           else F.cons(D.delay(fn()=>(i,sub array i)),loop(i+1)))
     in loop low end
 end
 datatype associativity=LeftAssoc|RightAssoc|NonAssoc
 datatype priority=No|Prio of associativity D.t*int D.t
 val noPriority=D.delay(fn()=>No)
 type namedProduction=int D.t*int F.seq*(text*int F.seq)D.t*priority D.t
 type start=text*int D.t*int D.t*bool D.t
 datatype grammar=Grammar of{
   productions:namedProduction F.seq,
   lookupProdNo:int->namedProduction D.t,
   lookupProdsOfName:int->int F.seq,
   tokenSpecs:(int D.t*text)F.seq,
   terminals:int F.seq,nonterminals:int F.seq,starts:start F.seq,
   types:text option D.t A.array,tokenNames:text A.array,
   firstNonterm:int D.t,firstTerm:int D.t,eof:int D.t,
   priorities:(int D.t*priority D.t)F.seq,
   tokenType:text,importedIdentity:bool D.t,
   monad:(bool*text*text*text*text)L.delay,
   expect:int option D.t,attributes:(text*text)F.seq,attributeType:text,
   lexer:(text*text)option D.t,errorHandler:text option D.t}
 fun productions(Grammar{productions,...})=productions
 fun lookupProdNo(Grammar{lookupProdNo,...})=lookupProdNo
 fun lookupProdsOfName(Grammar{lookupProdsOfName,...})=lookupProdsOfName
 fun tokenSpecs(Grammar{tokenSpecs,...})=tokenSpecs
 fun terminals(Grammar{terminals,...})=terminals
 fun nonterminals(Grammar{nonterminals,...})=nonterminals
 fun starts(Grammar{starts,...})=starts
 fun types(Grammar{types,...})=types
 fun tokenNames(Grammar{tokenNames,...})=tokenNames
 fun firstNonterm(Grammar{firstNonterm,...})=D.force firstNonterm
 fun firstTerm(Grammar{firstTerm,...})=D.force firstTerm
 fun eof(Grammar{eof,...})=D.force eof
 fun priorities(Grammar{priorities,...})=priorities
 fun tokenType(Grammar{tokenType,...})=tokenType
 fun importedIdentity(Grammar{importedIdentity,...})=D.force importedIdentity
 fun monad(Grammar{monad,...})=L.force monad
 fun expect(Grammar{expect,...})=D.force expect
 fun attributes(Grammar{attributes,...})=attributes
 fun attributeType(Grammar{attributeType,...})=attributeType
 fun lexer(Grammar{lexer,...})=D.force lexer
 fun errorHandler(Grammar{errorHandler,...})=D.force errorHandler
