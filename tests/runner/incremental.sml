(* Incremental compiler scenarios. Rebuild sets are explicit expectations;
   every successful checked build is compared with a fresh compilation. *)
structure Incremental =
struct
  open Sh
  exception Failed of string
  fun need (ok, why) = if ok then () else raise Failed why
  val all = "a.sml b.sml c.sml d.sml main.sml"
  type state = {name : string, compiler : string, directory : string ref,
                serial : int ref, flags : string list ref, result : Scenarios.result ref,
                environment : (string * string) list ref, assertions : int ref}
  fun create name compiler : state =
    {name = name, compiler = fromRoot compiler, directory = ref (run ^ "/incremental/" ^ name),
     serial = ref 0, flags = ref [], result = ref {status = 0, output = "", errors = ""},
     environment = ref [], assertions = ref 0}
  fun path (s : state) file = !(#directory s) ^ "/" ^ file
  fun check (s : state) message ok =
    (need (ok, #name s ^ ": " ^ message); #assertions s := !(#assertions s) + 1)
  fun put s file text = (mkdirs (OS.Path.dir (path s file)); write (path s file, text ^ "\n"))
  fun reset (s : state) = (rmTree (!(#directory s)); mkdirs (!(#directory s)))
  fun copy old new = (mkdirs (OS.Path.dir new); CachePlant.writeBinary new (CachePlant.binary old))
  fun copyTree old new = if isDir old then
       (mkdirs new; List.app (fn name => copyTree (old ^ "/" ^ name) (new ^ "/" ^ name)) (entries old)) else copy old new
  fun fresh s = (reset s; List.app (fn file => copy (fromRoot ("tests/incremental/project/" ^ file)) (path s file))
                                              (String.tokens Char.isSpace all @ ["files"]))
  fun own s files = (reset s; put s "files" files)
  fun fixture s file version = put s file (IncrementalFixtures.get (#name s, file, version))
  fun replace text old new =
    let val () = need (old <> "" andalso String.isSubstring old text, "edit source does not contain " ^ old)
        fun loop text = let val (prefix, after) = Substring.position old (Substring.full text)
                        in if Substring.isEmpty after then text else Substring.string prefix ^ new
                             ^ loop (Substring.string (Substring.triml (size old) after)) end
    in loop text end
  fun edit s file old new = write (path s file, replace (read (path s file)) old new)
  fun command (s : state) stdin args =
    let val n = !(#serial s) + 1
        val () = #serial s := n
        val log = path s ("logs/" ^ Int.toString n)
        val () = mkdirs (OS.Path.dir log)
        val envf = List.foldl (fn ((name, value), f) => setEnv (name, value) o f)
                             (unsetEnv ["FORCE_COLOR", "CLICOLOR_FORCE"]) (!(#environment s))
        val status = Children.exec {addressSpace = NONE, cpuTime = SOME 600,
                                   fileSize = SOME (1024 * 1024 * 1024), core = SOME 0} envf
          {cmd = args, dir = SOME (!(#directory s)), stdin = stdin,
           stdout = log ^ ".out", stderr = log ^ ".err", timeout = 600}
    in {status = status, output = read (log ^ ".out"), errors = read (log ^ ".err")} : Scenarios.result end
  fun compile s flags output = command s "" (#compiler s :: flags @ words (path s "files") @ ["-o", output])
  fun build (s : state) flags =
    let val result = compile s (["--units", "--cache-dir", "cache", "--explain-rebuild"] @ flags) "p.rbc"
    in #flags s := flags; #result s := result; write (path s "build.err", #errors result) end
  fun compiled (s : state) = List.filter (fn file => not (String.isSubstring "/" file)) (Scenarios.rebuilt (#errors (!(#result s))))
  fun want (s : state) expected =
    let val result = !(#result s)
        val () = check s ("compiled [" ^ String.concatWith " " (compiled s) ^ "], wanted [" ^ expected ^ "]")
                           (compiled s = String.tokens Char.isSpace expected)
        val () = check s "expected a successful build" (#status result = 0)
        val plain = compile s (["--units", "--no-cache"] @ !(#flags s)) "nocache.rbc"
    in check s "cached program differs from uncached compilation"
               (#status plain = 0 andalso same (path s "p.rbc", path s "nocache.rbc")) end
  fun fails (s : state) = check s "expected compilation failure" (#status (!(#result s)) <> 0)
  fun prints (s : state) expected =
    let val stack = List.exists (fn flag => flag = "--target=stack") (!(#flags s))
        val vm = OS.Path.dir (#compiler s) ^ (if stack then "/runevm-stack" else "/runevm")
        val result = command s "" [vm, "p.rbc"]
    in check s ("program output differs: " ^ String.toString (#output result ^ #errors result))
          (#output result ^ #errors result = expected ^ "\n") end
  fun entriesBelow directory =
    let fun walk path = if isDir path then List.concat (List.map (fn name => walk (path ^ "/" ^ name)) (entries path)) else [path]
    in if exists directory then sort (walk directory) else [] end
  fun cache s = List.filter (fn file => not (String.isSubstring "/units/" file)) (entriesBelow (path s "cache"))
  fun session (s : state) verify input =
    let val file = path s "session.in"
        val () = write (file, String.concat (List.map (fn line => line ^ "\n") input))
        val old = !(#environment s)
        val () = #environment s := ("RUNE_CACHE", path s "cache") :: ("RUNE_VERIFY_CACHE", if verify then "1" else "") :: old
        val result = command s file [OS.Path.dir (#compiler s) ^ "/rune-repl", "--no-init"]
        val () = #environment s := old
    in #output result ^ #errors result end
  fun basis s = copyTree (fromRoot "lib/basis") (path s "lib/basis")
  fun standard s = (fresh s; build s [])
  fun checkBuild s flags expected = (build s flags; want s expected)
  fun custom s files = (own s files; List.app (fn file => fixture s file 0) (String.tokens Char.isSpace files))
  fun functorFixity s = custom s "y.sml a.sml c.sml main.sml"
  fun selectedEntry s text = List.filter (fn file => String.isSubstring text (CachePlant.binary file)) (cache s)
  fun only [file] = file | only _ = raise Failed "expected exactly one matching cache entry"
  fun simple (s : state) =
    let fun e file old new = edit s file old new
        fun b flags expected = checkBuild s flags expected
        fun f file version = fixture s file version
        fun c files = custom s files
    in case #name s of
      "S1" => (fresh s; b [] all; copy (path s "p.rbc") (path s "cold.rbc"); b [] "";
                check s "warm differs from cold" (same (path s "p.rbc", path s "cold.rbc")))
    | "S2" => (standard s; e "a.sml" "fun area (Square n) = n * n" "fun area (Square n) = n * n * 1"; b [] "a.sml")
    | "S3" => (standard s; e "a.sml" "datatype shape = Square of int | Rect of int * int" "datatype shape = Square of int | Rect of int * int | Line of int";
                e "a.sml" "    | area (Rect (w, h)) = w * h" "    | area (Rect (w, h)) = w * h\n    | area (Line _) = 0"; b [] "a.sml b.sml d.sml main.sml")
    | "S4" => (standard s; e "a.sml" "  val unused = 0" "  val unused = \"zero\"\n  val extra = 1"; b [] "a.sml")
    | "S5" => (standard s; copy (path s "a.sml") (path s "original"); e "a.sml" "val unused = 0" "val unused = 0 val more = 1";
                b [] "a.sml"; copy (path s "original") (path s "a.sml"); b [] "")
    | "S6" => (standard s; OS.FileSys.setTime (path s "a.sml", NONE); b [] "")
    | "S8" => (standard s; e "c.sml" "fun area2 x = 2 * S.area x" "fun area2 x = 3 * S.area x"; b [] "c.sml d.sml")
    | "S9" => (standard s; e "a.sml" "datatype shape = Square of int | Rect of int * int" "datatype shape = Rect of int * int | Square of int";
                b [] "a.sml b.sml d.sml main.sml"; prints s "20\nhandled a")
    | "S10" => (standard s; e "a.sml" "Rect of int * int" "Rect of {w : int, h : int}";
                e "a.sml" "area (Rect (w, h))" "area (Rect {w, h})"; b [] "a.sml b.sml d.sml main.sml"; prints s "20\nhandled a")
    | "S11" => (c "p.sml q.sml r.sml"; b [] "p.sml q.sml r.sml"; f "p.sml" 1; b [] "p.sml q.sml r.sml"; prints s "4")
    | "S12" => (c "s.sml u.sml v.sml"; b [] "s.sml u.sml v.sml"; f "s.sml" 1; b [] "s.sml u.sml")
    | "S13" => (fresh s; e "b.sml" "fun area s = A.area s + 1" "fun ++ x = x + 1  fun area s = ++ (A.area s)";
                 b [] all; e "a.sml" "structure A =" "infix 5 ++\nstructure A ="; build s []; fails s)
    | "S14" => (c "k.sml m.sml"; b [] "k.sml m.sml"; f "k.sml" 1; b [] "k.sml m.sml"; prints s "ok")
    | "S15" => (c "e.sml r.sml h.sml u.sml"; b [] "e.sml r.sml h.sml u.sml"; f "e.sml" 1; b [] "e.sml r.sml h.sml"; prints s "one\nu")
    | "S16" => (c "o.sml p.sml"; b [] "o.sml p.sml"; f "o.sml" 1; b [] "o.sml p.sml"; prints s "2")
    | "S17" => (standard s; put s "files" "a.sml c.sml b.sml d.sml main.sml"; b [] "")
    | "S18" => (standard s; put s "e.sml" "val unrelated = 1"; put s "files" "a.sml b.sml e.sml c.sml d.sml main.sml"; b [] "e.sml")
    | "S19" => (standard s; put s "s.sml" "structure B : SHAPE = struct type t = A.shape fun area _ = 0 end";
                 put s "files" "a.sml b.sml c.sml s.sml d.sml main.sml"; b [] "s.sml d.sml")
    | "S20" => (fresh s; f "x.sml" 0; put s "files" "a.sml b.sml x.sml c.sml d.sml main.sml"; b [] "a.sml b.sml x.sml c.sml d.sml main.sml";
                 put s "files" all; b [] ""; put s "files" "a.sml c.sml d.sml main.sml"; build s []; fails s)
    | "S21" => (standard s; OS.FileSys.rename {old = path s "c.sml", new = path s "c2.sml"};
                 put s "files" "a.sml b.sml c2.sml d.sml main.sml"; b [] "c2.sml d.sml")
    | "S23" => (c "a.sml A.sml main.sml"; if not (String.isSubstring "Lo" (read (path s "a.sml"))) then say "SKIP case-insensitive file system\n" else
                 (b [] "a.sml A.sml main.sml"; f "A.sml" 1; b [] "A.sml"; prints s "4"))
    | "S24" => (fresh s; b ["-O1"] all; b ["-O0"] all; b ["-O1"] "")
    | "S25" => (fresh s; b [] all; b ["--target=stack"] all; b [] ""; b ["--target=stack"] "")
    | "S26" => (fresh s; b [] all; b ["--int-bits=64"] all; b [] "")
    | "S30" => (fresh s; b ["-O0"] all; b ["-O2"] all; b ["-O0"] ""; b ["-O2"] "")
    | "S31" => (standard s; copy (path s "b.sml") (path s "original");
                 e "b.sml" "A.area s + 1" "A.area s + \"1\""; build s []; fails s;
                 copy (path s "original") (path s "b.sml"); e "b.sml" "(* uses a.sml *)" "(* uses a.sml, mended *)"; b [] "b.sml")
    | "S32" => (c "w.sml"; b [] "w.sml"; b [] ""; check s "warning was not replayed"
                 (String.isSubstring "w.sml:1:5: warning: match is not exhaustive" (#errors (!(#result s)))))
    | "S49" => (functorFixity s; b [] "y.sml a.sml c.sml main.sml"; prints s "4"; f "a.sml" 1; b [] "a.sml c.sml main.sml"; prints s "14")
    | "S50" => (c "a.sml c.sml z.sml main.sml"; b [] "a.sml c.sml z.sml main.sml"; prints s "false";
                 f "a.sml" 1; b [] "a.sml c.sml main.sml"; prints s "true")
    | "S51" => (c "a.sml c.sml z.sml main.sml"; b [] "a.sml c.sml z.sml main.sml"; prints s "7";
                 f "a.sml" 1; b [] "a.sml c.sml main.sml"; prints s "7")
    | "S52" => (c "a.sml main.sml"; b [] "a.sml main.sml"; prints s "2 30"; f "a.sml" 1; b [] "a.sml"; prints s "2 30")
    | "S56" => (c "t.sml"; b [] "t.sml"; let val result = command s "" [OS.Path.dir (#compiler s) ^ "/runevm", "p.rbc"]
                 in check s "trace names the library elsewhere" (String.isSubstring "lib/basis/mono_vector_fn.sml:" (#errors result)
                                                      andalso String.isSubstring " at /" (#errors result)) end)
    | "S59" => (c "a.sml b.sml c.sml"; b [] "a.sml b.sml c.sml"; put s "files" "b.sml a.sml c.sml";
                 build s ["--verify-cache"]; check s "entry did not verify in another order" (#status (!(#result s)) = 0); prints s "41")
    | "S60" => (own s "colors.sml main.sml"; f "main.sml" 0;
                 put s "colors.sml" ("structure Colors = struct datatype t = " ^ String.concatWith " | " (List.tabulate (300, fn n => "C" ^ Int.toString (n+1)))
                                  ^ "\n fun index C1 = 1 | index _ = 0 end"); build s ["--emit-units", "units"];
                 let val files = List.filter (String.isSuffix "colors.rbi") (entriesBelow (path s "units"))
                     val bytes = OS.FileSys.fileSize (only files)
                 in check s "basis of 300 constructors exceeds its size bound" (#status (!(#result s)) = 0 andalso bytes > 0 andalso bytes < 100000) end; prints s "1")
    | "S61" => (c "a.sml b.sml main.sml"; b [] "a.sml b.sml main.sml"; f "a.sml" 1; b [] "a.sml b.sml main.sml"; prints s "42 0")
    | "S62" => (c "p.sml"; b ["--or-patterns"] "p.sml"; prints s "small"; build s []; fails s;
                 own s "d.sml"; f "d.sml" 0; b ["--default-type=int64"] "d.sml"; prints s "1"; build s []; fails s)
    | "S63" => (c "p.sml"; b ["--unicode"] "p.sml"; prints s "read"; b [] "p.sml"; b ["--unicode=latin1"] "p.sml";
                 b ["--unicode"] ""; b [] ""; prints s "read"; own s "--build p.build"; f "p.sml" 1; f "p.build" 0;
                 b [] "p.sml"; prints s "built"; b ["--unicode"] ""; f "p.build" 1; b ["--unicode"] "p.sml"; b [] "")
    | "S64" => (own s "p.sml"; put s "p.sml" "val x\206\187 = 1\nval () = print \"linted\\n\"";
                 let fun lint flags files expected = (b flags files; check s "unicode lint differs"
                        ((String.isSubstring "p.sml:1:5: warning: the name x" (#errors (!(#result s)))
                          andalso String.isSubstring "mixes scripts" (#errors (!(#result s)))) = expected))
                 in lint ["--unicode"] "p.sml" true; prints s "linted"; lint ["--unicode", "--no-unicode-lints"] "p.sml" false;
                    lint ["--unicode", "--no-unicode-lints"] "" false; lint ["--unicode"] "" true end)
    | "S65" => (c "c.sml b.sml d.sml main.sml"; b ["--emit-units", "u1"] "c.sml b.sml d.sml main.sml"; prints s "22";
                 f "c.sml" 1; b ["--emit-units", "u2"] "c.sml b.sml"; prints s "24";
                 let val name = OS.Path.file (only (List.filter (String.isSuffix "-b.rbi") (entriesBelow (path s "u1"))))
                 in check s "b.sml's basis changed with functor body" (same (path s ("u1/" ^ name), path s ("u2/" ^ name))) end)
    | "S66" => (c "c.sml g.sml main.sml"; b [] "c.sml g.sml main.sml"; prints s "6"; f "c.sml" 1;
                 b [] "c.sml main.sml"; prints s "9"; f "c.sml" 2; b [] "c.sml g.sml main.sml"; prints s "9")
    | "S67" => (c "c.sml main.sml"; b [] "c.sml main.sml"; prints s "5";
                 check s "no entry to plant" (List.exists (fn x => x) (List.map (fn file => CachePlant.basisVersion file "c.sml" 5) (cache s)));
                 b ["--explain-rebuild"] "c.sml"; prints s "5"; check s "basis version was not diagnosed"
                   (String.isSubstring "c.sml" (#errors (!(#result s))) andalso String.isSubstring "of another version" (#errors (!(#result s)))))
    | "S68" => (fresh s; e "a.sml" "  val unused = 0" "  val unused = 0\n  fun same (x : 'a) = 0";
                 e "b.sml" "fun area s = A.area s + 1" "fun area s = A.area s + 1 + A.same 1.5"; b [] all;
                 e "a.sml" "fun same (x : 'a) = 0" "fun same x = if x = x then 0 else 1"; build s []; fails s)
    | "S69" => (fresh s; e "a.sml" "  val unused = 0\nend" "  val unused = 0\nend\nsignature HAS = sig type u end";
                 put s "e.sml" "structure E : HAS = struct type u = real end";
                 put s "files" "a.sml b.sml e.sml c.sml d.sml main.sml"; b [] "a.sml b.sml e.sml c.sml d.sml main.sml";
                 e "a.sml" "sig type u end" "sig eqtype u end"; build s []; fails s)
    | "S72" => (c "a.sml m.sml b.sml"; b [] "a.sml m.sml b.sml"; prints s "2";
                 let val withM = cache s
                 in c "a.sml b.sml"; b [] "a.sml b.sml"; prints s "2";
                    check s "b.sml's usages depend on what an earlier unit fingerprinted"
                      (List.all (fn file => List.exists (fn other => other = file) withM) (cache s)) end)
    | _ => raise Failed ("not a simple scenario: " ^ #name s)
    end
end
