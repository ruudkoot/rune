structure GenerateInventoryBuild =
struct
  open GenerateInventoryBase
  structure D=GenerateInventoryDiscover structure C=GenerateInventoryClassify
  fun safeReference text =
    let val cps=Utf8.explode text
    in not (null cps) andalso length cps<=240 andalso List.all (fn cp => cp>=128 orelse Char.isAlphaNum (Char.chr cp) orelse Char.contains "_./@+ -" (Char.chr cp)) cps end
  fun profileInputs root parent =
    let val file=parent ^ "/Makefile" val source=if regular file then T.replace (readText file) "\\\n" " " else ""
        val rows=List.mapPartial (fn line => if T.matches "^\\s*(FAST|NORM|SLOW)_OPTS\\s*[:?+]?=" line then Option.map #2 (T.splitAt "=" line) else NONE) (lines source)
        fun arguments text=CommandWords.split (hd (fields #"#" text))
        val args=List.concat (List.map arguments rows)
    in T.distinct (List.mapPartial (fn arg => let val reference=if String.isPrefix "--" arg then (case T.splitAt "=" arg of SOME (_,v) => v | NONE => arg) else arg
               val file=resolve parent reference
             in if safeReference reference andalso inside root file andalso regular file andalso upstream root file then SOME (relative root file) else NONE end) args) end
  fun pythonForm (D.Atom text)=
        let val quote=if String.isSubstring "'" text andalso not (String.isSubstring "\"" text) then #"\"" else #"'"
        in str quote ^ String.translate (fn c => if c=quote orelse c = #"\\" then "\\" ^ str c else if c = #"\n" then "\\n" else str c) text ^ str quote end
    | pythonForm (D.Form items)="[" ^ String.concatWith ", " (List.map pythonForm items) ^ "]"
  fun build source root lock =
    let val discovered=D.discover source root
        fun row (item:D.item) =
          let val path= #path item val originalName= !(#name item) val entry=root ^ "/" ^ path
              val forms=ref [] : string list ref
              fun sandmarkFiles ()=
                let val own=OS.Path.base entry ^ ".ml"
                    val files=ref (if regular own then [own] else if String.isPrefix "benchmarks/" path then sourceFiles root (relative root (OS.Path.dir entry)) else [])
                    val metadata=if String.isPrefix "benchmarks/" path andalso isDir (OS.Path.dir entry) then List.filter (fn file => regular file andalso (OS.Path.file file="dune" orelse String.isSuffix "-dune.inc" file)) (immediate (OS.Path.dir entry)) else []
                    val ()=files:= !files @ metadata
                    fun memberForm form =case form of D.Atom kind::entries =>
                      if kind<>"executable" andalso kind<>"executables" then () else
                        let val names=List.concat (List.mapPartial (fn D.Form (D.Atom key::values) => if key="name" orelse key="names" then SOME (List.mapPartial (fn D.Atom s => SOME s | _ => NONE) values) else NONE | _ => NONE) entries)
                        in if not (List.exists (fn name => name=OS.Path.base (OS.Path.file entry)) names) then () else
                            (forms:= !forms @ [pythonForm (D.Form form)];
                             List.app (fn D.Form (D.Atom "modules"::members) => List.app (fn D.Atom module =>
                                 if List.exists (fn name => name=module) names andalso module<>OS.Path.base (OS.Path.file entry) then () else
                                   let val file=OS.Path.dir entry ^ "/" ^ module ^ ".ml" in if regular file then files:=file:: !files else () end | _ => ()) members | _ => ()) entries) end
                      | _ => ()
                    val ()=List.app (fn file => List.app memberForm (D.walkForms (D.sexps (readText file)))) metadata
                in !files end
              val files=if source="sandmark" then sandmarkFiles () else sourceFiles root path
              val files=if source="nofib" andalso path="spectral/simple" andalso regular (entry ^ "/simple.f") then files @ [entry ^ "/simple.f"] else files
              val files=sorted pathLess (T.distinct files)
              val text=String.concatWith "\n" (List.map readText (List.filter (fn p => hasExt (strings "EXTENSIONS") p andalso not (hasExt [".cm",".mlb"] p)) files))
              val code=if source="nofib" then String.concatWith "\n" (List.map (C.featureCode root) files) else codeOnly false text
              val (milestone,disposition,reason)=C.classify source root item files (code ^ "\n" ^ String.concatWith "\n" (!forms))
              val name= !(#name item) val parent=if isDir entry then entry else OS.Path.dir entry
              val inputs=ref (if source="nofib" then profileInputs root parent else []) : string list ref
              val ()=if null files orelse not (isDir parent) orelse not (List.exists (fn prefix => String.isPrefix prefix path) ["programs/","benchmarks/","imaginary/","spectral/","real/","gc/","shootout/","parallel/","smp/"]) then () else
                    List.app (fn file => if upstream root file andalso regular file andalso
                        (OS.Path.file file="ANSWER" orelse hasExt [".in",".stdin",".stdout",".faststdin",".faststdout",".slowstdin",".slowstdout",".expected",".out",".ok"] file orelse List.exists (fn part => part="DATA") (fields #"/" (relative parent file)) orelse
                          (source="nofib" andalso List.exists (fn part => part="runtime_files") (fields #"/" (relative parent file)))) then inputs:=relative root file:: !inputs else ()) (allFiles parent)
              val inputText=T.substitute "^\\s*#\\s*include[^\n]*$" (fn _ => "") text
              val ()=List.app (fn reference =>
                    let val candidate=resolve parent reference
                    in if safeReference reference andalso inside root candidate andalso regular candidate then inputs:=relative root candidate:: !inputs else () end) (quoted inputText)
              val notices=ref (let val value=get "notices" lock in if value="" orelse value="-" then [] else fields #";" value end)
              val ()=if null files orelse not (isDir parent) orelse not (isDir entry orelse source="nofib" orelse (source="sandmark" andalso String.isPrefix "benchmarks/" path)) then () else
                    List.app (fn file => if regular file andalso upstream root file andalso T.matches "^(LICENSE|COPYING|COPYRIGHT)(\\.[A-Za-z0-9_-]+)?$" (String.map Char.toUpper (OS.Path.file file)) then notices:=relative root file:: !notices else ()) (allFiles parent)
              val authors=ref [] : string list ref
              val context=ref (if isDir parent andalso not (null files) then List.filter (fn file => regular file andalso List.exists (fn name => name=OS.Path.file file) ["README","README.md","Makefile","FILES","sources.cm"]) (immediate parent) else [])
              val credit={authors=authors,evidence= #evidence item,notices=notices,inputs=inputs,context=context}:GenerateInventoryCredits.credit
              val ()=GenerateInventoryCredits.parentFacts source path root parent credit
              val ()=List.app (fn file => #evidence item:=relative root file:: !(#evidence item)) (!context)
              val ()=GenerateInventoryCredits.headers source path root (files @ !context) credit
              val notices=if source="sandmark" andalso not (String.isPrefix "benchmarks/" path) then ["dependencies/template/*.opam (package sources and notices)"] else !notices
              fun joined values=String.concatWith ";" (sort (T.distinct values))
              val authors=joined (!authors)
              (* The frozen generator exports the FEM dataset loop's last
                 variable as its name. Preserve the existing inventory key. *)
              val name=if source="nofib" andalso path="real/fem" then "data.3" else name
              (* Preserve the frozen generator's final text variable in the
                 two reviewed attribution branches that rebind it. *)
              val familyText=if source="nofib" andalso path="spectral/para" andalso regular (parent ^ "/runtime_files/input-data") then readText (parent ^ "/runtime_files/input-data")
                   else if source="nofib" andalso (path="gc/linear" orelse path="real/linear") then
                     if regular (parent ^ "/Input.lhs") then readText (parent ^ "/Input.lhs") else if regular (parent ^ "/Main.lhs") then readText (parent ^ "/Main.lhs") else text
                   else text
          in [("source",source),("path",path),("name",name),("rune_name",name),("milestone",milestone),("disposition",disposition),("family",D.family name familyText),("related",""),
              ("authors",if authors="" then "not stated in scanned source headers" else authors),("sha256",digest root files),("members",String.concatWith ";" (List.map (relative root) files)),("inputs",joined (!inputs)),("notices",joined notices),("evidence",joined (!(#evidence item))),("reason",reason)] end
    in List.map row discovered end
end
