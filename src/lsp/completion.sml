(* Completion presentation over the compiler's lexical scope query. Source
   slicing determines only the replacement; scope and visibility stay in the
   compiler. Every returned edit replaces the captured identifier prefix. *)
structure RuneLspCompletion =
struct
  structure A=RuneCompiler.Analysis
  val keywords=["abstype","and","andalso","as","case","datatype","do","else","end","eqtype",
    "exception","fn","fun","functor","handle","if","in","include","infix","infixr","let",
    "local","nonfix","of","op","open","orelse","raise","rec","sharing","sig","signature",
    "struct","structure","then","type","val","where","while","with","withtype"]
  fun nameByte c=Char.isAlphaNum c orelse Char.ord c>=128 orelse c= #"_" orelse c= #"'"
  fun symbolByte c=List.exists (fn byte => byte=c) (String.explode "!%&$#+-/:<=>?@\\~`^|*")
  fun prefix (text,offset) =
    let fun scan predicate i=if i>0 andalso predicate (String.sub (text,i-1)) then scan predicate (i-1) else i
        val from=if offset>0 andalso symbolByte (String.sub (text,offset-1)) then scan symbolByte offset else scan nameByte offset
        fun qualifiers at=if at>0 andalso String.sub (text,at-1)= #"." then
              let val beginning=scan nameByte (at-1)
              in if beginning=at-1 then at else qualifiers beginning end
            else at
        val beginning=qualifiers from
        val path=if beginning=from then [] else
          String.fields (fn c => c= #".") (String.substring (text,beginning,from-beginning-1))
    in {start=from,word=String.substring (text,from,offset-from),path=path} end
  fun kind name=case name of "function" => 3 | "constructor" => 4 | "exception" => 4
    | "value" => 6 | "type" => 25 | "structure" => 9 | "signature" => 8 | "functor" => 3 | _ => 1
  fun blocked (pieces:RuneCompiler.Syntax.piece list,offset)=List.exists
    (fn piece => #start piece<=offset andalso offset< #stop piece andalso
      List.exists (fn kind => kind= #kind piece) ["comment","string","character"]) pieces
  fun allowed (role,kind)=case role of "type" => kind="type" orelse kind="structure"
    | "expression" => List.exists (fn value => value=kind) ["value","function","constructor","exception","structure"]
    | "pattern" => List.exists (fn value => value=kind) ["constructor","exception","structure"]
    | "structure" => kind="structure" orelse kind="functor"
    | "signature" => kind="signature" | "field" => false | _ => true
  fun words role=case role of
      "expression" => ["andalso","case","fn","handle","if","let","op","orelse","raise","while"]
    | "pattern" => ["_","as","op"] | "type" => [] | "field" => [] | "structure" => ["let","struct"]
    | "signature" => ["datatype","eqtype","exception","include","sharing","sig","structure","type","val"]
    | "declaration" => ["abstype","and","datatype","exception","fun","functor","infix","infixr","local","nonfix","open","signature","structure","type","val"]
    | _ => keywords
  fun template (name,arguments) =
    let fun fields ([],index)=([],index)
          | fields (_::rest,index)=let val (tail,next)=fields (rest,index+1)
              in ("${" ^ Int.toString index ^ ":(raise Match)}" :: tail,next) end
        fun groups ([],_)=""
          | groups (group::rest,index)=let val (values,next)=fields (group,index)
              in " (" ^ String.concatWith ", " values ^ ")" ^ groups (rest,next) end
    in name ^ groups (arguments,1) ^ "$0" end
  fun items {text,offset,pieces,snapshot,uri,query,range,snippets} =
    if offset<0 orelse offset>size text orelse blocked (pieces,offset) then [] else
    let val {start,word,path}=prefix (text,offset)
        fun matching name=String.isPrefix word name
        val {role,candidates,fields}=query path
        val candidates=if not (null fields) then [] else List.filter
          (fn candidate:A.candidate => matching (#name candidate) andalso allowed (role,#kind candidate)) candidates
        fun item (candidate:A.candidate,isTemplate)=
          Json.Object ([("label",Json.String (#name candidate ^ (if isTemplate then " (...)" else ""))),("kind",Json.int (kind (#kind candidate))),
            ("sortText",Json.String (#name candidate)),("filterText",Json.String (#name candidate)),
            ("insertTextFormat",Json.int (if isTemplate then 2 else 1)),("textEdit",Json.Object
              [("range",range (start,offset)),("newText",Json.String
                (if isTemplate then template (#name candidate,#arguments candidate) else #name candidate))]),
            ("data",Json.Object [("snapshot",Json.String snapshot),("uri",Json.String uri),
              ("offset",Json.int offset),("name",Json.String (#name candidate)),("kind",Json.String (#kind candidate)),
              ("template",Json.Bool isTemplate)])] @
            (case #detail candidate of NONE => [] | SOME detail => [("detail",Json.String detail)]))
        val names=if not (null path) orelse not (null fields) then [] else List.filter matching (words role)
        val lexical=List.map (fn name => Json.Object [("label",Json.String name),("kind",Json.int 14),
          ("insertTextFormat",Json.int 1),("textEdit",Json.Object [("range",range (start,offset)),("newText",Json.String name)]),
          ("data",Json.Object [("snapshot",Json.String snapshot),("uri",Json.String uri),
            ("offset",Json.int offset),("name",Json.String name),("kind",Json.String "keyword")])]) names
        val fieldItems=List.map (fn (name,detail) => Json.Object [("label",Json.String name),("kind",Json.int 5),
          ("detail",Json.String detail),("insertTextFormat",Json.int 1),
          ("textEdit",Json.Object [("range",range (start,offset)),("newText",Json.String name)]),
          ("data",Json.Object [("snapshot",Json.String snapshot),("uri",Json.String uri),
            ("offset",Json.int offset),("name",Json.String name),("kind",Json.String "field")])])
          (List.filter (fn (name,_) => matching name) fields)
        val all=fieldItems @ List.concat (List.map (fn candidate:A.candidate => item (candidate,false) ::
          (if snippets andalso role="expression" andalso not (null (#arguments candidate))
            andalso nameByte (String.sub (#name candidate,0)) then [item (candidate,true)] else [])) candidates) @ lexical
    in List.take (all,Int.min (512,length all)) end
  fun inline {text,offset,pieces,query,range,selected} =
    if offset<0 orelse offset>size text orelse blocked (pieces,offset) then [] else
    let val {start,word,path}=prefix (text,offset)
        val {role,candidates,fields=_}=query path
        val start=start-List.foldl (fn (name,count) => count+size name+1) 0 path
        val replacementRange=range (start,offset)
        fun item (candidate:A.candidate)=
          let val name=String.concatWith "." (path @ [#name candidate])
              val inserted=if null (#arguments candidate) then name else
                "(" ^ name ^ " " ^ (case #arguments candidate of [domain] =>
                  if length domain>1 then "(" ^ String.concatWith ", " (List.map (fn _ => "_") domain) ^ ")" else "_"
                  | _ => "_") ^ ")"
              val compatible=case selected of NONE => true | SOME (selection,text) =>
                selection=replacementRange andalso String.isPrefix text inserted
          in if compatible then SOME (Json.Object [("insertText",Json.String inserted),
               ("filterText",Json.String name),("range",replacementRange)]) else NONE end
        val matching=List.filter (fn candidate:A.candidate => (role="pattern" orelse role="unknown") andalso
          (#kind candidate="constructor" orelse #kind candidate="exception") andalso
          nameByte (String.sub (#name candidate,0)) andalso String.isPrefix word (#name candidate)) candidates
        val items=List.mapPartial item matching
    in List.take (items,Int.min (8,length items)) end
  fun renderSignature (call:A.call,offsetLabels) =
    let fun units text=
          let fun count (at,total)=if at=size text then total else
                case Utf8.decode (text,at) of SOME (point,width) => count (at+width,total+(if point>65535 then 2 else 1))
                | NONE => count (at+1,total+1)
          in count (0,0) end
        fun fields ([],label,parameters)=(label,parameters)
          | fields (field::rest,label,parameters)=
              let val start=units label
                  val next=label ^ field
                  val parameter=Json.Object [("label",if offsetLabels then Json.Array [Json.int start,Json.int (units next)]
                    else Json.String field)]
              in fields (rest,next ^ (if null rest then "" else ", "),parameters @ [parameter]) end
        fun groups ([],label,parameters)=(label,parameters)
          | groups (group::rest,label,parameters)=
              let val (next,parameters)=fields (group,label ^ " (",parameters)
              in groups (rest,next ^ ")",parameters) end
        val (label,parameters)=groups (#arguments call,String.concatWith "." (#path call @ [#name call]),[])
        val preceding=List.foldl (fn (group,total) => total+length group) 0 (List.take (#arguments call,#argument call))
        val domain=List.nth (#arguments call,#argument call)
        val active=preceding+Int.min (#parameter call,Int.max (0,length domain-1))
    in Json.Object [("signatures",Json.Array [Json.Object [("label",Json.String (label ^ " : " ^ #detail call)),
         ("parameters",Json.Array parameters)]]),("activeSignature",Json.int 0),("activeParameter",Json.int active)] end
end
