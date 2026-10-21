(* Profiling summaries: weighted perf samples and elaborator counters.
   External instruments supply observations; grouping and reports are SML. *)
structure MeasureProfile =
struct
  open MeasureCommon
  fun pad width text=StringCvt.padLeft #" " width text
  fun left width text=StringCvt.padRight #" " width text
  fun lookup key rows=getOpt (Option.map #2 (List.find (fn (name,_) => key=name) rows),0.0)
  fun plus rows key value=rows:=(key,lookup key (!rows)+value) :: List.filter (fn (name,_) => name<>key) (!rows)
  fun numeric text=getOpt (Real.fromString text,0.0)
  fun weight key (rows:(string*IntInf.int) list)=getOpt (Option.map #2 (List.find (fn (name,_) => key=name) rows),0)
  fun addWeight rows key value=rows:=(key,weight key (!rows)+value) :: List.filter (fn (name,_) => name<>key) (!rows)
  fun count text=getOpt (IntInf.fromString text,0)
  fun number value=Int.toString (Real.trunc value)
  fun input files=if null files then TextIO.inputAll TextIO.stdIn else String.concat (List.map read files)
  fun options default args =
    let fun loop top files []=(top,List.rev files)
          | loop _ files ("--top"::value::rest)=loop (integer value) files rest
          | loop _ files ("-v"::value::rest)=if String.isPrefix "top=" value then loop (integer (String.extract (value,4,NONE))) files rest else raise Usage "only -v top=N is supported"
          | loop top files (arg::rest)=loop top (arg::files) rest
    in loop default [] args end
  fun elab args =
    let val (top,files)=options 10 args
        val text=input files
        val declarations=ref 0
        val total=ref 0.0
        val cells=ref [] : (string*real) list ref
        val contexts=ref [] : (string*real) list ref
        val operations=ref [] : (string*real) list ref
        val counts=ref [] : (string*IntInf.int) list ref
        val worst=ref [] : (real*string) list ref
        fun line line =
          let val words=String.tokens Char.isSpace line
          in if length words<5 orelse hd words<>"elab" then () else
             (declarations:= !declarations+1;
              List.app (fn field =>
                 let val (key,rest)=Substring.position "=" (Substring.full field)
                 in if Substring.isEmpty rest then () else
                    let val key=Substring.string key
                        val value=numeric (Substring.string (Substring.triml 1 rest))
                    in if key="total" then (total:= !total+value;worst:=(value,String.concatWith " " (List.take (List.drop (words,1),3))) :: !worst)
                       else if String.isSubstring "." key andalso not (List.exists (fn prefix => String.isPrefix prefix key) ["inst.","share.","match.","app."]) then
                         let val parts=fields #"." key in plus cells key value;plus contexts (hd parts) value;plus operations (List.nth (parts,1)) value end
                       else if key="app.depth" then counts:=(key,IntInf.max (count (Substring.string (Substring.triml 1 rest)),weight key (!counts))) :: List.filter (fn (name,_) => name<>key) (!counts)
                       else addWeight counts key (count (Substring.string (Substring.triml 1 rest)))
                    end end) (List.drop (words,4))) end
        val ()=List.app line (lines text)
        val cs=["top","fundecl","appcode","appcheck"]
        val ops=["core","inst","where","share","match","specs","copy"]
        fun seconds value=fixed 3 (value/1000000.0)
        fun percent value=if !total>0.0 then fixed 1 (100.0*value/ !total) ^ "%" else "-"
        val ()=say (Int.toString (!declarations) ^ " declarations, " ^ seconds (!total) ^ " s of elaboration\n\n")
        val ()=say (left 10 "s" ^ String.concat (List.map (fn name => " " ^ pad 9 name) ops) ^ " " ^ pad 9 "all" ^ " " ^ pad 7 "%" ^ "\n")
        val ()=List.app (fn context => say (left 10 context ^ String.concat (List.map (fn operation => " " ^ pad 9 (seconds (lookup (context ^ "." ^ operation) (!cells)))) ops)
                     ^ " " ^ pad 9 (seconds (lookup context (!contexts))) ^ " " ^ pad 7 (percent (lookup context (!contexts))) ^ "\n")) cs
        val ()=say (left 10 "all" ^ String.concat (List.map (fn name => " " ^ pad 9 (seconds (lookup name (!operations)))) ops) ^ " " ^ pad 9 (seconds (!total)) ^ "\n"
                  ^ left 10 "%" ^ String.concat (List.map (fn name => " " ^ pad 9 (percent (lookup name (!operations)))) ops) ^ "\n\ncounters:")
        val keys=String.tokens Char.isSpace "realize nodes inst inst.names where share.types share.structures match match.paths fundecl app.code app.check app.depth unify steps"
        val ()=List.app (fn key => say (" " ^ key ^ "=" ^ IntInf.toString (weight key (!counts)))) keys
        fun insert (row as (value,_):real*string) []=[row]
          | insert (row as (value,_)) ((first as (other,_))::rest)=if value>other then row::first::rest else first::insert row rest
        val sorted=List.foldl (fn (row,rows) => insert row rows) [] (List.rev (!worst))
        val ()=say ("\n\nthe " ^ Int.toString top ^ " declarations that took longest:\n")
        val ()=List.app (fn (value,description) => say (pad 10 (seconds value) ^ " s  " ^ description ^ "\n"))
                  (List.take (sorted,Int.min (Int.max (0,top),length sorted)))
    in 0 end
  val order=fields #"|" "tier 2 code|tier 1 code|JIT code, other tiers|native code|interpreter|JIT stubs and calls|frames: walks, liveness, the barrier|collector: minor|collector: major|allocation|boxes (64-bit numbers, reals)|equality (runtime)|string order (runtime)|exceptions (runtime)|IntInf primitives|primitives|JIT compiler|image and loader|libc: malloc and printf|memmove/memcpy (other callers)|kernel|other"
  val rules=List.map (fn (pattern,name) => (TerminalPattern.compile false pattern,name)) MeasureGroupRules.rules
  fun matches pattern text=isSome (TerminalPattern.find pattern text 0)
  fun classify symbol=case List.find (fn (pattern,_) => matches pattern symbol) rules of SOME (_,name) => name | NONE => "other"
  val native=TerminalPattern.compile false "#[0-9]+$"
  val jit=TerminalPattern.compile false "^jit[0-9]+:"
  val copying=TerminalPattern.compile false "^_*mem(cpy|move|set|cmp)|^__mem|^_*memchr|^_*(str|wcs)(len|cmp|chr|nlen)"
  val ours=TerminalPattern.compile false "rune|runevm|native|perf-[0-9]+\\.map"
  fun group (symbol,dso,caller)=
    if String.isSubstring "kernel" dso then "kernel" else if String.isPrefix "jit2:" symbol then "tier 2 code"
    else if String.isPrefix "jit1:" symbol then "tier 1 code" else if matches jit symbol then "JIT code, other tiers"
    else if matches native symbol then "native code" else if matches copying symbol then
         let val name=classify caller
         in if List.exists (fn name' => name=name') ["other","interpreter","JIT stubs and calls","JIT compiler"] then "memmove/memcpy (other callers)" else name end
    else classify symbol
  fun perf args =
    let val (top,files)=options 0 args
        val period=ref (0:IntInf.int) val leaf=ref "" val dso=ref "" val caller=ref "" val depth=ref 0
        val total=ref (0:IntInf.int)
        val groups=ref [] : (string*IntInf.int) list ref
        val symbols=ref [] : (string*IntInf.int) list ref
        val seen=ref [] : string list ref
        fun flush ()=
          (if !period<=0 then () else
             let val name=group (!leaf,!dso,!caller)
                 val key= !leaf ^ (if matches ours (!dso) then "" else " " ^ !dso)
             in addWeight groups name (!period);addWeight symbols key (!period);total:= !total+ !period;
                if List.exists (fn old => old=key) (!seen) then () else seen:= !seen @ [key] end;
           period:=0;leaf:="";dso:="";caller:="";depth:=0)
        fun line text =
          let val words=String.tokens Char.isSpace text
              fun word n=if n<length words then List.nth (words,n) else ""
          in if not (String.isPrefix "\t" text) then
                (flush ();period:=count (word 0);if length words>=3 then (leaf:=word 2;dso:=word 3) else ())
             else (depth:= !depth+1;if !depth=1 then (leaf:=word 1;dso:=word 2) else if !depth=2 then caller:=word 1 else ()) end
        val ()=List.app line (String.fields (fn c => c = #"\n") (input files))
        val ()=flush ()
        fun percentage value=fixed 2 (100.0*Real.fromLargeInt (IntInf.toLarge value)/Real.fromLargeInt (IntInf.toLarge (!total)))
        fun insert key []=[key] | insert key (first::rest)=if weight key (!symbols)>weight first (!symbols) then key::first::rest else first::insert key rest
        val sorted=List.foldl (fn (key,keys) => insert key keys) [] (!seen)
    in if !total=0 then say "total 0\n" else
        (say ("total " ^ IntInf.toString (!total) ^ "\n");
         List.app (fn name => say ("group\t" ^ name ^ "\t" ^ percentage (weight name (!groups)) ^ "\n")) order;
         if top<=0 then () else List.app (fn key => say ("sym\t" ^ key ^ "\t" ^ percentage (weight key (!symbols)) ^ "\n")) (List.take (sorted,Int.min (top,length sorted))));0 end
end
