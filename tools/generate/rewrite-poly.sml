structure GenerateRewritePoly =
struct
  open MeasureCommon
  structure T=GenerateText
  fun main (settings:GenerateRewrites.settings) file =
    let val dispatch=ref [] : (string*string) list ref val last=ref ""
        fun bound line=case TerminalPattern.find (TerminalPattern.compile false "(^|[^A-Za-z0-9_'])(val|and|fun) +[A-Za-z][A-Za-z0-9_']*") line 0 of NONE => ""
              | SOME (a,b) => let val matched=String.substring (line,a,b-a) in List.last (String.tokens Char.isSpace matched) end
        fun set name value=dispatch:=(name,value)::List.filter (fn (old,_) => old<>name) (!dispatch)
        fun line line =
          let val line=T.substitute "RunCall\\.addOverload[^\"]*\"[^\"]*\"" (fn _ => "()") line
              val casts=[("word","int","wordToInt"),("int","word","intToWord"),("char","int","charToInt"),("int","char","intToChar")]
              val line=List.foldl (fn ((a,b,f),line) => T.substitute (": *" ^ a ^ " *-> *" ^ b ^ " *= *RunCall\\.unsafeCast") (fn _ => ": " ^ a ^ " -> " ^ b ^ " = XC2P." ^ f) line) line casts
              val name=bound line
              val ()=if name="" then () else (last:=name;dispatch:=List.filter (fn (old,_) => old<>name) (!dispatch))
              val direct=TerminalPattern.find (TerminalPattern.compile false "\"(PolyBasicIOGeneral|PolyOSSpecificGeneral)\"") line 0
              val ()=case direct of SOME (a,b) => if !last="" then () else set (!last) (String.substring (line,a+1,b-a-2)) | NONE =>
                    if name="" then () else
                      (case TerminalPattern.find (TerminalPattern.compile false ("(val|and) +" ^ name ^ "[^=]*= *[A-Za-z][A-Za-z0-9_']* *$")) line 0 of NONE => () | SOME (a,b) =>
                        let val rhs=trim (#2 (valOf (T.splitAt "=" (String.substring (line,a,b-a)))))
                        in case List.find (fn (key,_) => key=rhs) (!dispatch) of NONE => () | SOME (_,value) => set name value end)
              fun rewrite (name,target) line=T.substitute ("(^|[^A-Za-z0-9_'.])" ^ name ^ " *\\( *[0-9]+ *, *") (fn call =>
                    let val lead=if String.isPrefix name call then "" else String.substring (call,0,1)
                        val code=trim (hd (fields #"," (#2 (valOf (T.splitAt "(" (String.extract (call,size lead+size name,NONE)))))))
                        val id=target ^ "_" ^ code val ()=GenerateRewrites.emit settings id
                    in lead ^ "XC2PR." ^ id ^ " (" end) line
              val line=List.foldl (fn (binding,line) => rewrite binding line) line (!dispatch)
              val line=T.substitute "(RunCall\\.rtsCall(Full|Fast)[0-9]|(Real\\.|Real32\\.)?rtsCallFast(R_R|RR_R|RI_R|I_R|F_F|FF_F|FI_F|I_F)) *\"[A-Za-z0-9_]+\"" (fn call =>
                    let val name=List.nth (fields #"\"" call,1) val ()=GenerateRewrites.emit settings name in "XC2PR." ^ name end) line
          in line end
    in T.lineMap line (T.required file) end
end
