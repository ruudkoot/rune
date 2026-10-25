(* Scenarios needing relocation, concurrent producers, copied libraries or
   persistent REPL sessions. All process startup stays bounded and supervised. *)
structure IncrementalExtra =
struct
  open Incremental
  fun relocated s suffix =
    let val old = !(#directory s)
        val new = old ^ suffix
    in rmTree new; OS.FileSys.rename {old = old, new = new}; #directory s := new end
  fun environment (s : state) key value = #environment s := (key, value) :: !(#environment s)
  fun permissions path writable =
    let val mode = Posix.FileSys.ST.mode (Posix.FileSys.stat path)
        val writeBits = Posix.FileSys.S.flags [Posix.FileSys.S.iwusr, Posix.FileSys.S.iwgrp, Posix.FileSys.S.iwoth]
        val mode = if writable then Posix.FileSys.S.flags [mode, Posix.FileSys.S.iwusr]
                   else Posix.FileSys.S.fromWord (SysWord.andb (Posix.FileSys.S.toWord mode, SysWord.notb (Posix.FileSys.S.toWord writeBits)))
    in Posix.FileSys.chmod (path, mode);
       if isDir path then List.app (fn name => permissions (path ^ "/" ^ name) writable) (entries path) else () end
  fun inodes s = List.map (fn file => (file, Posix.FileSys.inoToWord (Posix.FileSys.ST.ino (Posix.FileSys.stat file)))) (cache s)
  fun notIn previous now = List.filter (fn file => not (List.exists (fn old => old = file) previous)) now
  fun concurrent (s : state) =
    let val mode = Posix.FileSys.S.flags [Posix.FileSys.S.irusr, Posix.FileSys.S.iwusr]
        val input = Posix.FileSys.openf ("/dev/null", Posix.FileSys.O_RDONLY, Posix.FileSys.O.flags [])
        val out = Posix.FileSys.creat (path s "one.out", mode)
        val err = Posix.FileSys.creat (path s "one.err", mode)
        fun fd x = SysWord.toInt (Posix.FileSys.fdToWord x)
        val pid = Subprocess.spawn {program = #compiler s,
             args = #compiler s :: ["--units", "--cache-dir", "cache"] @ words (path s "files") @ ["-o", "one.rbc"],
             env = SOME (unsetEnv ["FORCE_COLOR", "CLICOLOR_FORCE"] (Posix.ProcEnv.environ ())),
             search = false, dir = SOME (!(#directory s)), stdin = SOME (fd input), stdout = SOME (fd out), stderr = SOME (fd err),
             group = false, limits = {addressSpace = NONE, cpuTime = SOME 600, fileSize = SOME (1024*1024*1024), core = SOME 0}}
        val () = (Posix.IO.close input; Posix.IO.close out; Posix.IO.close err)
        val second = compile s ["--units", "--cache-dir", "cache"] "two.rbc"
        val start = Runtime.clock ()
        fun wait () = case Subprocess.poll (SOME pid) of SOME {status, ...} => status = Posix.Process.W_EXITED
          | NONE => if Time.toSeconds (Time.- (Runtime.clock (), start)) >= 600 then
               ((Posix.Process.kill (Posix.Process.K_PROC (Posix.Process.wordToPid (SysWord.fromInt pid)), Posix.Signal.kill)
                 handle OS.SysErr _ => ()); ignore (Subprocess.wait (SOME pid)); false)
             else (OS.Process.sleep (Time.fromMilliseconds 20); wait ())
        val first = wait ()
        val plain = compile s ["--units", "--no-cache"] "nocache.rbc"
    in check s "concurrent builds differ from a fresh build"
           (first andalso #status second = 0 andalso #status plain = 0
            andalso same (path s "one.rbc", path s "nocache.rbc") andalso same (path s "two.rbc", path s "nocache.rbc"));
       checkBuild s [] "" end
  fun parallel (s : state) =
    let val single = create "S58-one" (#compiler s)
        val () = (fresh s; fresh single; environment s "RUNE_PARALLEL_MIN" "0"; environment single "RUNE_PARALLEL_MIN" "0")
        fun compare description =
          let val () = (build single []; build s ["-j", "4"])
              val a = !(#result single)
              val b = !(#result s)
          in check s ("parallel build differs: " ^ description)
                (#status a = #status b andalso compiled single = compiled s andalso #errors a = #errors b
                  andalso (#status a <> 0 orelse same (path s "p.rbc", path single "p.rbc"))) end
        fun both file old new = List.app (fn state => edit state file old new) [s, single]
    in compare "cold"; compare "warm"; both "b.sml" "+ 1" "+ 2"; compare "body edit";
       both "a.sml" "val unused = 0" "val unused = 1  val more = 2"; compare "declaration edit";
       both "c.sml" "2 * S.area x" "2 * S.area"; compare "compile error";
       both "c.sml" "2 * S.area\n" "2 * S.area x\n"; compare "mended" end
  fun one (s : state) =
    let fun b flags expected = checkBuild s flags expected
        fun f file version = fixture s file version
    in case #name s of
      "S7" =>
        (standard s; let val old = !(#directory s)
                        val other = old ^ "-other"
                        val () = (rmTree other; mkdirs other)
                        val () = List.app (fn file => copy (path s file) (other ^ "/" ^ file))
                                          (String.tokens Char.isSpace all @ ["files"])
                        val () = #directory s := other
                        val result = compile s ["--units", "--cache-dir", old ^ "/cache", "--explain-rebuild"] "p.rbc"
                    in #result s := result; #flags s := []; want s "" end)
    | "S22" => (standard s; let val original = !(#directory s)
                               val link = original ^ "-link"
                           in rmTree link; Posix.FileSys.symlink {old = original, new = link}; #directory s := link;
                              b [] ""; #directory s := original end)
    | "S29" => (standard s; relocated s "-moved"; b [] "")
    | "S28" =>
        (fresh s; basis s; b ["--lib", path s "lib"] all;
         edit s "lib/basis/list.sml" "  datatype list = datatype list" "  val runeScenarioS28 = 0\n  datatype list = datatype list";
         b ["--lib", path s "lib"] ""; append (path s "lib/basis/pervasive.sml", "\nval runeScenarioS28 = 0\n"); b ["--lib", path s "lib"] "";
         #directory s := !(#directory s) ^ "o"; own s "x.sml w.sml"; basis s;
         put s "x.sml" "val n = WideString.size";
         put s "w.sml" "val v : WideCharVector.vector = \"ab\"\nval () = print (Int.toString (WideCharVector.length v) ^ \"\\n\")";
         b ["--lib", path s "lib"] "x.sml w.sml";
         edit s "lib/basis/widestring.sml" "  fun fromLit s = " "  val runeScenarioS28 = 0\n  fun fromLit s = ";
         b ["--lib", path s "lib"] "w.sml")
    | "S33" =>
        (standard s; List.app (fn file => let val bytes = CachePlant.binary file
                                       in CachePlant.writeBinary file (String.substring (bytes, 0, Int.min (40, size bytes))) end) (cache s);
         b [] all; let val file = hd (cache s)
                       val bytes = CachePlant.binary file
                       val () = need (size bytes > 60, "cache entry too short for byte corruption")
                   in CachePlant.writeBinary file (String.substring (bytes, 0, 60)
                       ^ str (Char.chr ((Char.ord (String.sub (bytes, 60)) + 1) mod 256)) ^ String.extract (bytes, 61, NONE)) end;
         build s []; check s "corrupted entry was reused" (not (null (Scenarios.rebuilt (#errors (!(#result s)))))); b [] "")
    | "S34" => (fresh s; concurrent s)
    | "S35" => (standard s; List.app (fn file => write (file ^ ".tmp-1-1", "half an entry"))
                    (List.mapPartial (fn config => case sort (entries config) of name :: _ => SOME (config ^ "/" ^ name) | _ => NONE)
                       (List.concat (List.map (fn shard => List.map (fn name => shard ^ "/" ^ name) (entries shard))
                                     (List.map (fn name => path s ("cache/" ^ name)) (entries (path s "cache")))))); b [] "")
    | "S36" =>
        (standard s; edit s "a.sml" "fun area (Square n) = n * n" "fun area (Square n) = n * n * 1";
         permissions (path s "cache") false;
         ((if OS.FileSys.access (path s "cache", [OS.FileSys.A_WRITE]) then say "SKIP cache permissions: process can write read-only directory\n"
           else (b [] "a.sml"; permissions (path s "cache") true; b [] "a.sml"))
          before permissions (path s "cache") true)
         handle e => (permissions (path s "cache") true; raise e))
    | "S40" =>
        (own s ""; put s "uses.sml" "val twice = (base, base)";
         let val _ = session s false ["val base = \"ab\";", "use \"uses.sml\";"]
             val one = length (cache s)
             val _ = session s false ["val base = 3;", "use \"uses.sml\";"]
             val two = length (cache s)
             val saved = inodes s
             val output = session s false ["val base = \"cd\";", "use \"uses.sml\";"]
         in check s "session cache was not reused with a new binding of the same type"
                 (one = 1 andalso two = 2 andalso inodes s = saved andalso String.isSubstring "twice = (\"cd\", \"cd\")" output) end)
    | "S53" =>
        (custom s "t.sml v.sml"; ignore (session s false ["use \"t.sml\";", "use \"v.sml\";"]);
         check s "cached value used the previous printer"
           (String.isSubstring "val v = <t 3> : t" (session s false ["use \"t.sml\";",
             "Compiler.addPrettyPrinter (fn _ => fn _ => fn (T n) => Compiler.PrettyString (\"<t \" ^ Int.toString n ^ \">\"));", "use \"v.sml\";"])))
    | "S54" =>
        (custom s "t.sml v.sml"; ignore (session s false ["RuneCompiler.printDepth := 0;", "use \"t.sml\";", "use \"v.sml\";"]);
         check s "cached entry did not echo at default depth" (String.isSubstring "val v = T 3 : t" (session s false ["use \"t.sml\";", "use \"v.sml\";"])))
    | "S55" =>
        (functorFixity s; b [] "y.sml a.sml c.sml main.sml";
         let val old = selectedEntry s "main.sml"
             val () = copy (only old) (path s "old-entry")
             val () = (f "a.sml" 1; b [] "a.sml c.sml main.sml"; build s ["--verify-cache"])
             val () = check s "warm build did not verify" (#status (!(#result s)) = 0)
             val new = only (notIn old (selectedEntry s "main.sml"))
             val () = CachePlant.stale (path s "old-entry") new
             val () = build s []
             val () = check s "planted stale entry was not used" (null (compiled s))
             val () = prints s "4"
             val () = build s ["--verify-cache"]
         in check s "verification did not reject the planted stale entry" (#status (!(#result s)) <> 0
                andalso String.isSubstring "main.sml: the cache's entry is not what compiling it gives" (#errors (!(#result s)))) end)
    | "S57" =>
        (own s ""; f "u.sml" 0; ignore (session s false ["val base = 1;", "use \"u.sml\";"]);
         let val old = cache s
             val () = f "u.sml" 1
             val _ = session s false ["val base = 1;", "use \"u.sml\";"]
             val new = only (notIn old (cache s))
             val () = CachePlant.stale (hd old) new
             val () = check s "REPL did not use planted entry"
                         (String.isSubstring "val twice = 2 : int" (session s false ["val base = 1;", "use \"u.sml\";"]))
             val output = session s true ["val base = 1;", "use \"u.sml\";"]
         in check s "REPL verification did not reject planted entry"
               (String.isSubstring "the cache's entry for " output andalso String.isSubstring " is not what compiling it gives" output) end)
    | "S74" =>
        (own s ""; put s "counter.sml" "structure Counter = struct val n = ref 0 end";
         let val _ = session s false ["use \"counter.sml\";"]
             val output = session s true ["use \"counter.sml\";", "structure Old = Counter;", "use \"counter.sml\";",
                                          "Old.n := 10;", "val now = !Counter.n;", "val old = !Old.n;"]
         in check s ("a structure named a file's used again: " ^ output)
              (String.isSubstring "val now = 0 : int" output andalso String.isSubstring "val old = 10 : int" output
               andalso not (String.isSubstring "not what compiling it gives" output)) end)
    | "S75" =>
        (own s ""; put s "user.sml" "fun bump () = Counter.n := !Counter.n + 1";
         put s "apply.sml" "structure A = Twice (struct fun step n = n * 3 end)  val a = A.go 5";
         let
           val write = "fun write (f, t) = let val out = TextIO.openOut f in TextIO.output (out, t); TextIO.closeOut out end;"
           fun counter more = "write (\"counter.sml\", \"structure Counter = struct val n = ref 0" ^ more ^ " end\");"
           fun twice body = "write (\"twice.sml\", \"functor Twice (X : sig val step : int -> int end) = struct fun go x = "
                            ^ body ^ " end\");"
           val output = session s false
             [write, counter "", "use \"counter.sml\";", "use \"user.sml\";", "use \"counter.sml\";", "use \"user.sml\";",
              "bump ();", "val same = !Counter.n;",
              counter " val m = 1", "use \"counter.sml\";", "use \"user.sml\";", "bump ();", "val edited = !Counter.n;",
              twice "X.step (X.step x)", "use \"twice.sml\";", "use \"apply.sml\";",
              twice "X.step (X.step (X.step x))", "use \"twice.sml\";", "use \"apply.sml\";"]
         in check s ("a cached unit linked against a unit the session replaced: " ^ output)
              (String.isSubstring "val same = 1 : int" output andalso String.isSubstring "val edited = 1 : int" output
               andalso String.isSubstring "val a = 135 : int" output) end)
    | "S58" => parallel s
    | _ => simple s
    end
  val cases = ["S1", "S2", "S3", "S5", "S6", "S8", "S17", "S18", "S19", "S29", "S13", "S24", "S31", "S33", "S34", "S36", "S28", "S40",
               "S4", "S7", "S9", "S10", "S11", "S12", "S14", "S15", "S16", "S20", "S21", "S22", "S23", "S25", "S26", "S30", "S32", "S35",
               "S57", "S56", "S49", "S50", "S51", "S52", "S53", "S54", "S55", "S58", "S59", "S60", "S61", "S62", "S63", "S64", "S65", "S66", "S67", "S68", "S69", "S70", "S71", "S72", "S73", "S74", "S75"]
  fun runCase name compiler =
    let val s = create name compiler
    in one s; say ("PASS incremental." ^ name ^ ": " ^ Int.toString (!(#assertions s)) ^ " assertions\n") end
end
