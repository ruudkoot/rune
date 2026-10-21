(* Pinned benchmark inventory primitives. This model does not execute an
   upstream program, build description or interpolation in an input file. *)
structure GenerateInventoryBase =
struct
  open MeasureCommon
  structure T=GenerateText
  type row=(string*string) list
  val fieldsOrder=String.tokens Char.isSpace "source path name rune_name milestone disposition family related authors sha256 members inputs notices evidence reason"
  val remembered=ref (NONE:Json.value option)
  fun review ()=case !remembered of SOME cfg => cfg | NONE => let val cfg=readJson (fromRoot "tools/generate/data/inventory-review.json") in remembered:=SOME cfg;cfg end
  fun strings key=List.map text (array (field key (review ())))
  fun get key row=case List.find (fn (name,_) => name=key) row of SOME (_,v) => v | NONE => raise Failed ("missing inventory member " ^ key)
  fun set key value row=List.map (fn (name,old) => (name,if name=key then value else old)) row @ (if List.exists (fn (name,_) => name=key) row then [] else [(key,value)])
  fun jsonRow row=Json.Object (List.map (fn (key,v) => (key,Json.String v)) row)
  fun decodeRow v=List.map (fn (key,v) => (key,text v)) (object v)
  fun decodeRows v=List.map decodeRow (array v)
  fun jsonRows rows=Json.Array (List.map jsonRow rows)
  fun table path =
    let val contents=T.required path
        (* TSV uses CSV quoting, including embedded newlines and doubled quotes. *)
        val n=size contents
        fun parse i quoted field row rows =
          if i=n then if null field andalso null row then List.rev rows else List.rev (List.rev (String.implode (List.rev field)::row)::rows)
          else let val c=String.sub (contents,i)
          in if quoted then if c = #"\"" then if i+1<n andalso String.sub (contents,i+1) = #"\"" then parse (i+2) true (#"\""::field) row rows else parse (i+1) false field row rows
                    else parse (i+1) true (c::field) row rows
             else if c = #"\"" andalso null field then parse (i+1) true field row rows
             else if c = #"\t" then parse (i+1) false [] (String.implode (List.rev field)::row) rows
             else if c = #"\n" then parse (i+1) false [] [] (List.rev (String.implode (List.rev field)::row)::rows)
             else if c = #"\r" andalso i+1<n andalso String.sub (contents,i+1) = #"\n" then parse (i+1) false field row rows
             else parse (i+1) false (c::field) row rows end
        val records=parse 0 false [] [] []
    in case records of [] => [] | header::rows =>
         (if OS.Path.file path="inventory.tsv" then need (header=fieldsOrder,"wrong inventory columns") else ();
          List.map (fn row => (need (length row=length header,"malformed table row in " ^ path);ListPair.zip (header,row))) rows) end
  fun utf8 text=Utf8.implode (Utf8.explode text)
  fun readText file=T.replace (T.replace (utf8 (binary file)) "\r\n" "\n") "\r" "\n"
  fun short n text=String.concat (List.map Utf8.encode (let val cps=Utf8.explode text in List.take (cps,Int.min (n,length cps)) end))
  fun pathLess (a,b) =
    let fun compare ([],[])=false | compare ([],_)=true | compare (_,[])=false
          | compare (a::ar,b::br)=if a=b then compare (ar,br) else a<b
    in compare (fields #"/" a,fields #"/" b) end
  fun relative root path =
    if path=root then "." else if String.isPrefix (root ^ "/") path then String.extract (path,size root+1,NONE) else raise Failed ("path outside inventory root " ^ path)
  fun normal path=GenerateMLB.normalise path
  fun resolve root path=let val path=normal (if OS.Path.isAbsolute path then path else root ^ "/" ^ path)
                       in if exists path then OS.FileSys.fullPath path else path end
  fun inside root path=path=root orelse String.isPrefix (root ^ "/") path
  fun regular path=exists path andalso not (isDir path)
  fun upstream root path=not (List.exists (fn part => List.exists (fn denied => part=denied) [".cm",".git","MLB","_build","dist-newstyle","__pycache__"]) (fields #"/" (relative root path)))
  fun allFiles directory =
    if OS.FileSys.isLink directory andalso isDir directory then [] else if isDir directory then
      List.concat (List.map (fn name => allFiles (directory ^ "/" ^ name)) (sort (entries directory))) else [directory]
  fun immediate directory=List.map (fn name => directory ^ "/" ^ name) (sort (entries directory))
  fun extension path=case OS.Path.ext path of NONE => "" | SOME ext => "." ^ ext
  fun hasExt allowed path=List.exists (fn ext => ext=extension path) allowed
  fun codeOnly haskell text =
    let val n=size text
        fun at i=String.sub (text,i)
        fun pair i a b=i+1<n andalso at i=a andalso at (i+1)=b
        fun opening i=if haskell then if pair i #"{" #"-" then SOME (#"-",#"}") else NONE
                      else if pair i #"(" #"*" then SOME (#"*",#")") else if pair i #"/" #"*" then SOME (#"*",#"/") else NONE
        fun lineEnd i=if i=n orelse at i = #"\n" then i else lineEnd (i+1)
        fun loop i comments string acc =
          if i>=n then String.implode (List.rev acc) else
           case comments of (a,b)::rest =>
             (case opening i of SOME finish => loop (i+2) (finish::comments) false acc | NONE =>
                if pair i a b then loop (i+2) rest false acc else loop (i+1) comments false ((if at i = #"\n" then #"\n" else #" ")::acc))
            | [] => if string then if at i = #"\\" then loop (i+2) [] true acc else if at i = #"\"" then loop (i+1) [] false acc
                         else loop (i+1) [] true ((if at i = #"\n" then #"\n" else #" ")::acc)
              else case opening i of SOME finish => loop (i+2) [finish] false (#" "::acc) | NONE =>
                 if haskell andalso pair i #"-" #"-" then loop (lineEnd i) [] false acc
                 else if at i = #"\"" then loop (i+1) [] true (#" "::acc) else loop (i+1) [] false (at i::acc)
    in loop 0 [] false [] end
  fun haskellCode file =
    let val raw=readText file
        fun blocks text acc=case T.splitAt "\\begin{code}" text of NONE => List.rev acc | SOME (_,rest) =>
              (case T.splitAt "\\end{code}" rest of NONE => List.rev acc | SOME (body,rest) => blocks rest (body::acc))
        val code=if extension file<>".lhs" then raw else
             case blocks raw [] of [] => String.concatWith "\n" (List.mapPartial (fn line =>
                  let val line=Substring.string (Substring.dropl (fn c => c = #" " orelse c = #"\t") (Substring.full line))
                  in if String.isPrefix ">" line then SOME (T.prefix " " (String.extract (line,1,NONE))) else NONE end) (String.fields (fn c => c = #"\n") raw))
                | pieces => String.concatWith "\n" pieces
    in codeOnly true code end
  fun quoted text =
    let val n=size text
        fun loop i acc=if i>=n then List.rev acc else if String.sub (text,i)<> #"\"" then loop (i+1) acc else
             let fun finish j=if j>=n orelse String.sub (text,j) = #"\n" then NONE else if String.sub (text,j) = #"\"" then SOME j else finish (j+1)
             in case finish (i+1) of NONE => loop (i+1) acc | SOME j => loop (j+1) (String.substring (text,i+1,j-i-1)::acc) end
    in loop 0 [] end
  fun digest root files =
    let fun one (file,state)=Sha256.update (Sha256.update (Sha256.update (state,relative root file ^ "\000"),binary file),"\000")
    in Hex.fromBytes (Sha256.finish (List.foldl one Sha256.empty files)) end
  fun includes root files =
    let val known=ref files
        fun walk []=() | walk (member::pending)=
          let val names=List.concat (List.map (fn line => if T.matches "^[ \t]*#[ \t]*include[ \t]*\"" line then quoted line else []) (lines (readText member)))
              val added=List.mapPartial (fn name => let val dep=resolve (OS.Path.dir member) name
                        in if inside root dep andalso regular dep andalso upstream root dep andalso not (List.exists (fn old => old=dep) (!known)) then (known:= !known @ [dep];SOME dep) else NONE end) names
          in walk (List.rev added @ pending) end
        val ()=walk (List.filter (hasExt [".hs",".lhs",".c",".h"]) files)
    in sorted pathLess (!known) end
  fun importNames source =List.mapPartial (fn line => if not (T.matches "^[ \t]*import[ \t]+" line) then NONE else
       let val words=String.tokens Char.isSpace line val tail=if length words>1 andalso List.nth (words,1)="qualified" then List.drop (words,2) else tl words
       in case tail of name::_ => if size name>0 andalso Char.isUpper (String.sub (name,0)) then SOME (Substring.string (Substring.takel (fn c => Char.isAlphaNum c orelse c = #"_" orelse c = #".") (Substring.full name))) else NONE | _ => NONE end) (lines source)
  fun sourceFiles root path =
    let val p=resolve root path
    in if isDir p then includes root (List.filter (fn q => regular q andalso hasExt (strings "EXTENSIONS") q andalso upstream root q) (allFiles p)) else
      let val files=ref (if exists p then [p] else [])
          fun visit []=() | visit (member::pending)=
             let val deps=List.mapPartial (fn module =>
                    let val name=T.replace module "." "/"
                        fun find []=NONE | find (base::rest)=case List.find regular [base ^ "/" ^ name ^ ".hs",base ^ "/" ^ name ^ ".lhs"] of NONE => find rest | found => found
                    in find [OS.Path.dir p,root ^ "/common"] end) (importNames (haskellCode member))
                 val added=List.filter (fn dep => not (List.exists (fn old => old=dep) (!files))) (T.distinct deps)
             in files:= !files @ added;visit (List.rev added @ pending) end
          val ()=if hasExt [".hs",".lhs"] p andalso exists p then visit [p] else ()
          val ()=if extension p=".mlb" andalso exists p then
             let val pattern=TerminalPattern.compile false "[A-Za-z0-9_./-]+\\.(sml|sig|mlb)"
                 val source=readText p
                 fun loop i=case TerminalPattern.find pattern source i of NONE => () | SOME (a,b) =>
                      let val member=normal (OS.Path.dir p ^ "/" ^ String.substring (source,a,b-a))
                      in if regular member andalso not (List.exists (fn old => old=member) (!files)) then files:= !files @ [member] else ();loop b end
             in loop 0 end else ()
      in includes root (!files) end end
end
