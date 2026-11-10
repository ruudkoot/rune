(* rhc's corpus (tests/hs/corpus/README.md): the trees, read through
   RUNE_HS_CORPUS as ExternalChecks reads MLton's regression set; the
   manifests that land as data; a candidate's closure; and its copy in each
   variant the oracles judge, made as E8 made it (the drafts'
   results/E8/judge.py): as it stands with its pragmas blanked and the
   preprocessor run (h98), with the import rewrite (rewrite), with the 2019
   nofib's compat layer (harness), or with its pragmas kept (ext). *)
structure HsCorpus =
struct
  open Sh

  (* where the corpus's data is: tests/hs/corpus, or another for a test of
     the harness *)
  fun data () = env ("RUNE_HS_DATA", fromRoot "tests/hs/corpus")
  fun root () = env ("RUNE_HS_CORPUS", "")
  fun tree p = root () ^ "/" ^ p

  (* a TSV of the corpus: its header, and each row as a lookup by column *)
  exception Bad of string
  fun table file =
    let
      val path = data () ^ "/" ^ file
      val () = if exists path then () else raise Bad ("missing " ^ data () ^ "/" ^ file)
      val rows = List.filter (fn l => l <> "") (String.fields (fn c => c = #"\n") (read path))
      val header = case rows of h :: _ => String.fields (fn c => c = #"\t") h | [] => raise Bad (file ^ " is empty")
      fun one r =
        let val fs = String.fields (fn c => c = #"\t") r
        in if length fs = length header then ListPair.zip (header, fs)
           else raise Bad (file ^ ": a row of " ^ Int.toString (length fs) ^ " fields, not " ^ Int.toString (length header)
                           ^ ": " ^ String.substring (r, 0, Int.min (80, size r))) end
    in (header, List.map one (tl rows)) end
  fun field (row : (string * string) list) k =
    case List.find (fn (h, _) => h = k) row of SOME (_, v) => v | NONE => raise Bad ("no column " ^ k)
  fun rows file = #2 (table file)

  type candidate = {id : string, set : string, path : string, parent : string, expect : string}
  fun candidates () =
    List.map (fn r => {id = field r "id", set = field r "set", path = field r "path", parent = field r "parent",
                       expect = field r "expect"} : candidate) (rows "candidates.tsv")

  (* the sets whose program is its directory, copied whole *)
  val wholeSets = ["nhc98-nofib", "nofib-2019", "conformance98", "yhc-conformance"]
  fun whole set = List.exists (fn s => s = set) wholeSets
  val common = "nofib/common"

  fun dirname p = case OS.Path.dir p of "" => "." | d => d
  fun relative (base, p) = if String.isPrefix (base ^ "/") p then String.extract (p, size base + 1, NONE) else p

  (* where a module of the program is: a file of the directories, by its
     name's path *)
  fun findLocal (m, dirs) =
    let val p = String.map (fn #"." => #"/" | c => c) m
    in List.foldl (fn (d, SOME f) => SOME f
                    | (d, NONE) => List.foldl (fn (e, SOME f) => SOME f
                                                | (e, NONE) => let val f = d ^ "/" ^ p ^ e in if exists f then SOME f else NONE end)
                                              NONE [".hs", ".lhs"]) NONE dirs
    end

  (* the program's own modules reachable from its main (absolute paths, in
     the order they were found), with what each says of itself, and the
     modules it imports from elsewhere *)
  fun closure (main, dirs) =
    let
      fun go ([], seen, ext) = (rev seen, dedup ext)
        | go (f :: stack, seen, ext) =
            if List.exists (fn (g, _) => g = f) seen then go (stack, seen, ext)
            else
              let
                val s = HsSource.scanText (f, HsSource.universal (read f))
                val (local', ext') = List.foldl (fn (m, (l, e)) => case findLocal (m, dirs) of
                                                                     SOME p => (p :: l, e) | NONE => (l, m :: e))
                                                 ([], ext) (#imports s)
              in go (List.rev local' @ stack, (f, s) :: seen, ext') end
      and dedup xs = HsSource.dedup xs
    in go ([main], [], []) end

  (* the closure of a candidate, and the imports it takes from outside the
     Report and that the rewrite reaches *)
  fun closureOf (c : candidate) =
    let
      val main = tree (#path c)
      val dirs = [dirname main] @ (if #set c = "nofib-2019" then [tree common] else [])
      val (seen, ext) = closure (main, dirs)
      val nonreport = List.filter (fn m => not (List.exists (fn r => r = m) HsSource.report)) ext
    in {files = seen, nonreport = nonreport,
        rewritable = List.filter (fn m => isSome (HsSource.rewriteOf m)) nonreport} end

  fun copyFile (src, dst) =
    let val () = mkdirs (dirname dst)
        val i = BinIO.openIn src
        val bytes = BinIO.inputAll i before BinIO.closeIn i
        val w = BinIO.openOut dst
    in BinIO.output (w, bytes); BinIO.closeOut w end
  fun isLink p = OS.FileSys.isLink p handle OS.SysErr _ => false
  (* a directory, its symbolic links kept as links *)
  fun copyTree (src, dst) =
    (mkdirs dst;
     List.app (fn n =>
       let val s = src ^ "/" ^ n and d = dst ^ "/" ^ n
       in if isLink s then Posix.FileSys.symlink {old = OS.FileSys.readLink s, new = d}
          else if isDir s then copyTree (s, d) else copyFile (s, d) end) (Sh.sort (entries src)))

  (* the compat layer's edit of a file of the corpus, by its path there *)
  fun compatEdit rel = let val f = data () ^ "/compat/" ^ rel ^ ".sed" in if exists f then SOME f else NONE end
  fun sedTo (script, src, dst) =
    let val () = mkdirs (dirname dst)
        val status = exec {cmd = ["sed", "-f", script, src], dir = NONE, stdin = "", stdout = dst, stderr = dst ^ ".sed-err",
                           timeout = 60}
    in if status = 0 then (OS.FileSys.remove (dst ^ ".sed-err") handle OS.SysErr _ => ())
       else raise Bad ("sed -f " ^ script ^ " " ^ src ^ ": " ^ firstLine (dst ^ ".sed-err")) end
  (* a file of the corpus copied, with the compat layer's edit in the
     harness variant *)
  fun copyIn variant (src, dst) =
    case (variant = "harness", compatEdit (relative (root (), src))) of
      (true, SOME script) => sedTo (script, src, dst)
    | _ => copyFile (src, dst)

  (* the preprocessor as GHC's -cpp runs it, with GHC's own macro, so that a
     program takes its modern branches; a literate source is unlit first and
     becomes a .hs. The file the result is in *)
  fun expandCpp (q, includes) =
    let
      val src = if String.isSuffix ".lhs" q then
                  let val h = String.substring (q, 0, size q - 4) ^ ".hs"
                  in write (h, HsSource.unlit (HsSource.universal (read q))); OS.FileSys.remove q; h end
                else q
      val out = src ^ ".cpp-out"
      val status = exec {cmd = ["gcc", "-E", "-undef", "-traditional-cpp", "-P", "-x", "c", "-D__GLASGOW_HASKELL__=904",
                                "-D__HASKELL98__", "-Dlinux_HOST_OS"] @ List.map (fn i => "-I" ^ i) includes @ [src],
                         dir = NONE, stdin = "", stdout = out, stderr = out ^ ".err", timeout = 120}
    in
      if status = 0 then copyFile (out, src) else ();
      (OS.FileSys.remove out handle OS.SysErr _ => ()); (OS.FileSys.remove (out ^ ".err") handle OS.SysErr _ => ());
      src
    end

  (* every file under a directory, by name *)
  fun allFiles dir =
    List.concat (List.map (fn n => let val p = dir ^ "/" ^ n in
                                     if isLink p then (if isDir p then [] else [p])
                                     else if isDir p then allFiles p else [p] end) (Sh.sort (entries dir)))

  (* the copy of a candidate in a variant under `work`: the program's
     directory `p` (its whole directory for a set of directories, otherwise
     its closure and the boot files it names), the parent's sources beside
     it, nofib's NofibUtils where it is imported; the compat modules in the
     harness variant; then each source with its pragmas blanked, the
     preprocessor run where it wants it, and the variant's rewrite. The
     directory and the main's name *)
  fun prepare (c : candidate, variant, files : (string * HsSource.scan) list, work) =
    let
      val () = if isDir work then rmTree work else ()
      val p = work ^ "/p"
      val () = mkdirs p
      val main = tree (#path c)
      val r = dirname main
      val closureFiles = List.map #1 files
      val () =
        if whole (#set c) then
          (List.app (fn n =>
             let val s = r ^ "/" ^ n
             in if isDir s then (if exists (s ^ "/Main.hs") then () else copyTree (s, p ^ "/" ^ n))
                else copyIn variant (s, p ^ "/" ^ n) end) (Sh.sort (entries r));
           if #parent c <> "-" then
             List.app (fn s => copyIn variant (s, work ^ "/" ^ OS.Path.file s)) (glob (tree (#parent c), ".hs"))
           else ())
        else
          (List.app (fn f => copyIn variant (f, p ^ "/" ^ relative (r, f))) closureFiles;
           List.app (fn f =>
             let val stem = hd (String.fields (fn ch => ch = #".") (OS.Path.file f))
             in if List.exists (fn (_, s : HsSource.scan) => List.exists (fn b => b = stem) (#boot s)) files
                then copyFile (f, p ^ "/" ^ OS.Path.file f) else () end)
             (glob (r, ".hs-boot") @ glob (r, ".lhs-boot")))
      val () = if isDir (tree common) andalso List.exists (fn (_, s : HsSource.scan) => List.exists (fn m => m = "NofibUtils") (#imports s)) files
               then copyIn variant (tree (common ^ "/NofibUtils.hs"), p ^ "/NofibUtils.hs") else ()
      val () =
        if variant = "harness" then
          (copyFile (data () ^ "/compat/NofibCompat.hs", p ^ "/NofibCompat.hs");
           if exists (p ^ "/NofibUtils.hs") then copyFile (data () ^ "/compat/NofibUtils.hs", p ^ "/NofibUtils.hs") else ())
        else ()
      val mainName = ref (OS.Path.file (#path c))
      val inClosure = List.map (fn f => relative (r, f)) closureFiles
      fun each q =
        if not (String.isSuffix ".hs" q orelse String.isSuffix ".lhs" q) then ()
        else if not (whole (#set c)) andalso not (List.exists (fn x => x = relative (p, q)) inClosure) then ()
        else if variant = "ext" then ()
        else
          let
            val t = HsSource.universal (read q)
            val cpp = HsSource.wantsCpp t
            val t' = HsSource.blankPragmas t
            val () = if t' <> t then write (q, t') else ()
            val q' = if cpp then expandCpp (q, [p, work]) else q
            val () = if q' <> q andalso OS.Path.file q = !mainName then mainName := OS.Path.file q' else ()
            fun edit f = let val t = HsSource.universal (read q') val t' = f t in if t' <> t then write (q', t') else () end
          in
            if variant = "rewrite" then edit HsSource.rewriteImports else ();
            if variant = "harness" andalso not (List.exists (fn n => n = OS.Path.file q') ["NofibCompat.hs", "NofibUtils.hs"])
            then edit (fn t => HsSource.harnessText (t, q')) else ()
          end
    in List.app each (allFiles p); (p, !mainName) end
end
