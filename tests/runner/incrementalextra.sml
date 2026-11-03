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
  (* what a build compiled of its own, by the paths it gave them: not the
     libraries' files, which a project's first build through its own cache
     may compile *)
  fun ownCompiled (s : state) =
    List.filter (not o String.isSubstring "/../lib/") (Scenarios.rebuilt (#errors (!(#result s))))
  fun wantOwn (s : state) expected =
    check s ("compiled [" ^ String.concatWith " " (ownCompiled s) ^ "], wanted [" ^ expected ^ "]")
            (#status (!(#result s)) = 0 andalso ownCompiled s = String.tokens Char.isSpace expected)
  (* a build file through the cache, and without it: S41 *)
  fun buildFile (s : state) file expected =
    let val () = #result s := command s "" [#compiler s, "--build", file, "--units", "--cache-dir", "cache", "--explain-rebuild",
                                            "-o", "p.rbc"]
        val () = wantOwn s expected
        val plain = command s "" [#compiler s, "--build", file, "--units", "--no-cache", "-o", "nocache.rbc"]
    in check s "cached program differs from uncached compilation"
             (#status plain = 0 andalso same (path s "p.rbc", path s "nocache.rbc")) end
  (* a root file that is refused, and how *)
  fun refused (s : state) (text, says) =
    let val () = put s "rune.workspace" text
        val r = command s "" [#compiler s, "--build", "p.build", "--units", "--no-cache", "-o", "p.rbc"]
    in check s ("a workspace was not refused: " ^ text)
             (#status r <> 0 andalso String.isSubstring "rune.workspace" (#errors r) andalso String.isSubstring says (#errors r)) end
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
         let (* c.sml's own entry: main.sml's names c.sml's unit too *)
             fun entries () = List.filter (fn file => not (String.isSubstring "main.sml" (CachePlant.binary file)))
                                          (selectedEntry s "c.sml")
             val old = entries ()
             val () = copy (only old) (path s "old-entry")
             val () = (f "a.sml" 1; b [] "a.sml c.sml"; build s ["--verify-cache"])
             val () = check s "warm build did not verify" (#status (!(#result s)) = 0)
             val new = only (notIn old (entries ()))
             val () = CachePlant.stale (path s "old-entry") new
             val () = build s []
             val () = check s "planted stale entry was not used" (null (compiled s))
             val () = prints s "4"
             val () = build s ["--verify-cache"]
         in check s "verification did not reject the planted stale entry" (#status (!(#result s)) <> 0
                andalso String.isSubstring "c.sml: the cache's entry is not what compiling it gives" (#errors (!(#result s)))) end)
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
    | "S76" =>
        (own s ""; put s "v.sml" "val v = 1 + 2  fun get (SOME x) = x | get NONE = v";
         let val _ = session s false ["val a = 1;", "val b = 2;", "use \"v.sml\";"]
             val output = session s true ["use \"v.sml\";", "val w = get NONE;"]
         in check s ("a file used at another place in a session, the cache verified: " ^ output)
              (String.isSubstring "val v = 3 : int" output andalso String.isSubstring "val w = 3 : int" output
               andalso not (String.isSubstring "not what compiling it gives" output)) end)
    | "S78" =>
        (* a function marked to be inlined (`inline val`): an edit of its
           body compiles the declaring unit and the units that copied it,
           and nothing else; an edit beside it, the declaring unit alone *)
        let
          val () = own s ""
          val () = put s "a.sml" "structure A = struct fun inc x = x + 1 fun other x = x * 2 end"
          val () = put s "b.sml" "val b = A.inc 41"
          val () = put s "c.sml" "val c = A.other 3"
          val () = put s "main.sml" "val () = print (Int.toString b ^ \" \" ^ Int.toString c ^ \"\\n\")"
          val () = put s "p.build" "inline val A.inc end\nfiles a.sml b.sml c.sml main.sml end"
          fun bld expected output =
            let
              val r = command s "" [#compiler s, "--build", "p.build", "--units", "--cache-dir", "cache", "--explain-rebuild",
                                    "-o", "p.rbc"]
              val () = #result s := r
              val got = compiled s
              val () = check s ("compiled [" ^ String.concatWith " " got ^ "], wanted [" ^ expected ^ "]")
                             (#status r = 0 andalso got = String.tokens Char.isSpace expected)
              val plain = command s "" [#compiler s, "--build", "p.build", "--units", "--no-cache", "-o", "nocache.rbc"]
              val () = check s "cached program differs from uncached compilation"
                             (#status plain = 0 andalso same (path s "p.rbc", path s "nocache.rbc"))
            in prints s output end
        in
          bld "a.sml b.sml c.sml main.sml" "42 6";
          edit s "a.sml" "fun inc x = x + 1" "fun inc x = x + 2";
          bld "a.sml b.sml" "43 6";
          edit s "a.sml" "fun other x = x * 2" "fun other x = x * 2 + 0";
          bld "a.sml" "43 6"
        end
    | "S83" =>
        (* an edit that keeps every offset and moves a line (a space made a
           newline): a unit that copied the marked function has its line in
           its line table, from the source of the unit that declares it *)
        let
          val () = own s ""
          fun declaring gap = put s "a.sml" ("structure A = struct val pad = 0" ^ gap
                                             ^ "fun inc (x : int) = if x > 2 then raise Fail \"boom\" else x + 1 end")
          val () = declaring " "
          val () = put s "b.sml" "val () = print (Int.toString (A.inc 5) ^ \"\\n\")"
          val () = put s "p.build" "inline val A.inc end\nfiles a.sml b.sml end"
          fun bld expected =
            let
              val r = command s "" [#compiler s, "--build", "p.build", "--units", "--cache-dir", "cache", "--explain-rebuild",
                                    "-o", "p.rbc"]
              val () = #result s := r
              val got = compiled s
              val () = check s ("compiled [" ^ String.concatWith " " got ^ "], wanted [" ^ expected ^ "]")
                             (#status r = 0 andalso got = String.tokens Char.isSpace expected)
              val plain = command s "" [#compiler s, "--build", "p.build", "--units", "--no-cache", "-o", "nocache.rbc"]
            in check s "cached program differs from uncached compilation"
                     (#status plain = 0 andalso same (path s "p.rbc", path s "nocache.rbc")) end
        in
          bld "a.sml b.sml";
          declaring "\n";
          bld "a.sml b.sml"
        end
    | "S91" =>
        (* a file given twice is two units, as compiled whole: each has its
           own globals (build-cache issue 22, in batch; E16) *)
        let
          val () = own s "a.sml keep.sml a.sml main.sml"
          val () = put s "a.sml" "structure A = struct val n = ref 0 end"
          val () = put s "keep.sml" "structure Old = A"
          val () = put s "main.sml" "val () = Old.n := 10\nval () = print (Int.toString (!A.n) ^ \" \" ^ Int.toString (!Old.n) ^ \"\\n\")"
          val () = b [] "a.sml keep.sml a.sml main.sml"
          val () = prints s "0 10"
          val () = b [] ""
          val () = prints s "0 10"
          val whole = compile s [] "whole.rbc"
          val () = check s "the whole program does not compile" (#status whole = 0)
          val direct = command s "" [OS.Path.dir (#compiler s) ^ "/runevm", "whole.rbc"]
          val () = check s "the whole program prints otherwise" (#output direct = "0 10\n")
          val units = compile s ["--units", "--whole", "--cache-dir", "cache"] "units.rbc"
          val () = check s "--units --whole is not the whole program" (#status units = 0 andalso same (path s "units.rbc", path s "whole.rbc"))
          val () = environment s "RUNE_PARALLEL_MIN" "1"
          val parallel = compile s ["--units", "-j", "3", "--cache-dir", "parallel"] "parallel.rbc"
          val () = check s "-j changes a file given twice" (#status parallel = 0 andalso same (path s "parallel.rbc", path s "p.rbc"))
          val () = #environment s := []
          (* a build's are named from its root, and these from the first
             file: the same here, where the two are one directory *)
          val () = put s "rune.workspace" ""
          val () = put s "p.build" "a.sml keep.sml a.sml main.sml"
        in buildFile s "p.build" ""; prints s "0 10" end
    | "S92" =>
        (* however a path spells a file, it is one unit: nothing is compiled
           again, and a dynamic module's client is the same bytes (E10) *)
        let
          val () = fresh s
          val () = b [] all
          val () = mkdirs (path s "sub")
          val () = put s "files" "./a.sml b.sml sub/../c.sml .//d.sml main.sml"
          val () = build s []
          val () = wantOwn s ""
          val () = check s "a spelling names the file in the program" (String.isSubstring "./a.sml" (CachePlant.binary (path s "p.rbc")))
          val plain = compile s ["--units", "--no-cache"] "nocache.rbc"
          val () = check s "cached program differs from uncached compilation" (#status plain = 0 andalso same (path s "p.rbc", path s "nocache.rbc"))
          val () = put s "files" (String.concatWith " " (List.map (path s) (String.tokens Char.isSpace all)))
          val () = build s []
          val () = wantOwn s ""
          val () = put s "sg.sml" "signature SHAPE = sig val v : Ty.t val area : int -> int end"
          val () = put s "ty.sml" "structure Ty = struct datatype t = A | B end"
          val () = put s "client.sml" "structure S = _dynamic \"impl.rbu\" : SHAPE\nval () = print (Int.toString (S.area 3) ^ \"\\n\")"
          fun emitted (dir, ty) =
            let val r = command s "" [#compiler s, "--units", "--no-cache", "--emit-units", dir, ty, "sg.sml", "client.sml", "-o", dir ^ ".rbc"]
                val () = check s ("a dynamic client does not compile: " ^ #errors r) (#status r = 0)
            in valOf (List.find (String.isSubstring "client") (entriesBelow (path s dir))) end
          val plainClient = emitted ("plain", "ty.sml")
          val spelt = emitted ("spelt", "./ty.sml")
        in check s "a spelling reaches a dynamic client" (same (plainClient, spelt)) end
    | "S93" =>
        (* a library keeps its name where it moves: nothing is compiled, and
           what the program and the warnings name is where it is now *)
        let
          val () = own s ""
          val () = put s "rune.workspace" ""
          val () = put s "old/foo/library.build" "files a.sml end"
          val () = put s "old/foo/a.sml" "fun f 0 = 1"
          val () = put s "main.sml" "val () = print (Int.toString (f 0) ^ \"\\n\")"
          val () = put s "p.build" "old/foo/a.sml main.sml"
          val () = buildFile s "p.build" "old/foo/a.sml main.sml"
          val () = mkdirs (path s "new")
          val () = OS.FileSys.rename {old = path s "old/foo", new = path s "new/foo"}
          val () = put s "p.build" "new/foo/a.sml main.sml"
          val () = buildFile s "p.build" ""
          val warned = #errors (!(#result s))
          val () = check s ("a warning does not name where the file is now: " ^ warned)
                         (String.isSubstring "new/foo/a.sml:1:5: warning" warned andalso not (String.isSubstring "old/foo" warned))
          val () = check s "the program names the old path" (not (String.isSubstring "old/foo" (CachePlant.binary (path s "p.rbc"))))
          val () = OS.FileSys.rename {old = path s "new/foo", new = path s "new/bar"}
          val () = put s "p.build" "new/bar/a.sml main.sml"
        in buildFile s "p.build" "new/bar/a.sml main.sml" end
    | "S94" =>
        (* two libraries of one name: their files of one path are two units
           by a rank, and a client is taken to the one it named (E16) *)
        let
          val () = own s ""
          val () = put s "rune.workspace" ""
          val () = List.app (fn dir => put s (dir ^ "/library.build") "files a.sml end") ["x/util", "y/util"]
          val () = put s "x/util/a.sml" "structure A = struct val n = ref 0 end"
          val () = put s "y/util/a.sml" "structure A = struct val n = ref 0 end"
          val () = put s "keep.sml" "structure Old = A"
          val () = put s "main.sml" "val () = Old.n := 10\nval () = print (Int.toString (!A.n) ^ \" \" ^ Int.toString (!Old.n) ^ \"\\n\")"
          val () = put s "p.build" "x/util/a.sml keep.sml y/util/a.sml main.sml"
          val () = buildFile s "p.build" "x/util/a.sml keep.sml y/util/a.sml main.sml"
          val () = prints s "0 10"
          val () = buildFile s "p.build" ""
          val () = prints s "0 10"
          val () = put s "x/util/u.sml" "structure A = struct val x = 1 end\nstructure Keep = A"
          val () = put s "y/util/u.sml" "structure A = struct val x = 2 end"
          val () = put s "u2.sml" "val () = print (Int.toString (Keep.x + 0) ^ \"\\n\")"
          val () = put s "q.build" "x/util/u.sml y/util/u.sml u2.sml"
          val () = buildFile s "q.build" "x/util/u.sml y/util/u.sml u2.sml"
          val () = prints s "1"
          val () = put s "x/util/u.sml" "structure A = struct val x = 1 val y = 2 end\nstructure Keep = A"
          val () = buildFile s "q.build" "x/util/u.sml"
          val () = check s "the client was not taken across the edit"
                         (String.isSubstring "from the cache u2.sml, across util:u.sml changed" (#errors (!(#result s))))
          val () = prints s "1"
          (* a library's name leaves room for a version: no @, no : *)
          val () = put s "v@1/library.build" "files u.sml end"
          val () = put s "v@1/u.sml" "structure Keep = struct val x = 1 end"
          val () = put s "u3.sml" "val () = print (Int.toString Keep.x ^ \"\\n\")"
          val () = put s "r.build" "\"v@1/u.sml\" u3.sml"
          val () = buildFile s "r.build" "v@1/u.sml u3.sml"
          val () = put s "v@1/u.sml" "structure Keep = struct val x = 1 val y = 2 end"
          val () = buildFile s "r.build" "v@1/u.sml"
        in
          check s "a library's name holds an @" (String.isSubstring "across v_1:u.sml changed" (#errors (!(#result s))))
        end
    | "S95" =>
        (* the root file: what a build's units are named from, the nearest
           above the build, and where it finds its libraries *)
        let
          val () = own s ""
          val () = put s "rune.workspace" "(* the root *)\nroots vendor end\ntarget top = top.build \"--target=stack\" end"
          val () = put s "src/a.sml" "structure A = struct val x = 1 end"
          val () = put s "src/b.sml" "structure B = struct val y = A.x + 1 end"
          val () = put s "tests/t.sml" "val () = print (Int.toString B.y ^ \"\\n\")"
          val () = put s "top.build" "src/a.sml src/b.sml"
          val () = put s "tests/t.build" "../src/a.sml ../src/b.sml t.sml"
          val () = buildFile s "top.build" "src/a.sml src/b.sml"
          val () = buildFile s "tests/t.build" "tests/t.sml"
          val () = prints s "2"
          val () = put s "tests/rune.workspace" ""
          val () = buildFile s "tests/t.build" "tests/../src/a.sml tests/../src/b.sml tests/t.sml"
          val () = OS.FileSys.remove (path s "tests/rune.workspace")
          val () = put s "vendor/foo/library.build" "files foo.sml end"
          val () = put s "vendor/foo/foo.sml" "structure Foo = struct val z = 5 end"
          val r = command s "" [#compiler s, "--basis-index", "vendor/foo"]
          val () = check s ("a library of a root does not index: " ^ #errors r) (#status r = 0)
          val () = put s "main.sml" "val () = print (Int.toString Foo.z ^ \"\\n\")"
          val () = put s "m.build" "libraries foo end\nmain.sml"
          val () = buildFile s "m.build" "vendor/foo/foo.sml main.sml"
          val () = prints s "5"
          val () = put s "rune.workspace" ""
          val r = command s "" [#compiler s, "--build", "m.build", "--units", "--no-cache", "-o", "p.rbc"]
          val () = check s "a library was found under no root" (#status r <> 0)
          val () = put s "p.build" "src/a.sml"
        in
          List.app (refused s)
            [("frob", "unexpected frob"), ("roots /usr/lib end", "relative"), ("roots $(HOME)/lib end", "relative"),
             ("roots lib", "does not end"), ("target a = end", "names no build file"), ("target a b.build end", "target NAME"),
             ("target a = a.build --allow-prim end", "is a string"), ("target a = a.build --target=stack end", "unexpected ="),
             ("roots a = b end", "unexpected ="),
             ("target a = a.build end target a = b.build end", "two targets"), ("(* no end", "comment")]
        end
    | "S96" =>
        (* a file outside the root, reached by ../, is named by the same
           path from the root: nothing of the machine, so a tree that moves
           keeps its entries *)
        let
          val () = own s ""
          val () = put s "tree/w/rune.workspace" ""
          val () = put s "tree/out/a.sml" "structure A = struct val x = 1 end"
          val () = put s "tree/w/main.sml" "val () = print (Int.toString A.x ^ \"\\n\")"
          val () = put s "tree/w/p.build" "../out/a.sml main.sml"
          val () = buildFile s "tree/w/p.build" "tree/w/../out/a.sml tree/w/main.sml"
          val () = prints s "1"
          val () = buildFile s "tree/w/p.build" ""
          val () = OS.FileSys.rename {old = path s "tree", new = path s "moved"}
          val () = buildFile s "moved/w/p.build" ""
        in prints s "1" end
    | "S97" =>
        (* the REPL's use: however a path spells a file, one unit *)
        (own s ""; put s "a.sml" "structure A = struct val n = ref 0 end";
         let val _ = session s false ["use \"a.sml\";"]
             val entries = cache s
             val output = session s false ["use \"./a.sml\";", "val n = !A.n;"]
         in check s ("a spelling compiled a used file again: " ^ output)
              (String.isSubstring "val n = 0 : int" output andalso cache s = entries) end)
    | "S121" =>
        (* an identity holds no unit's identity: a unit whose import changed
           in nothing it names keeps its own, and what named it is exact *)
        let
          val () = own s ""
          val () = put s "a.sml" "structure A = struct type t = int  val x : t = 1  val y = 2 end"
          val () = put s "b.sml" "structure B = struct val v : A.t = A.x end"
          val () = put s "c.sml" "val () = print (Int.toString B.v ^ \"\\n\")"
          val () = put s "p.build" "a.sml b.sml c.sml"
          fun across wanted =
            check s ("what was taken across a change: " ^ #errors (!(#result s)))
                    (String.isSubstring "rune: from the cache b.sml, across " (#errors (!(#result s)))
                     andalso (String.isSubstring "rune: from the cache c.sml\n" (#errors (!(#result s)))) = wanted)
          val () = buildFile s "p.build" "a.sml b.sml c.sml"
          val () = put s "a.sml" "structure A = struct type t = int  val x : t = 1  val y = \"two\" end"
          val () = buildFile s "p.build" "a.sml"
          val () = across true
          (* the numbers of A's names all move, and what they are does not *)
          val () = put s "a.sml" "structure A = struct type n = bool  val m = true  type t = int  val x : t = 1  val y = 2 end"
          val () = buildFile s "p.build" "a.sml"
          val () = across true
        in prints s "1" end
    | "S122" =>
        (* a unit's bytes the same, and an import it names another: its
           identity moves, or what names it alone would hold by its binder *)
        let
          val () = own s ""
          val () = put s "a.sml" "structure A = struct datatype t = X | Y end"
          val () = put s "b.sml" "structure B = struct val v = A.X  fun same (a, b) = a = b end"
          val () = put s "c.sml" "val () = print (Bool.toString (B.same (B.v, B.v)) ^ \"\\n\")"
          val () = put s "p.build" "a.sml b.sml c.sml"
          val () = buildFile s "p.build" "a.sml b.sml c.sml"
          val () = put s "a.sml" "structure A = struct datatype t = X of int option | Y end"
          val () = put s "b.sml" "structure B = struct val v = A.Y  fun same (a, b) = a = b end"
          val () = buildFile s "p.build" "a.sml b.sml c.sml"
          val () = put s "a.sml" "structure A = struct datatype t = Y | X of int option end"
          val () = buildFile s "p.build" "a.sml b.sml c.sml"
        in prints s "true" end
    | "S123" =>
        (* a name that is another unit's marked function: the unit's identity
           moves with the function's body, which its clients copy *)
        let
          val () = own s ""
          fun declaring n = put s "a.sml" ("structure A = struct fun inc (x : int) = x + " ^ n ^ " end")
          val () = declaring "1"
          val () = put s "b.sml" "structure B = struct val f = A.inc end"
          val () = put s "c.sml" "val () = print (Int.toString (B.f 1) ^ \"\\n\")"
          val () = put s "p.build" "inline val A.inc end\nfiles a.sml b.sml c.sml end"
          val () = buildFile s "p.build" "a.sml b.sml c.sml"
          val () = prints s "2"
          val () = declaring "2"
          val () = buildFile s "p.build" "a.sml b.sml c.sml"
        in prints s "3" end
    | "S124" =>
        (* a signature written as a reference to an earlier unit's: what it
           is is that one, so the identity moves with it, though the bytes
           of the unit that refers to it stay the same *)
        let
          val () = own s ""
          val () = put s "a.sml" "signature S = sig type t  val x : t end"
          val () = put s "b.sml" "signature T = sig structure I : S end"
          val () = put s "c.sml" "structure M : T = struct structure I = struct type t = int  val x = 1 end end"
          val () = put s "p.build" "a.sml b.sml c.sml"
          val () = buildFile s "p.build" "a.sml b.sml c.sml"
          val () = put s "a.sml" "signature S = sig type t  val x : t  val y : t end"
          val r = command s "" [#compiler s, "--build", "p.build", "--units", "--cache-dir", "cache", "-o", "p.rbc"]
        in check s "a client of a signature that changed was taken from the cache" (#status r <> 0) end
    | "S58" => parallel s
    | n => if String.isPrefix CacheFacts.prefix n then CacheFacts.one s
           else if String.isPrefix CacheFlags.prefix n then CacheFlags.one s
           else if CacheChecks.handles n then CacheChecks.one s
           else simple s
    end
  val cases = ["S1", "S2", "S3", "S5", "S6", "S8", "S17", "S18", "S19", "S29", "S13", "S24", "S31", "S33", "S34", "S36", "S28", "S40",
               "S4", "S7", "S9", "S10", "S11", "S12", "S14", "S15", "S16", "S20", "S21", "S22", "S23", "S25", "S26", "S30", "S32", "S35",
               "S57", "S56", "S49", "S50", "S51", "S52", "S53", "S54", "S55", "S58", "S59", "S60", "S61", "S62", "S63", "S64", "S65", "S66", "S67", "S68", "S69", "S70", "S71", "S72", "S73", "S74", "S75", "S76", "S77", "S78", "S79", "S80", "S81", "S82", "S83", "S84", "S85", "S86", "S87", "S88", "S89", "S90", "S91", "S92", "S93", "S94", "S95", "S96", "S97", "S121", "S122", "S123", "S124"] @ CacheFacts.cases @ CacheFlags.cases @ CacheChecks.cases
  fun runCase name compiler =
    let val s = create name compiler
    in one s; say ("PASS incremental." ^ name ^ ": " ^ Int.toString (!(#assertions s)) ^ " assertions\n") end
end
