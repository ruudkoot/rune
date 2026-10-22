structure GenerateInventory =
struct
  open GenerateInventoryBase
  structure D=GenerateInventoryDiscover
  fun validate rows locks =
    let val seen=ref [] : (string*string) list ref
        fun one row =
          let val key=(get "source" row,get "path" row) val label="('" ^ #1 key ^ "', '" ^ #2 key ^ "')"
              val ()=need (not (List.exists (fn old => old=key) (!seen)) andalso List.exists (fn (source,_) => source= #1 key) locks,"duplicate or unknown inventory key " ^ label)
              val ()=seen:=key:: !seen
          in need (List.exists (fn kind => kind=get "disposition" row) ["import","duplicate","defer","exclude"],"bad disposition " ^ label);
             need (get "reason" row<>"" andalso get "evidence" row<>"" andalso get "rune_name" row<>"","missing audit metadata " ^ label);
             need (size (get "sha256" row)=64 andalso CharVector.all (fn c => Char.isDigit c orelse (c>= #"a" andalso c<= #"f")) (get "sha256" row),"bad source digest " ^ label) end
        val ()=List.app one rows
        val names=List.map (get "rune_name") (List.filter (fn row => get "disposition" row="import") rows)
        val ()=need (length names=length (T.distinct names),"colliding proposed import names")
        val ()=List.app (fn (source,lock) => case List.find (fn (key,_) => key="entries") lock of NONE => () | SOME (_,value) =>
                    let val count=length (List.filter (fn row => get "source" row=source) rows)
                    in need (count=integer value,"incomplete source inventory for " ^ source ^ ": " ^ Int.toString count) end) locks
    in () end
  fun query () =
    let val request=Json.decode (TextIO.inputAll TextIO.stdIn)
        val operation=text (field "operation" request) val args=field "arguments" request
        fun root ()=text (field "root" args)
        val reply=(Json.Object [("value",case operation of
             "build" => jsonRows (GenerateInventoryBuild.build (text (field "source" args)) (root ()) (decodeRow (field "lock" args)))
           | "family" => Json.String (D.family (text (field "name" args)) (text (field "text" args)))
           | "related" => jsonRows (D.related (decodeRows (field "rows" args)))
           | "names" => jsonRows (D.names (decodeRows (field "rows" args)))
           | "digest" => Json.String (digest (root ()) (List.map text (array (field "files" args))))
           | "source_files" => Json.Array (List.map Json.String (sourceFiles (root ()) (text (field "entry" args))))
           | "validate" => (validate (decodeRows (field "rows" args)) (List.map (fn (key,v) => (key,decodeRow v)) (object (field "locks" args)));Json.Null)
           | "table" => jsonRows (table (text (field "path" args)))
           | _ => raise Failed "unknown inventory query operation")]
           handle Failed why => Json.Object [("error",Json.String why)])
    in say (Json.encode reply ^ "\n");0 end
  fun quote cell=if CharVector.exists (fn c => c = #"\t" orelse c = #"\n" orelse c = #"\r" orelse c = #"\"") cell then "\"" ^ T.replace cell "\"" "\"\"" ^ "\"" else cell
  fun main ["--query"]=query ()
    | main args =
    let val sources=ref [] : (string*string) list ref val write=ref false val check=ref false
        fun parse []=() | parse ("--source"::value::rest)=
                (case T.splitAt "=" value of NONE => raise Usage "--source requires ID=DIR" | SOME (name,dir) => (sources:=(name,dir)::List.filter (fn (key,_) => key<>name) (!sources);parse rest))
          | parse ("--write"::rest)=(write:=true;parse rest) | parse ("--check"::rest)=(check:=true;parse rest)
          | parse _=raise Usage "inventory [--source ID=DIR ...] [--write|--check]"
        val ()=parse args val ()=need (not (!write andalso !check),"choose --write or --check")
        val suite=fromRoot "examples/benchmarks"
        val locks=List.map (fn row => (get "source" row,row)) (table (suite ^ "/upstreams.tsv"))
        val ()=if null (!sources) then need (not (!write),"--write requires all pinned sources") else
             need (sort (List.map #1 (!sources))=sort (List.map #1 locks),"supply all five pinned source trees")
        fun discover (source,lock) =
          let val dir=resolve (OS.FileSys.getDir ()) (GenerateRewrites.lookup source (!sources))
              val tmp=T.privateDirectory (fromRoot "tests/out/generate") ("inventory-" ^ source)
              fun git label args=trim (successful (execute root (tmp ^ "/" ^ label) (["git","--no-optional-locks","-C",dir] @ args)))
              val revision=git "revision" ["rev-parse","HEAD"]
              val ()=need (revision=get "revision" lock,"wrong revision for " ^ source ^ ": " ^ revision)
              val ()=need (git "status" ["status","--porcelain","--untracked-files=normal"]="","modified or untracked upstream sources: " ^ source)
          in GenerateInventoryBuild.build source dir lock end
        val rows=if null (!sources) then table (suite ^ "/inventory.tsv") else
             let val rows=D.names (List.concat (List.map discover locks)) val rows=sorted (fn (a,b) => get "source" a<get "source" b orelse (get "source" a=get "source" b andalso get "path" a<get "path" b)) rows
             in D.related rows end
        val ()=validate rows locks
        val ()=if !write then T.atomic (suite ^ "/inventory.tsv") (String.concatWith "\t" fieldsOrder ^ "\n" ^ String.concat (List.map (fn row => String.concatWith "\t" (List.map (quote o (fn key => get key row)) fieldsOrder) ^ "\n") rows))
               else if not (null (!sources)) then need (rows=table (suite ^ "/inventory.tsv"),"inventory differs from pinned discovery/classification; review before --write") else ()
        val ()=List.app (fn (source,_) => let val entries=List.filter (fn row => get "source" row=source) rows
                     val kinds=sort (T.distinct (List.map (get "disposition") entries))
                     val counts=List.map (fn kind => Int.toString (length (List.filter (fn row => get "disposition" row=kind) entries)) ^ " " ^ kind) kinds
                   in say (source ^ ": " ^ String.concatWith ", " counts ^ "\n") end) locks
    in say ("inventory: OK (" ^ Int.toString (length rows) ^ " entries)\n");0 end
end
