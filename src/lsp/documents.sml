(* Versioned immutable document snapshots. Synchronization health, save
   observations and the highest seen client version are separate state. *)
structure RuneLspDocuments =
struct
  structure P=LspProtocol
  structure M=LspPosition
  type snapshot={uri:string,languageId:string,version:IntInf.int,revision:IntInf.int,content:M.t}
  type saveState={announced:IntInf.int option,payloadRevision:IntInf.int option}
  type entry={snapshot:snapshot,seen:IntInf.int,desynchronized:bool,save:saveState}
  type limits={maxDocuments:int,maxDocumentBytes:int,maxTotalBytes:int,
               maxDocumentLines:int,maxTotalLines:int}
  datatype t=Store of {documents:entry list ref,next:IntInf.int ref,encoding:P.encoding,limits:limits}
  datatype edit=Replace of string | Change of {range:P.range,text:string,rangeLength:IntInf.int option}
  exception Rejected of string
  fun new (encoding,limits:limits) =
    if #maxDocuments limits<1 orelse #maxDocumentBytes limits<0 orelse #maxTotalBytes limits< #maxDocumentBytes limits
    orelse #maxDocumentLines limits<1 orelse #maxTotalLines limits< #maxDocumentLines limits
    then raise Domain else Store {documents=ref [],next=ref 0,encoding=encoding,limits=limits}
  fun lookup (Store {documents,...},uri) = List.find (fn e:entry => #uri (#snapshot e)=uri) (!documents)
  fun snapshot (store,uri) = Option.map #snapshot (lookup (store,uri))
  fun healthy (store,uri) = case lookup (store,uri) of SOME e => not (#desynchronized e) | NONE => false
  fun all (Store {documents,...}) = List.map #snapshot (!documents)
  fun validVersion n = IntInf.>= (n,P.minInteger) andalso IntInf.<= (n,P.maxInteger)
  fun put (Store {documents,...},entry:entry) =
    documents:=entry :: List.filter (fn e:entry => #uri (#snapshot e)<> #uri (#snapshot entry)) (!documents)
  fun fresh (Store {next,...}) = let val revision= !next in next:=IntInf.+ (revision,1);revision end
  fun quota (store as Store {limits,...},uri) =
    let val (bytes,lines)=List.foldl (fn (s:snapshot,(bytes,lines)) =>
          if #uri s=uri then (bytes,lines) else (bytes+size (M.text (#content s)),lines+M.lineCount (#content s))) (0,0) (all store)
    in {bytes=Int.min (#maxDocumentBytes limits,#maxTotalBytes limits-bytes),
        lines=Int.min (#maxDocumentLines limits,#maxTotalLines limits-lines)} end
  fun content (store,uri,text) =
    let val budget=quota (store,uri)
        val ()=if size text> #bytes budget then raise Rejected "document text exceeds its byte limit" else ()
        val ()=if #lines budget<1 then raise Rejected "document index exceeds its line limit" else ()
    in M.bounded {text=text,maxLines= #lines budget}
       handle M.Invalid => raise Rejected "document text is not valid UTF-8"
            | M.Limit => raise Rejected "document index exceeds its line limit" end
  fun openDocument (store as Store {documents,limits,...},{uri,languageId,version,text}) =
    if not (validVersion version) then raise Rejected "invalid document version"
    else if uri="" orelse not (Utf8.isValid uri andalso Utf8.isValid languageId) then raise Rejected "invalid document identity"
    else if isSome (lookup (store,uri)) then raise Rejected "document is already open"
    else if length (!documents)>= #maxDocuments limits then raise Rejected "too many open documents"
    else let val ()=(ignore (LspUri.parse uri) handle LspUri.Invalid => raise Rejected "invalid document URI")
             val document=content (store,uri,text)
             val result:snapshot={uri=uri,languageId=languageId,version=version,revision=fresh store,content=document}
         in put (store,{snapshot=result,seen=version,desynchronized=false,save={announced=NONE,payloadRevision=NONE}});result end
  fun closeDocument (store as Store {documents,...},uri) =
    case lookup (store,uri) of NONE => raise Rejected "document is not open"
    | SOME _ => documents:=List.filter (fn e:entry => #uri (#snapshot e)<>uri) (!documents)
  fun current (store,s:snapshot) =
    case lookup (store,#uri s) of NONE => false
    | SOME e => not (#desynchronized e) andalso #revision (#snapshot e)= #revision s
  fun encodedLength (encoding,text) =
    Utf8.foldl (fn (scalar,n) => IntInf.+ (n,IntInf.fromInt
      (case encoding of P.Utf8 => size (Utf8.encode scalar) | P.Utf16 => if scalar>0xFFFF then 2 else 1 | P.Utf32 => 1))) 0 text
  fun changeDocument (store as Store {encoding,...},{uri,version,changes}) =
    let val previous=case lookup (store,uri) of SOME e => e | NONE => raise Rejected "document is not open"
        val prior= #snapshot previous
        val ()=if validVersion version then () else raise Rejected "invalid document version"
        val ()=if IntInf.> (version,#seen previous) then () else raise Rejected "stale document version"
        fun desynchronize message =
          (put (store,{snapshot=prior,seen=version,desynchronized=true,save= #save previous});raise Rejected message)
        fun apply (Replace text,_) = content (store,uri,text)
          | apply (Change {range={start,stop},text,rangeLength},document) =
            let val ()=if IntInf.< (#line start,#line stop) orelse
                  (#line start= #line stop andalso IntInf.<= (#character start,#character stop))
                  then () else raise Rejected "edit range is reversed"
                val old=M.text document
                val a=case M.offset (document,encoding,start) of SOME n => n | NONE => raise Rejected "edit starts inside a character"
                val b=case M.offset (document,encoding,stop) of SOME n => n | NONE => raise Rejected "edit ends inside a character"
                val ()=if a<=b then () else raise Rejected "edit range is reversed"
                val ()=if Utf8.isValid text then () else raise Rejected "replacement text is not valid UTF-8"
                val ()=case rangeLength of NONE => () | SOME expected =>
                  if IntInf.>= (expected,0) andalso IntInf.<= (expected,P.maxInteger) andalso
                    expected=encodedLength (encoding,String.substring (old,a,b-a)) then () else raise Rejected "edit length differs"
                val length=size old-(b-a)
                val budget=quota (store,uri)
                val ()=if size text<= #bytes budget-length then () else raise Rejected "document text exceeds its byte limit"
                val ()=if #lines budget>=1 then () else raise Rejected "document index exceeds its line limit"
            in M.editBounded {document=document,start=a,stop=b,text=text,maxLines= #lines budget}
               handle M.Limit => raise Rejected "document index exceeds its line limit" end
        fun work () =
          let val ()=if not (#desynchronized previous) then () else
                (case changes of Replace _ :: _ => () | _ => raise Rejected "document requires a full replacement")
              val result=List.foldl apply (#content prior) changes
              val updated:snapshot={uri=uri,languageId= #languageId prior,version=version,revision=fresh store,content=result}
          in put (store,{snapshot=updated,seen=version,desynchronized=false,save= #save previous});updated end
    in work () handle Rejected message => desynchronize message end
  fun quarantine (store,{uri,version}) =
    case lookup (store,uri) of NONE => () | SOME e =>
      let val seen=case version of NONE => #seen e
            | SOME version => if validVersion version andalso IntInf.> (version,#seen e) then version else #seen e
          val stale=case version of SOME version => validVersion version andalso IntInf.<= (version,#seen e) | NONE => false
      in if stale then () else put (store,{snapshot= #snapshot e,seen=seen,desynchronized=true,save= #save e}) end
  fun willSave (store,uri) =
    case lookup (store,uri) of NONE => raise Rejected "document is not open"
    | SOME e => if #desynchronized e then raise Rejected "document requires a full replacement"
        else put (store,{snapshot= #snapshot e,seen= #seen e,desynchronized=false,
          save={announced=SOME (#revision (#snapshot e)),payloadRevision= #payloadRevision (#save e)}})
  fun saved (store,{uri,text}) =
    case lookup (store,uri) of NONE => raise Rejected "document is not open"
    | SOME e =>
        let val document= #snapshot e
            val agrees=Option.map (fn text => text=M.text (#content document)) text
            val revision=if agrees=SOME true andalso not (#desynchronized e) then SOME (#revision document) else NONE
            val ()=put (store,{snapshot=document,seen= #seen e,desynchronized= #desynchronized e,
              save={announced=NONE,payloadRevision=revision}})
        in {snapshot=document,agrees=agrees} end

end
