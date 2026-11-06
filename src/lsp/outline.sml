(* Named syntax scopes, joined by compiler binding identity. Clause-local
   variables remain distinct even when their spellings are the same. *)
structure RuneLspOutline =
struct
  structure C=CompilerApi
  structure W=RuneLspWorkspace
  type entry={identity:string,name:string,category:string,start:int,stop:int}
  type symbol={name:string,kind:int,start:int,stop:int,selectionStart:int,selectionStop:int}
  (* A family of events, the innermost that holds a range found by walking up
     from the last that begins at or before it. A syntax's spans nest, so the
     walk costs the depth of the nesting, not the number of events; those of
     one span are in the order of their events, the first the deepest. *)
  type nesting={events:C.Syntax.event vector,parents:int vector}
  fun nesting (events:C.Syntax.event list):nesting =
    let val numbered=ListPair.zip (events,List.tabulate (length events,fn i => i))
        fun less ((a:C.Syntax.event,i),(b:C.Syntax.event,j))= #start a< #start b orelse #start a= #start b andalso
          (#stop a> #stop b orelse #stop a= #stop b andalso i>j)
        val sorted=Vector.fromList (List.map #1 (RuneLspStructure.sort less numbered))
        fun climb ([],_)=[]
          | climb (stack as top::rest,event:C.Syntax.event)=
              if #stop (Vector.sub (sorted,top))<= #start event andalso #start (Vector.sub (sorted,top))< #start event
              then climb (rest,event) else stack
        val stack=ref []
        val parents=Vector.tabulate (Vector.length sorted,fn i =>
          let val open'=climb (!stack,Vector.sub (sorted,i))
          in stack:=i::open';case open' of []=> ~1 | top::_=>top end)
    in {events=sorted,parents=parents} end
  fun innermost ({events,parents}:nesting,start,stop) =
    let fun last (lo,hi)=if lo>=hi then lo-1 else
          let val mid=lo+(hi-lo) div 2
          in if #start (Vector.sub (events,mid))<=start then last (mid+1,hi) else last (lo,mid) end
        fun up i=if i<0 then NONE else
          let val event=Vector.sub (events,i)
          in if #start event<=start andalso stop<= #stop event then SOME event else up (Vector.sub (parents,i)) end
    in up (last (0,Vector.length events)) end
  (* the first of events, in their own order, that lies within another; each
     other looked at once *)
  fun firstWithin (events:C.Syntax.event list) =
    let val sorted=Vector.fromList (RuneLspStructure.sort (fn ((a:C.Syntax.event,_),(b:C.Syntax.event,_))=> #start a< #start b)
          (ListPair.zip (events,List.tabulate (length events,fn i => i))))
        val memo=W.table (Vector.length sorted)
        fun lower (start,lo,hi)=if lo>=hi then lo else
          let val mid=lo+(hi-lo) div 2
          in if #start (#1 (Vector.sub (sorted,mid)))<start then lower (start,mid+1,hi) else lower (start,lo,mid) end
        fun search (outer:C.Syntax.event)=
          let fun loop (at,best)=if at>=Vector.length sorted then best else
                let val (event,index)=Vector.sub (sorted,at)
                in if #start event> #stop outer then best else
                   loop (at+1,if #stop event> #stop outer then best else case best of
                     SOME (_,prior) => if index<prior then SOME (event,index) else best | NONE => SOME (event,index)) end
          in Option.map #1 (loop (lower (#start outer,0,Vector.length sorted),NONE)) end
    in fn (outer:C.Syntax.event) =>
      let val key=Int.toString (#start outer) ^ ":" ^ Int.toString (#stop outer)
      in case W.lookup (memo,key) of SOME found => found
         | NONE => let val found=search outer in W.add (memo,key,found);found end end end
  fun prepare {entries:entry list,events:C.Syntax.event list,pieces:C.Syntax.piece list,facts:C.Analysis.fact list} =
    let fun key (entry:entry)= #identity entry ^ "\000" ^ #name entry ^ "\000" ^ #category entry
        (* the first of each binding, the groups newest first *)
        val groups=W.table (length entries)
        val serial=ref 0
        val all=ref []
        fun later (entry:entry)=(serial:= !serial+1;(entry,!serial))
        val ()=List.app (fn entry:entry =>
          case W.lookup (groups,key entry) of
            NONE => let val group=ref (later entry) in W.add (groups,key entry,group);all:=group:: !all end
          | SOME group => if #start (#1 (!group))<= #start entry then () else group:=later entry) entries
        val entries=List.map #1 (RuneLspStructure.sort (fn ((_,a),(_,b)) => a>b) (List.map ! (!all)))
        val entries=RuneLspStructure.sort (fn (a:entry,b:entry)=> #start a< #start b) entries
        fun contains (event:C.Syntax.event,start,stop)= #start event<=start andalso stop<= #stop event
        fun kindIn kinds (event:C.Syntax.event)=List.exists (fn kind => kind= #kind event) kinds
        (* where each name a symbol has occurs, in order *)
        val spelled=W.table (length entries)
        val ()=List.app (fn entry:entry => if isSome (W.lookup (spelled,#name entry)) then ()
          else W.add (spelled,#name entry,ref [])) entries
        val ()=List.app (fn piece:C.Syntax.piece =>
          if List.exists (fn kind => kind= #kind piece) ["identifier","operator","typeVariable"] then
            Option.app (fn places => places:=(#start piece,#stop piece):: !places) (W.lookup (spelled,#text piece))
          else ()) pieces
        val positions=W.table (length entries)
        fun placesOf name=case W.lookup (positions,name) of SOME places => SOME places | NONE =>
          Option.map (fn places =>
            let val ordered=Vector.fromList (List.rev (!places)) in W.add (positions,name,ordered);ordered end)
            (W.lookup (spelled,name))
        fun firstName (event:C.Syntax.event,name)=case placesOf name of NONE => NONE | SOME places =>
          let fun lower (lo,hi)=if lo>=hi then lo else
                let val mid=lo+(hi-lo) div 2
                in if #1 (Vector.sub (places,mid))< #start event then lower (mid+1,hi) else lower (lo,mid) end
              val at=lower (0,Vector.length places)
          in if at=Vector.length places then NONE else
             let val (start,stop)=Vector.sub (places,at)
             in if stop<= #stop event then SOME start else NONE end end
        (* each named declaration, by its name and where that first occurs in it *)
        fun nameKey (name,start)=name ^ "\000" ^ Int.toString start
        val declared=W.table (length events)
        val ()=List.app (fn event:C.Syntax.event =>
          case #values event of name::_ =>
            if not (kindIn ["fundef","strbind","sigbind","funbind","typbind","datbind","typespec","valspec","strspec",
                            "exnspec","ExnDecl","ExnRepl","constructor"] event) orelse not (isSome (W.lookup (spelled,name))) then () else
            (case firstName (event,name) of NONE => () | SOME start =>
              case W.lookup (declared,nameKey (name,start)) of SOME found => found:=event:: !found
              | NONE => W.add (declared,nameKey (name,start),ref [event]))
          | _ => ()) events
        fun smallest ([],best)=best
          | smallest (event::rest,NONE)=smallest(rest,SOME event)
          | smallest (event::rest,SOME prior)=smallest(rest,SOME(if #stop event- #start event< #stop prior- #start prior then event else prior))
        fun named (entry:entry)=smallest(List.filter (fn event => contains (event,#start entry,#stop entry))
          (case W.lookup (declared,nameKey (#name entry,#start entry)) of SOME found => List.rev (!found) | NONE => []),NONE)
        val values=nesting (List.filter (kindIn ["DVal","DValRec"]) events)
        val firstExpression=firstWithin (List.filter (fn event:C.Syntax.event => String.isPrefix "E" (#kind event)) events)
        val firstType=firstWithin (List.filter (fn event:C.Syntax.event => String.isPrefix "Ty" (#kind event)) events)
        val valueStops=Vector.fromList (List.mapPartial (fn entry:entry =>
          if #category entry="value" then SOME (#start entry,#stop entry) else NONE) entries)
        (* whether exactly one value is named in event before an expression *)
        fun alone (event:C.Syntax.event,limit) =
          let fun lower (lo,hi)=if lo>=hi then lo else
                let val mid=lo+(hi-lo) div 2
                in if #1 (Vector.sub (valueStops,mid))< #start event then lower (mid+1,hi) else lower (lo,mid) end
              fun count (at,found)=if at=Vector.length valueStops orelse found>1 then found else
                let val (start,stop)=Vector.sub (valueStops,at)
                in if start>=limit then found else count (at+1,if stop<=limit andalso stop<= #stop event then found+1 else found) end
          in count (lower (0,Vector.length valueStops),0)=1 end
        fun valueDeclaration (entry:entry)=
          case innermost (values,#start entry,#stop entry) of NONE=>NONE
          | SOME event=>
              (case firstExpression event of NONE=>NONE | SOME expression=>
                if #stop entry> #start expression orelse not (alone (event,#start expression)) then NONE
                else SOME(event,expression))
        val applied=W.table (length facts)
        val ()=List.app (fn fact:C.Analysis.fact => if null (#arguments fact) then () else
          W.add (applied,nameKey (Int.toString (#start fact),#stop fact),())) facts
        val outers=List.map (fn (tag,kind) => (tag,nesting (List.filter (fn event:C.Syntax.event => #kind event=kind andalso
          (case #values event of "1"::_=>true | _=>false)) events)))
          [("fundef","DFun"),("strbind","DStructure"),("sigbind","DSignature"),("funbind","DFunctor")]
        fun make (entry:entry):symbol =
          let val declaration=named entry
              val value=if #category entry="value" andalso not(isSome declaration) then valueDeclaration entry else NONE
              val functionValue=case value of NONE=>false | SOME(_,expression)=> #kind expression="EFn" orelse
                isSome (W.lookup (applied,nameKey (Int.toString (#start expression),#stop expression)))
              val functionSpec=case declaration of SOME event=> #kind event="valspec" andalso
                (case firstType event of SOME ty=> #kind ty="TyArrow" | NONE=>false) | NONE=>false
              val tag=case declaration of NONE=>"" | SOME event=> #kind event
              val kind=case #category entry of "structure"=>2 | "signature"=>11 | "functor"=>12 | "type"=>23
                | _=>if tag="constructor" then 22 else if tag="ExnDecl" orelse tag="ExnRepl" orelse tag="exnspec" then 14
                  else if tag="fundef" orelse functionValue orelse functionSpec then 12 else 13
              val span=case declaration of SOME event=>
                    (case Option.mapPartial (fn (_,outer) => innermost (outer,#start event,#stop event))
                       (List.find (fn (name,_) => name=tag) outers) of SOME outer=>(#start outer,#stop outer)
                     | NONE=>(#start event,#stop event))
                | NONE=>(case value of SOME(event,_)=>(#start event,#stop event) | NONE=>(#start entry,#stop entry))
          in {name= #name entry,kind=kind,start= #1 span,stop= #2 span,selectionStart= #start entry,selectionStop= #stop entry} end
    in List.map make entries end
  fun flat (symbols:symbol list,uri,range)=List.map(fn item=>Json.Object
    [("name",Json.String(#name item)),("kind",Json.int(#kind item)),("location",Json.Object
      [("uri",Json.String uri),("range",range(#selectionStart item,#selectionStop item))])])symbols
  (* Each symbol under the smallest that strictly encloses it, the first of
     those of one span: a sweep in order of start, the longest first, with a
     stack of the spans open. *)
  fun nested (symbols:symbol list,range) =
    let val table=Vector.fromList symbols
        val count=Vector.length table
        val parents=Array.array (count,NONE)
        fun less (i,j)=
          let val a=Vector.sub (table,i) val b=Vector.sub (table,j)
          in #start a< #start b orelse #start a= #start b andalso (#stop a> #stop b orelse #stop a= #stop b andalso i<j) end
        val order=RuneLspStructure.sort less (List.tabulate (count,fn n => n))
        fun encloses (i,child:symbol)=
          let val parent=Vector.sub (table,i) in #start parent<= #start child andalso #stop child<= #stop parent end
        fun sweep ([],_)=()
          | sweep (i::rest,stack)=
              let val child=Vector.sub (table,i)
                  fun climb []=[] | climb (top::below)=if encloses (top,child) then top::below else climb below
                  val open'=climb stack
              in case open' of
                   top::_ =>
                     let val parent=Vector.sub (table,top)
                     in if #start parent= #start child andalso #stop parent= #stop child
                        then (Array.update (parents,i,Array.sub (parents,top));sweep (rest,open'))
                        else (Array.update (parents,i,SOME top);sweep (rest,i::open')) end
                 | [] => sweep (rest,[i]) end
        val ()=sweep (order,[])
        val children=Array.array (count,[])
        val roots=ref []
        val ()=List.app (fn i => case Array.sub (parents,i) of NONE => roots:=i:: !roots
          | SOME parent => Array.update (children,parent,i::Array.sub (children,parent))) (List.tabulate (count,fn n => count-1-n))
        fun emit i=
          let val item=Vector.sub (table,i)
          in Json.Object[("name",Json.String(#name item)),("kind",Json.int(#kind item)),
            ("range",range(#start item,#stop item)),("selectionRange",range(#selectionStart item,#selectionStop item)),
            ("children",Json.Array(List.map emit (Array.sub (children,i))))] end
    in List.map emit (!roots) end
end
