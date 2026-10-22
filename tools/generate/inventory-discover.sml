structure GenerateInventoryDiscover =
struct
  open GenerateInventoryBase
  datatype sexp=Atom of string | Form of sexp list
  type item={path:string,name:string ref,evidence:string list ref}
  fun sexps text =
    let val text=T.substitute ";;[^\n]*" (fn _ => "") text val n=size text
        fun quoted i=if i>=n then n else if String.sub (text,i) = #"\\" then quoted (i+2)
                  else if String.sub (text,i) = #"\"" then i+1 else quoted (i+1)
        fun word i=if i>=n orelse Char.isSpace (String.sub (text,i)) orelse Char.contains "()" (String.sub (text,i)) then i else word (i+1)
        fun tokenize i acc=if i>=n then List.rev acc else
             if Char.isSpace (String.sub (text,i)) then tokenize (i+1) acc
             else if Char.contains "()" (String.sub (text,i)) then tokenize (i+1) (str (String.sub (text,i))::acc)
             else let val stop=if String.sub (text,i) = #"\"" then quoted (i+1) else word i in tokenize stop (String.substring (text,i,stop-i)::acc) end
        fun strip text=Substring.string (Substring.dropr (fn c => c = #"\"") (Substring.dropl (fn c => c = #"\"") (Substring.full text)))
        fun parse [] true acc=(List.rev acc,[]) | parse [] false _=raise Failed "unbalanced Dune form"
          | parse (")"::rest) true _=raise Failed "unbalanced Dune form" | parse (")"::rest) false acc=(List.rev acc,rest)
          | parse ("("::rest) top acc=let val (nested,rest)=parse rest false [] in parse rest top (Form nested::acc) end
          | parse (token::rest) top acc=parse rest top (Atom (strip token)::acc)
    in #1 (parse (tokenize 0 []) true []) end
  fun walkForms items=List.concat (List.map (fn Atom _ => [] | Form items => items::walkForms items) items)
  fun isMain code=T.matches "^[ \t]*(module[ \t]+Main([^A-Za-z0-9_']|$)|main[ \t]*(::|=))" code
  fun discover source root =
    let val found=ref [] : item list ref
        fun add path name evidence =case List.find (fn (row:item) => #path row=path) (!found) of
             NONE => found:= !found @ [{path=path,name=ref name,evidence=ref [evidence]}]
           | SOME row => #evidence row:= !(#evidence row) @ [evidence]
        fun rel path=relative root path
        val ()=case source of
            "mlton" => List.app (fn p => add (rel p) (OS.Path.base (OS.Path.file p)) "benchmark/tests/Makefile") (glob (root ^ "/benchmark/tests",".sml"))
          | "smlnj" =>
             (List.app (fn p => if isDir p then add (rel p) (OS.Path.file p) "README.md;programs/*/sources.cm" else ()) (immediate (root ^ "/programs"));
              let val raw=readText (root ^ "/README.md") val expression=TerminalPattern.compile false "\\[`[^`]+`\\]\\(programs/"
                  fun loop start=case TerminalPattern.find expression raw start of NONE => () | SOME (a,b) =>
                     let val matched=String.substring (raw,a,b-a) val name=List.nth (fields #"`" matched,1)
                     in add ("programs/" ^ name) name "README.md";loop b end
              in loop 0 end)
          | "mlkit" => List.app (fn folder => List.app (fn p => if regular p andalso hasExt [".sml",".mlb"] p then add (rel p) (OS.Path.base (OS.Path.file p)) "test/all.tst;test_dev/Makefile" else ()) (immediate (root ^ "/" ^ folder))) ["test","test_dev"]
          | "nofib" => List.app (fn category =>
              List.app (fn p => if not (upstream root p) orelse OS.Path.dir p=root ^ "/" ^ category then () else
                let val directory=OS.Path.dir p val entries=List.filter (fn q => regular q andalso hasExt [".hs",".lhs"] q andalso isMain (haskellCode q)) (immediate directory)
                in if length entries>1 then List.app (fn entry => add (rel entry) (OS.Path.base (OS.Path.file entry)) (rel p)) entries
                   else add (rel directory) (OS.Path.file directory) (rel p) end)
              (List.filter (fn p => OS.Path.file p="Makefile" andalso regular p) (if isDir (root ^ "/" ^ category) then allFiles (root ^ "/" ^ category) else []))) ["imaginary","spectral","real","gc","shootout","parallel","smp"]
          | "sandmark" =>
             (List.app (fn p => if not (upstream root p andalso regular p) orelse not (OS.Path.file p="dune" orelse String.isSuffix "-dune.inc" p) then () else
                List.app (fn form => case form of Atom kind::entries =>
                    if kind="executable" orelse kind="executables" then List.app (fn Form (Atom field::names) => if field="name" orelse field="names" then
                           List.app (fn Atom name => add (rel (OS.Path.dir p ^ "/" ^ name ^ ".exe")) name (rel p) | _ => ()) names else () | _ => ()) entries else () | _ => ()) (walkForms (sexps (readText p))))
                (if isDir (root ^ "/benchmarks") then allFiles (root ^ "/benchmarks") else []);
              List.app (fn p => case readJson p of data as Json.Object _ =>
                  (case Json.member ("benchmarks",data) of NONE => () | SOME benches =>
                     List.app (fn bench => let val executable=T.substitute "\\.(bc|exe)$" (fn _ => ".exe") (text (field "executable" bench))
                           val name=T.substitute "\\.bc$" (fn _ => "") (text (field "name" bench))
                           val ()=add executable name (OS.Path.file p)
                       in if OS.Path.file p="run_config.json" then #name (valOf (List.find (fn (item:item) => #path item=executable) (!found))) := name else () end) (array benches)) | _ => ()) (glob (root,".json")))
          | _ => raise Failed ("unknown source " ^ source)
    in !found end
  fun baseName name=T.substitute "_(smlnj|mlton|tp|no_basislib)$" (fn _ => "") name
  fun family name body =
    let val key=String.map Char.toLower name
        fun includes names=List.exists (fn s => String.isSubstring s key) (String.tokens Char.isSpace names)
    in if List.exists (fn n => n=key) ["happy","hpg","lift","parstof","transform"] then "compiler-application"
       else if includes "fft nbody n-body barnes mandel nucleic ray simple fem fluid almabench matrix grammatrix decomposition durand levinson minilight sphere zern arith" then "numerical"
       else if includes "sort merge list rev sieve primes hamming wheel" then "lists-streams"
       else if includes "lex yacc parser infer hamlet typecheck prolog veritas anna vliw" then "compiler-application"
       else if includes "boyer bdd zdd logic knuth kb rewrite claus crypt sat queens tsp minimax" then "symbolic-search"
       else if includes "fib tak ack motzkin sudan evenodd" then "calls-recursion"
       else if includes "gc alloc tree dangle reynolds space mutstore weak final roots stress" then "allocation-lifetimes"
       else if includes "integer pidigits bernou digits rsa smith zarith paraffin" orelse T.matches "(^|[^A-Za-z0-9_])(IntInf|Integer)([^A-Za-z0-9_]|$)" body then "integer-arithmetic"
       else if length (Utf8.explode body)>16000 then "application" else "kernel" end
  fun related rows =
    let val aliases=[("nucleic","pseudoknot"),("nucleic2","pseudoknot"),("DLXSimulator","dlx"),("smith-nf","smith-normal-form"),("kb","knuth-bendix"),("rec_seq_fib","fib"),("rec_seq_tak","tak"),("rec_seq_evenodd","even-odd")]
        fun base row=let val name=baseName (get "name" row) in case List.find (fn (key,_) => key=name) aliases of SOME (_,v) => v | NONE => name end
        fun one (row,i)=let val peers=List.mapPartial (fn (other,j) => if i<>j andalso base other=base row then SOME (get "source" other ^ ":" ^ get "path" other) else NONE) (ListPair.zip (rows,List.tabulate (length rows,fn i => i)))
                        in set "related" (String.concatWith ";" (sort peers)) row end
    in ListPair.map one (rows,List.tabulate (length rows,fn i => i)) end
  fun names rows =
    let val sources=["mlton","smlnj","mlkit","nofib","sandmark"]
        fun rank row=let fun loop [] _=raise Failed "unknown inventory source" | loop (s::ss) i=if get "source" row=s then i else loop ss (i+1) in loop sources 0 end
        val indexed=ListPair.zip (rows,List.tabulate (length rows,fn i => i))
        val ordered=sorted (fn ((a,_),(b,_)) => rank a<rank b orelse (rank a=rank b andalso get "path" a<get "path" b)) indexed
        val result=Array.fromList rows val used=ref [] : string list ref
        fun one (row,i)=if get "disposition" row<>"import" then () else
          let val name=get "name" row val source=get "source" row val path=get "path" row fun exists n=List.exists (fn old => old=n) (!used)
              val name=if exists name then name ^ "-" ^ source else name
              val parts=fields #"/" path
              val qualifier=String.concatWith "-" (if source="sandmark" then List.take (List.drop (parts,1),Int.max (0,length parts-2)) else List.take (parts,Int.max (0,length parts-1)))
              val name=if exists name then name ^ "-" ^ qualifier else name
          in need (not (exists name),"cannot disambiguate " ^ path);used:=name:: !used;Array.update (result,i,set "rune_name" name row) end
    in List.app one ordered;Array.foldr (op ::) [] result end
end
