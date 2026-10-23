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
  fun items {text,offset,pieces,snapshot,uri,visible,range} =
    if offset<0 orelse offset>size text orelse blocked (pieces,offset) then [] else
    let val {start,word,path}=prefix (text,offset)
        fun matching name=String.isPrefix word name
        val candidates=List.filter (fn candidate:A.candidate => matching (#name candidate)) (visible path)
        fun item (candidate:A.candidate)=
          Json.Object ([("label",Json.String (#name candidate)),("kind",Json.int (kind (#kind candidate))),
            ("sortText",Json.String (#name candidate)),("filterText",Json.String (#name candidate)),
            ("insertTextFormat",Json.int 1),("textEdit",Json.Object
              [("range",range (start,offset)),("newText",Json.String (#name candidate))]),
            ("data",Json.Object [("snapshot",Json.String snapshot),("uri",Json.String uri),
              ("offset",Json.int offset),("name",Json.String (#name candidate)),("kind",Json.String (#kind candidate))])] @
            (case #detail candidate of NONE => [] | SOME detail => [("detail",Json.String detail)]))
        val names=if not (null path) then [] else List.filter matching keywords
        val lexical=List.map (fn name => Json.Object [("label",Json.String name),("kind",Json.int 14),
          ("insertTextFormat",Json.int 1),("textEdit",Json.Object [("range",range (start,offset)),("newText",Json.String name)]),
          ("data",Json.Object [("snapshot",Json.String snapshot),("uri",Json.String uri),
            ("offset",Json.int offset),("name",Json.String name),("kind",Json.String "keyword")])]) names
        val all=List.map item candidates @ lexical
    in List.take (all,Int.min (512,length all)) end
end
