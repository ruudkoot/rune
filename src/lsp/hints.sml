(* Protocol presentation of frozen compiler-owned pattern type hints. *)
structure RuneLspHints =
struct
  structure P=LspProtocol
  structure J=RuneLspSync
  val maximum=2048
  fun member (value,[])=SOME value
    | member (value,name::rest)=Option.mapPartial (fn value => member (value,rest)) (Json.member (name,value))
  fun enabled capabilities=case member (capabilities,["textDocument","inlayHint"]) of SOME (Json.Object _) => true | _ => false
  fun resolving capabilities=enabled capabilities andalso
    (case member (capabilities,["textDocument","inlayHint","resolveSupport","properties"]) of
       SOME (Json.Array properties) => List.exists (fn value => value=Json.String "tooltip") properties | _ => false)
  fun provider capabilities=if enabled capabilities then SOME (Json.Object [("resolveProvider",Json.Bool (resolving capabilities))]) else NONE
  fun method name=name="textDocument/inlayHint" orelse name="inlayHint/resolve"
  fun supported (capabilities,name)=enabled capabilities andalso (name<>"inlayHint/resolve" orelse resolving capabilities)
  fun bounds (params,index,encoding) =
    let val {start,stop}=case P.rangeFromJson (J.required (params,"range")) of SOME range => range
          | NONE => raise J.Invalid "invalid inlay hint range"
        val ()=if #line start> #line stop orelse #line start= #line stop andalso #character start> #character stop
          then raise J.Invalid "reversed inlay hint range" else ()
    in case index of NONE => NONE | SOME index =>
      (case (LspPosition.offset (index,encoding,start),LspPosition.offset (index,encoding,stop)) of
         (SOME start,SOME stop) => SOME (start,stop)
       | _ => raise J.Invalid "inlay hint range splits an encoded character") end
  fun render {uri,snapshot,revision,generation,capabilities,index,encoding,hint:RuneCompiler.Analysis.typeHint,resolved,clean} =
    let val position=case LspPosition.position (index,encoding,#position hint) of SOME position => position
          | NONE => raise Fail "inlay hint has an invalid source boundary"
        val lazy=resolving capabilities
        val data=Json.Object [("uri",Json.String uri),("snapshot",Json.String snapshot),
          ("binding",Json.String (#binding hint)),("offset",Json.int (#position hint)),
          ("revision",Json.intInf revision),("generation",Json.intInf generation)]
    in Json.Object ([("position",P.positionToJson position),("label",Json.String (": " ^ clean (#ty hint))),
          ("kind",Json.int 1)] @
        (if lazy then [("data",data)] else []) @
        (if lazy andalso not resolved then [] else [("tooltip",Json.String (clean (#name hint ^ " : " ^ #ty hint)))])) end
  fun bounded hints=if length hints>maximum then raise Fail "inlay hint count budget exceeded" else
    let val result=Json.Array hints
    in if size (Json.encode result)>1024*1024 then raise Fail "inlay hint response budget exceeded" else result end
end
