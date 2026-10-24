(* Named syntax scopes, joined by compiler binding identity. Clause-local
   variables remain distinct even when their spellings are the same. *)
structure RuneLspOutline =
struct
  structure C=RuneCompiler
  type entry={identity:string,name:string,category:string,start:int,stop:int}
  type symbol={name:string,kind:int,start:int,stop:int,selectionStart:int,selectionStop:int}
  fun prepare {entries:entry list,events:C.Syntax.event list,pieces:C.Syntax.piece list,facts:C.Analysis.fact list} =
    let fun same (a:entry,b:entry)= #identity a= #identity b andalso #name a= #name b andalso #category a= #category b
        fun group (entry,kept)=case List.find(fn prior=>same(entry,prior))kept of NONE=>entry::kept
          | SOME prior=>if #start prior<= #start entry then kept else entry::List.filter(fn prior=>not(same(entry,prior)))kept
        val entries=RuneLspStructure.sort (fn (a:entry,b:entry)=> #start a< #start b)(List.foldl group [] entries)
        fun contains (event:C.Syntax.event,start,stop)= #start event<=start andalso stop<= #stop event
        fun smallest ([],best)=best
          | smallest (event::rest,NONE)=smallest(rest,SOME event)
          | smallest (event::rest,SOME prior)=smallest(rest,SOME(if #stop event- #start event< #stop prior- #start prior then event else prior))
        fun firstName (event:C.Syntax.event,name)=Option.map #start(List.find(fn piece:C.Syntax.piece=>
          #start event<= #start piece andalso #stop piece<= #stop event andalso #text piece=name andalso
          List.exists(fn kind=>kind= #kind piece)["identifier","operator","typeVariable"])pieces)
        fun named (entry:entry)=smallest(List.filter(fn event:C.Syntax.event=>
          List.exists(fn kind=>kind= #kind event)["fundef","strbind","sigbind","funbind","typbind","datbind",
            "typespec","valspec","strspec","exnspec","ExnDecl","ExnRepl","constructor"] andalso
          (case #values event of name::_=>name= #name entry | _=>false) andalso
          contains(event,#start entry,#stop entry) andalso firstName(event,#name entry)=SOME(#start entry))events,NONE)
        fun valueDeclaration (entry:entry)=
          case smallest(List.filter(fn event:C.Syntax.event=>contains(event,#start entry,#stop entry) andalso
            List.exists(fn kind=>kind= #kind event)["DVal","DValRec"])events,NONE) of NONE=>NONE
          | SOME event=>
              (case List.find(fn expression:C.Syntax.event=>String.isPrefix "E" (#kind expression) andalso
                contains(event,#start expression,#stop expression))events of NONE=>NONE | SOME expression=>
                if #stop entry> #start expression orelse length(List.filter(fn other:entry=> #category other="value" andalso
                  contains(event,#start other,#stop other) andalso #stop other<= #start expression)entries)<>1 then NONE
                else SOME(event,expression))
        fun make (entry:entry):symbol =
          let val declaration=named entry
              val value=if #category entry="value" andalso not(isSome declaration) then valueDeclaration entry else NONE
              val functionValue=case value of NONE=>false | SOME(_,expression)=> #kind expression="EFn" orelse
                List.exists(fn fact:C.Analysis.fact=> #start fact= #start expression andalso #stop fact= #stop expression
                  andalso not(null(#arguments fact)))facts
              val functionSpec=case declaration of SOME event=> #kind event="valspec" andalso
                (case List.find(fn item:C.Syntax.event=>String.isPrefix "Ty" (#kind item) andalso
                  contains(event,#start item,#stop item))events of SOME ty=> #kind ty="TyArrow" | _=>false) | NONE=>false
              val tag=case declaration of NONE=>"" | SOME event=> #kind event
              val kind=case #category entry of "structure"=>2 | "signature"=>11 | "functor"=>12 | "type"=>23
                | _=>if tag="constructor" then 22 else if tag="ExnDecl" orelse tag="ExnRepl" orelse tag="exnspec" then 14
                  else if tag="fundef" orelse functionValue orelse functionSpec then 12 else 13
              val span=case declaration of SOME event=>
                    (case smallest(List.filter(fn outer:C.Syntax.event=>contains(outer,#start event,#stop event) andalso
                      (case #values outer of "1"::_=>true | _=>false) andalso
                      List.exists(fn pair=>pair=(tag,#kind outer))[("fundef","DFun"),("strbind","DStructure"),
                        ("sigbind","DSignature"),("funbind","DFunctor")])events,NONE) of SOME outer=>(#start outer,#stop outer)
                     | NONE=>(#start event,#stop event))
                | NONE=>(case value of SOME(event,_)=>(#start event,#stop event) | NONE=>(#start entry,#stop entry))
          in {name= #name entry,kind=kind,start= #1 span,stop= #2 span,selectionStart= #start entry,selectionStop= #stop entry} end
    in List.map make entries end
  fun flat (symbols:symbol list,uri,range)=List.map(fn item=>Json.Object
    [("name",Json.String(#name item)),("kind",Json.int(#kind item)),("location",Json.Object
      [("uri",Json.String uri),("range",range(#selectionStart item,#selectionStop item))])])symbols
  fun nested (symbols:symbol list,range) =
    let val table=Vector.fromList symbols
        val count=Vector.length table
        fun owner i=
          let val child=Vector.sub(table,i)
              fun pick(j,best)=if i=j then best else
                let val parent=Vector.sub(table,j)
                    val encloses= #start parent<= #start child andalso #stop child<= #stop parent andalso
                      (#start parent<> #start child orelse #stop parent<> #stop child)
                in if not encloses then best else case best of NONE=>SOME j | SOME old=>
                  let val prior=Vector.sub(table,old)
                  in if #stop parent- #start parent< #stop prior- #start prior then SOME j else best end end
          in List.foldl pick NONE (List.tabulate(count,fn n=>n)) end
        val parents=Vector.tabulate(count,owner)
        fun children parent=List.filter(fn i=>Vector.sub(parents,i)=parent)(List.tabulate(count,fn n=>n))
        fun emit i=
          let val item=Vector.sub(table,i)
          in Json.Object[("name",Json.String(#name item)),("kind",Json.int(#kind item)),
            ("range",range(#start item,#stop item)),("selectionRange",range(#selectionStart item,#selectionStop item)),
            ("children",Json.Array(List.map emit(children(SOME i))))] end
    in List.map emit (children NONE) end
end
