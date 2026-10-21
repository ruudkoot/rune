(* ML Basis source ordering, independent of a host compiler's elaborator. *)
structure GenerateMLB =
struct
  open MeasureCommon
  datatype item=File of string | Local | In | End
  fun normalise path =
    let fun step ("",parts)=parts | step (".",parts)=parts | step ("..",[])=[] | step ("..",_::rest)=rest | step (part,parts)=part::parts
    in "/" ^ String.concatWith "/" (List.rev (List.foldl step [] (fields #"/" path))) end
  fun tokenize text =
    let val n=size text
        fun pair i a b=i+1<n andalso String.sub (text,i)=a andalso String.sub (text,i+1)=b
        fun comment i depth=if i>=n then raise Failed "unterminated MLB comment" else if pair i #"(" #"*" then comment (i+2) (depth+1)
              else if pair i #"*" #")" then if depth=1 then i+2 else comment (i+2) (depth-1) else comment (i+1) depth
        fun quoted i=if i>=n then raise Failed "unterminated MLB string" else if String.sub (text,i) = #"\\" then quoted (i+2)
                 else if String.sub (text,i) = #"\"" then i+1 else quoted (i+1)
        fun loop i first acc =
          if i>=n then List.rev (if first<i then String.substring (text,first,i-first)::acc else acc)
          else if pair i #"(" #"*" then let val stop=comment (i+2) 1 in loop stop stop (if first<i then String.substring (text,first,i-first)::acc else acc) end
          else if String.sub (text,i) = #"\"" then let val stop=quoted (i+1) val acc=if first<i then String.substring (text,first,i-first)::acc else acc in loop stop stop (String.substring (text,i,stop-i)::acc) end
          else if Char.isSpace (String.sub (text,i)) orelse String.sub (text,i) = #";" then loop (i+1) (i+1) (if first<i then String.substring (text,first,i-first)::acc else acc)
          else loop (i+1) first acc
    in loop 0 0 [] end
  fun flatten vars path =
    let val seen=ref [] : string list ref val result=ref [] : item list ref
        fun emit item=result:=item:: !result
        fun substitute text count =
          if count>=1024 then raise Failed "recursive MLB path variable" else case GenerateText.splitAt "$(" text of NONE => text | SOME (pre,rest) =>
            (case GenerateText.splitAt ")" rest of NONE => raise Failed "unclosed MLB path variable" | SOME (name,tail) =>
                case List.find (fn (key,_) => key=name) vars of NONE => raise Failed ("mlb-flatten: no value for $(" ^ name ^ ")") | SOME (_,value) => substitute (pre ^ value ^ tail) (count+1))
        fun resolve directory path=let val p=substitute path 0 in normalise (if OS.Path.isAbsolute p then p else directory ^ "/" ^ p) end
        fun file path =
          if List.exists (fn old => old=path) (!seen) then () else
          let val ()=seen:=path:: !seen val ()=need (exists path,"missing MLB file: " ^ path)
              val tokens=Vector.fromList (tokenize (read path)) val n=Vector.length tokens
              fun tok i=if i<n then Vector.sub (tokens,i) else ""
              fun expect i token=if tok i=token then i+1 else raise Failed (path ^ ": expected " ^ token ^ ", found " ^ (if i<n then tok i else "the end"))
              fun keyword t=List.exists (fn word => word=t) ["local","in","end","ann","structure","signature","functor","basis","open","and","bas","let","_prim"]
              fun sources t=List.exists (fn suffix => String.isSuffix suffix t) [".sml",".sig",".fun",".mlb"]
              fun declarations i =
                if i>=n orelse tok i="in" orelse tok i="end" then i else
                let val t=tok i
                    val next=if t="local" then
                         let val ()=emit Local val i=expect (declarations (i+1)) "in" val ()=emit In val i=expect (declarations i) "end" in emit End;i end
                      else if t="ann" then
                         let fun skip j=if j>=n orelse tok j="in" then j else skip (j+1)
                         in expect (declarations (expect (skip (i+1)) "in")) "end" end
                      else if t="structure" orelse t="signature" orelse t="functor" then
                         let val j=i+2
                             val j=if tok j="=" then (need (tok (j+1)=tok (j-1),path ^ ": rebinding " ^ tok (j-1) ^ " = " ^ tok (j+1));j+2) else j
                             fun more j=if tok j="and" then more (if tok (j+2)="=" then j+4 else j+2) else j
                         in more j end
                      else if t="basis" then
                         let fun more j=if tok j="and" then more (expression (j+3)) else j
                         in more (expression (i+3)) end
                      else if t="open" then let fun skip j=if j>=n orelse keyword (tok j) orelse sources (tok j) then j else skip (j+1) in skip (i+1) end
                      else if t="_prim" then i+1
                      else if String.isSuffix ".mlb" t then (file (resolve (OS.Path.dir path) t);i+1)
                      else if sources t then (emit (File (resolve (OS.Path.dir path) t));i+1)
                      else raise Failed (path ^ ": cannot flatten " ^ t)
                in declarations next end
              and expression i=if tok i="bas" then expect (declarations (i+1)) "end"
                else if tok i="let" then
                    let val ()=emit Local val i=expect (declarations (i+1)) "in" val ()=emit In val i=expect (expression i) "end"
                    in emit End;i end else i+1
              val stop=declarations 0
          in need (stop=n,path ^ ": unexpected " ^ tok stop) end
        val ()=file (resolve (OS.FileSys.getDir ()) path)
    in List.rev (!result) end
  fun encode (File path)="file " ^ path | encode Local="local" | encode In="in" | encode End="end"
  fun main args =
    let fun parse vars ("--vars"::value::rest)=parse (List.map (fn word => case GenerateText.splitAt "=" word of SOME pair => pair | NONE => raise Usage "MLB variable must be NAME=VALUE") (String.tokens Char.isSpace value) @ vars) rest
          | parse vars [path]=(vars,path) | parse _ _=raise Usage "mlb-flatten [--vars 'NAME=VALUE ...'] FILE.mlb"
        val (vars,path)=parse [] args
    in say (String.concat (List.map (fn item => encode item ^ "\n") (flatten vars path)));0 end
end
