(* Decode document synchronization at the protocol boundary. A malformed
   transition quarantines its identified document without applying edits. *)
structure RuneLspSync =
struct
  structure P=LspProtocol
  structure D=RuneLspDocuments
  exception Invalid of string
  datatype event = Opened of D.snapshot | Changed of D.snapshot
    | Closed of D.snapshot | WillSave of D.snapshot
    | Saved of {snapshot:D.snapshot,agrees:bool option}
  val methods=["textDocument/didOpen","textDocument/didChange","textDocument/didClose",
               "textDocument/willSave","textDocument/didSave"]

  fun object (value as Json.Object _) = value
    | object _ = raise Invalid "expected an object"
  fun member (Json.Object fields,name) =
        let fun find ([],found)=found
              | find ((key,value)::rest,found) =
                  if key<>name then find (rest,found)
                  else case found of NONE => find (rest,SOME value)
                    | SOME _ => raise Invalid ("duplicate field: " ^ name)
        in find (fields,NONE) end
    | member _ = raise Invalid "expected an object"
  fun required (value,name) = case member (value,name) of SOME field => field
    | NONE => raise Invalid ("missing field: " ^ name)
  fun string (Json.String text) = if Utf8.isValid text then text else raise Invalid "malformed UTF-8 string"
    | string _ = raise Invalid "expected a string"
  fun integer value = case P.integer value of SOME n => n | NONE => raise Invalid "expected an LSP integer"
  fun params NONE = raise Invalid "missing synchronization parameters"
    | params (SOME value) = object value
  fun document value = object (required (value,"textDocument"))
  fun uri value = string (required (value,"uri"))
  fun snapshot (store,uri) = case D.snapshot (store,uri) of SOME value => value
    | NONE => raise D.Rejected "document is not open"
  fun edit value =
    let val value=object value
        val text=string (required (value,"text"))
    in case member (value,"range") of
      NONE => D.Replace text
    | SOME range =>
        let val range=case P.rangeFromJson range of SOME range => range | NONE => raise Invalid "invalid edit range"
            val length=case member (value,"rangeLength") of NONE => NONE
              | SOME value => (case P.uinteger value of SOME n => SOME n | NONE => raise Invalid "invalid edit length")
        in D.Change {range=range,text=text,rangeLength=length} end
    end
  fun changes (Json.Array values) = List.map edit values
    | changes _ = raise Invalid "contentChanges must be an array"
  fun handleNotification (store,{method,params=raw}) =
    case method of
      "textDocument/didOpen" =>
        let val item=document (params raw)
        in SOME (Opened (D.openDocument (store,{uri=uri item,
             languageId=string (required (item,"languageId")),version=integer (required (item,"version")),
             text=string (required (item,"text"))}))) end
    | "textDocument/didChange" =>
        let val value=params raw
            val item=document value
            val uri=uri item
            val version=(Option.mapPartial P.integer (member (item,"version")) handle Invalid _ => NONE)
            fun change () = D.changeDocument (store,{uri=uri,version=integer (required (item,"version")),
              changes=changes (required (value,"contentChanges"))})
        in SOME (Changed (change ()))
           handle Invalid message => (D.quarantine (store,{uri=uri,version=version});raise Invalid message) end
    | "textDocument/didClose" =>
        let val uri=uri (document (params raw))
            val previous=snapshot (store,uri)
        in D.closeDocument (store,uri);SOME (Closed previous) end
    | "textDocument/willSave" =>
        let val value=params raw
            val uri=uri (document value)
            val reason=integer (required (value,"reason"))
            val ()=if IntInf.>= (reason,1) andalso IntInf.<= (reason,3) then () else raise Invalid "invalid save reason"
        in D.willSave (store,uri);SOME (WillSave (snapshot (store,uri))) end
    | "textDocument/didSave" =>
        let val value=params raw
            val uri=uri (document value)
            val text=Option.map string (member (value,"text"))
        in SOME (Saved (D.saved (store,{uri=uri,text=text}))) end
    | _ => NONE
end
