(* Implements: FOREIGN_COVERAGE *)
structure ForeignCoverage : FOREIGN_COVERAGE =
struct
  datatype state = Selected | Generated | Shimmed | Unselected | Unsupported of string
  type entry = {identity : ForeignModel.identity, source : ForeignModel.source, state : state}
  exception Error = ForeignModel.Error
  fun report {declarations, selected, generated, shimmed, unsupported} =
    let val unknown = {file="<coverage>",line=1,column=1}
        fun key identity = ForeignModel.key identity
        fun member identity values = List.exists(fn other=>key identity=key other)values
        fun fail message = raise Error(unknown,message)
        fun unique [] = () | unique(x::xs) =
          if member x xs then fail("duplicate coverage claim: " ^ #name x) else unique xs
        val () = List.app unique [selected,generated,shimmed,List.map #1 unsupported]
        val () = List.app(fn identity=>
          if member identity selected then () else fail("implementation claim is not selected: " ^ #name identity))
          (generated @ shimmed @ List.map #1 unsupported)
        val _ = ForeignModel.reachable(declarations,selected)
        fun entry (declaration:ForeignModel.declaration) =
          let val identity= #identity declaration
              val rejected=List.find(fn (other,_)=>key other=key identity)unsupported
              val implemented=member identity generated
              val adapted=member identity shimmed
              val ()=if (implemented andalso adapted) orelse
                  (isSome rejected andalso (implemented orelse adapted)) then
                  fail("conflicting implementation states: " ^ #name identity) else ()
              val state=case rejected of SOME(_,reason)=>Unsupported reason | NONE=>
                if adapted then Shimmed else if implemented then Generated else
                if member identity selected then Selected else Unselected
          in {identity=identity,source= #source declaration,state=state} end
        fun dedup _ []=[]
          | dedup previous ((x:ForeignModel.declaration)::xs)=
              let val name=key(#identity x)
              in if previous=SOME name then dedup previous xs else x::dedup(SOME name)xs end
    in List.map entry (dedup NONE (ForeignModel.canonical declarations)) end
  fun json entries =
    let fun one ({identity={family,namespace,name},source={file,line,column},state}:entry) =
          Json.Object ([
            ("family",Json.String family),("namespace",Json.String namespace),("foreign",Json.String name),
            ("source",Json.Object[("file",Json.String file),("line",Json.int line),("column",Json.int column)]),
            ("state",Json.String(case state of Selected=>"selected" | Generated=>"generated" |
              Shimmed=>"shimmed" | Unselected=>"unselected" | Unsupported _=>"unsupported"))]
            @ (case state of Unsupported reason=>[("reason",Json.String reason)] | _=>[]))
    in Json.Array(List.map one entries) end
end
