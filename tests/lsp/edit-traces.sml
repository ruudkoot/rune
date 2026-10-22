(* Independent token-list editor: edit coordinates and expected text are
   computed without using the position index under test. *)
structure RuneLspEditTraces =
struct
  structure D=RuneLspDocuments
  structure M=LspPosition
  structure P=LspProtocol
  val seed=ref 17
  fun pick n = (seed:=(!seed*109+89) mod 32749; !seed mod n)
  fun need (true,_) = () | need (false,message) = raise Fail message
  fun normalize ("\r" :: "\n" :: rest)=normalize ("\r\n" :: rest)
    | normalize (x :: rest)=x :: normalize rest | normalize []=[]
  fun newline atom=atom="\r" orelse atom="\n" orelse atom="\r\n"
  fun width P.Utf8 atom=size atom
    | width P.Utf16 atom=if newline atom then size atom else if size atom=4 then 2 else 1
    | width P.Utf32 atom=if newline atom then size atom else 1
  fun position encoding atoms count =
    let val (line,column)=List.foldl (fn (atom,(line,column)) =>
          if newline atom then (line+1,0) else (line,column+width encoding atom)) (0,0) (List.take (atoms,count))
    in {line=IntInf.fromInt line,character=IntInf.fromInt column}:P.position end
  val alphabet=["a","b"," ","\204\129","\n","\r","\r\n","\240\144\144\128","\195\169","\239\187\191"]
  fun run encoding =
    let val uri="file:///random.sml"
        val store=D.new (encoding,{maxDocuments=2,maxDocumentBytes=200000,maxTotalBytes=300000,maxDocumentLines=10000,maxTotalLines=10000})
        val initial=normalize ["a","\240\144\144\128","\r\n","b"]
        val _=D.openDocument (store,{uri=uri,languageId="sml",version=0,text=String.concat initial})
        fun loop (501,atoms) = atoms
          | loop (step,atoms) =
            let val count=length atoms
                val a=pick (count+1)
                val b=a+pick (count-a+1)
                val inserted=List.tabulate (pick 4,fn _ => List.nth (alphabet,pick (length alphabet)))
                val removed=List.take (List.drop (atoms,a),b-a)
                val range={start=position encoding atoms a,stop=position encoding atoms b}
                val expected=normalize (List.take (atoms,a) @ inserted @ List.drop (atoms,b))
                val old=valOf (D.snapshot (store,uri))
                val snapshot=D.changeDocument (store,{uri=uri,version=IntInf.fromInt step,changes=
                  [D.Change {range=range,text=String.concat inserted,rangeLength=SOME (IntInf.fromInt
                    (List.foldl (fn (atom,n) => n+width encoding atom) 0 removed))}]})
                val ()=need (M.text (#content snapshot)=String.concat expected,"independent edit oracle differs")
                val ()=need (not (D.current (store,old)) andalso D.current (store,snapshot),"revision publication")
                val ()=List.app (fn at =>
                  let val offset=size (String.concat (List.take (expected,at)))
                  in need (M.offset (#content snapshot,encoding,position encoding expected at)=SOME offset,"position-to-offset oracle");
                     need (M.position (#content snapshot,encoding,offset)=SOME (position encoding expected at),"offset-to-position oracle") end)
                  (List.tabulate (length expected+1,fn at => at))
            in loop (step+1,expected) end
        val _=loop (1,initial)
    in () end
  fun main () = (seed:=17;List.app run [P.Utf8,P.Utf16,P.Utf32])
end
