(* Frozen independent input/oracle data, with source digests. The rendering
   code is SML; cryptographic expectations stay independently established. *)
structure GenerateFixtures =
struct
  open MeasureCommon
  val directory=fromRoot "tools/generate/data"
  fun manifest ()=readJson (directory ^ "/fixtures.json")
  fun verified name =
    let val path=directory ^ "/" ^ name val expected=text (field name (field "sha256" (manifest ())))
    in need (hash path=expected,"generator input digest differs: " ^ name);read path end
  fun bytes text=case Hex.toBytes text of SOME s => s | NONE => raise Failed "invalid fixture hexadecimal"
  fun literal text="\"" ^ String.translate (fn c => if c = #"\"" orelse c = #"\\" then "\\" ^ str c
        else if Char.ord c>=32 andalso Char.ord c<127 then str c else "\\" ^ StringCvt.padLeft #"0" 3 (Int.toString (Char.ord c))) text ^ "\""
  fun entities [] =
    let val rows=List.map (fn line => case tabs line of [name,value] => (name,bytes value) | _ => raise Failed "invalid named entity input") (lines (verified "html-entities-v1.tsv"))
        val rows=sorted (fn ((a,_),(b,_)) => a<b) rows
        val version=text (field "python_version" (manifest ()))
        val ()=need (length rows=2125,"named entity input count differs")
        val output="(* The named character references of HTML5 and the UTF-8 of what each\n   stands for, by name, from Python " ^ version ^ "'s html.entities.html5;\n   written by scripts/gen-entities.py. *)\nstructure MarkdownEntities =\nstruct\n  val table : (string * string) vector = Vector.fromList [\n" ^
             String.concatWith ",\n" (List.map (fn (name,value) => "    (" ^ literal name ^ ", " ^ literal value ^ ")") rows) ^ "]\nend\n"
    in say output;0 end
    | entities _=raise Usage "entities (writes MarkdownEntities to stdout)"
  fun digest [] =
    let val rows=List.map (String.tokens Char.isSpace) (lines (verified "digest-vectors-v1.tsv"))
        val ()=need (length rows=134,"digest oracle vector count differs")
        fun row values=case values of [message,key,digest,mac] =>
             let fun hex "-"="-" | hex s=Hex.fromBytes (bytes s)
                 val ()=need (size digest=64 andalso size mac=64,"invalid SHA256/HMAC oracle field")
             in String.concatWith " " (List.map hex [message,key,digest,mac]) ^ "\n" end
          | _ => raise Failed "invalid independent digest vector"
    in say (String.concat (List.map row rows));0 end
    | digest _=raise Usage "digest-vectors (writes independently frozen vectors to stdout)"
end
