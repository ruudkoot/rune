(* Coverage closure is metadata validation, not evidence of a passing execution. *)
structure BenchCoverage =
struct
  type source = {upstream:string, path:string, disposition:string,
                 identity:string, reason:string}
  fun fields line = String.fields (fn c => c = #"\t") (BenchCatalog.strip line)
  fun identity text =
    String.size text = 64 andalso
    List.all (fn c => (c >= #"0" andalso c <= #"9") orelse
                     (c >= #"a" andalso c <= #"f")) (String.explode text)
  fun disposition value = List.exists (fn s => s = value) ["import","duplicate","defer","exclude"]
  fun sources path =
    case BenchCatalog.lines path of
      [] => raise Fail "empty source inventory"
    | header::rows =>
        if BenchCatalog.strip header <>
          "source\tpath\tname\trune_name\tmilestone\tdisposition\tfamily\trelated\tauthors\tsha256\tmembers\tinputs\tnotices\tevidence\treason"
        then raise Fail "invalid coverage inventory header"
        else List.map (fn line =>
          case fields line of
            [upstream,path,_,_,_,status,_,_,_,sha,_,_,_,evidence,reason] =>
              if disposition status andalso identity sha andalso reason <> "" andalso evidence <> ""
              then {upstream=upstream,path=path,disposition=status,identity=sha,reason=reason}
              else raise Fail "incomplete coverage disposition"
          | _ => raise Fail "invalid coverage inventory row") rows

  fun names entries =
    List.rev (List.foldl (fn (entry:BenchCatalog.entry, names) =>
      if List.exists (fn name => name = #name entry) names then names else #name entry::names) [] entries)

  fun matching entries (source:source) =
    List.filter (fn (entry:BenchCatalog.entry) =>
      #upstream entry = #upstream source andalso #sourcePath entry = #path source) entries

  fun validate sources entries =
    let
      fun source (row:source) =
        if not(disposition(#disposition row)) orelse not(identity(#identity row)) orelse #reason row = ""
        then raise Fail "incomplete coverage disposition"
        else if #disposition row = "import" andalso List.null(matching entries row)
        then raise Fail ("unimplemented import: " ^ #upstream row ^ ":" ^ #path row)
        else ()
      fun entry (row:BenchCatalog.entry) =
        if #upstream row = "rune" then BenchCatalog.localFile (#sourcePath row)
        else case List.find (fn (source:source) => #upstream source = #upstream row andalso #path source = #sourcePath row) sources of
          NONE => raise Fail "unknown coverage source"
        | SOME source => if #disposition source = "import" then ()
                         else raise Fail "non-import source appears as runnable"
      fun unique [] _ = ()
        | unique ((row:source)::rest) seen =
            let val key=(#upstream row,#path row)
            in if List.exists (fn value => value=key) seen then raise Fail "duplicate coverage source"
               else unique rest(key::seen) end
      val _ = if List.null sources then raise Fail "empty source coverage" else ()
      val _ = unique sources []
      val _ = List.app source sources
    in List.app entry entries end

  fun companions path =
    case BenchCatalog.lines path of
      [] => raise Fail "empty companion inventory"
    | header::rows =>
        if BenchCatalog.strip header <>
          "upstream\trevision\tparent\tpath\tname\tlanguage\trole\tauthors\tsha256\tdisposition\treason\tnotices"
        then raise Fail "invalid companion inventory header"
        else
          let
            fun check line =
              case fields line of
                [upstream,revision,parent,path,name,language,role,authors,sha,status,reason,notices] =>
                  if List.all (fn s => s <> "") [upstream,revision,parent,path,name,language,role,authors,reason,notices]
                     andalso identity sha andalso disposition status then (upstream,path,name)
                  else raise Fail "incomplete companion disposition"
              | _ => raise Fail "invalid companion inventory row"
            fun unique [] _ = ()
              | unique (key::rest) seen =
                  if List.exists (fn value => value=key) seen then raise Fail "duplicate companion disposition"
                  else unique rest(key::seen)
            val keys=List.map check rows
            val _=unique keys []
          in List.length keys end

  fun documentation entries =
    let
      val lines=List.map BenchCatalog.strip (BenchCatalog.lines(BenchCatalog.root ^ "README.md"))
      fun check name =
        let
          val row="| [" ^ name ^ "](#" ^ String.map Char.toLower name ^ ") | "
          val heading="## " ^ name
          val _=if List.exists (String.isPrefix row) lines then () else raise Fail("missing linked overview: " ^ name)
          val _=if List.exists (fn line => line=heading) lines then () else raise Fail("missing benchmark section: " ^ name)
        in BenchCatalog.localFile(name ^ "/PROVENANCE.md") end
    in List.app check (names entries) end

  fun report sources entries =
    let
      val _=print "upstream\tsource_path\tdisposition\tinventory_sha256\tbenchmarks\tprofiles\tcoverage\treason\n"
      fun emit (row:source) =
        let val selected=matching entries row
            val coverage=if #disposition row="import" then "implemented" else #disposition row
        in print(String.concatWith "\t" [#upstream row,#path row,#disposition row,#identity row,
             String.concatWith ","(names selected),Int.toString(List.length selected),coverage,#reason row] ^ "\n") end
    in List.app emit sources end
end
