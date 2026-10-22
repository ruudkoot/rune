(* The executable census for unit-testing-part2.md. Git supplies file names,
   not test policy: every live shell, Python and AWK file needs one owner.
   Baseline blob IDs keep the old implementation recoverable after retirement. *)
structure Migration =
struct
  open Sh
  val inventory = "tests/runner/migration.tsv"
  type entry = {path : string, kind : string, owner : string, state : string,
                blob : string, replacement : string, comparison : string}
  fun relevant p = List.exists (fn suffix => String.isSuffix suffix p) [".sh", ".py", ".awk"]
  fun parse text =
    List.map (fn line =>
      case String.fields (fn c => c = #"\t") line of
        [path, kind, owner, state, blob, replacement, comparison] =>
          {path = path, kind = kind, owner = owner, state = state, blob = blob,
           replacement = replacement, comparison = comparison} : entry
      | _ => raise Fail ("migration inventory: malformed row: " ^ line))
      (List.filter (fn l => not (String.isPrefix "#" l)) (lines text))
  fun errors (rows : entry list) actual =
    let
      fun has p = List.exists (fn r : entry => #path r = p) rows
      fun one (r : entry) =
        let
          val p = #path r
          val suffix = case #kind r of "shell" => ".sh" | "python" => ".py" | "awk" => ".awk" | _ => "?"
          val owner = List.exists (fn n => #owner r = "P2." ^ Int.toString n)
                        (List.tabulate (16, fn i => i + 1))
          val retained = List.exists (fn s => #owner r = "Retain: " ^ s)
                           ["bootstrap/setup", "installers under test", "independent oracles/peers"]
          fun bad (ok, msg) = if ok then [] else [p ^ ": " ^ msg]
        in
          bad (length (List.filter (fn x : entry => #path x = p) rows) = 1, "duplicate ownership")
          @ bad (String.isSuffix suffix p, "kind does not match file extension")
          @ bad (owner orelse retained, "unknown milestone or exception")
          @ bad (size (#blob r) = 40 andalso CharVector.all Char.isHexDigit (#blob r), "invalid baseline blob")
          @ bad (#comparison r <> "" andalso #comparison r <> "-", "missing comparison contract")
          @ (case #state r of
               "retired" => bad (not (List.exists (fn a => a = p) actual), "retired script is still present")
                  @ bad (String.isSuffix ".sml" (#replacement r) andalso exists (#replacement r), "missing SML replacement")
             | "retained" => bad (retained, "retained state needs a named exception")
                  @ bad (List.exists (fn a => a = p) actual, "retained script is absent")
             | "pending" => bad (owner, "pending script needs a migration milestone")
                  @ bad (List.exists (fn a => a = p) actual, "pending script is absent")
             | _ => [p ^ ": unknown migration state"])
        end
    in
      List.concat (List.map one rows)
      @ List.map (fn p => p ^ ": no migration owner") (List.filter (fn p => not (has p)) actual)
    end
  fun git dir args =
    let
      val out = dir ^ "/git.out"
      val err = dir ^ "/git.err"
      val status = exec {cmd = "git" :: args, dir = SOME root, stdin = "", stdout = out, stderr = err, timeout = 60}
    in if status = 0 then read out else raise Fail ("git: " ^ read err) end
  fun actual dir =
    List.filter (fn p => p <> "" andalso relevant p andalso exists p)
      (String.fields (fn c => c = #"\000")
        (git dir ["ls-files", "-z", "--cached", "--others", "--exclude-standard", "--", "scripts", "tests", "tools"]))
  fun check () =
    let val dir = run ^ "/migration"
        val () = mkdirs dir
        val problems = errors (parse (read inventory)) (actual dir)
    in List.app (fn p => say ("FAIL migration: " ^ p ^ "\n")) problems end
  fun faults () =
    let
      val rows = parse (read inventory)
      val paths = List.map #path (List.filter (fn r : entry => #state r <> "retired") rows)
      val first = hd (List.filter (fn r : entry => #state r <> "retired") rows)
      val rest = List.filter (fn r : entry => #path r <> #path first) rows
      fun rejects name rs ps = if null (errors rs ps) then say ("FAIL migration canary: accepted " ^ name ^ "\n") else ()
    in
      if null (errors rows paths) then () else say "FAIL migration canary: valid inventory rejected\n";
      rejects "missing ownership" rest paths;
      rejects "duplicate ownership" (first :: rows) paths;
      rejects "new unclassified driver" rows ("tests/unclassified-canary.py" :: paths);
      rejects "missing pending script" rows (List.filter (fn p => p <> #path first) paths);
      rejects "retirement without a replacement"
        ({path = #path first, kind = #kind first, owner = #owner first, state = "retired",
          blob = #blob first, replacement = "tests/runner/absent-migration-canary.sml", comparison = #comparison first}
         :: rest) (List.filter (fn p => p <> #path first) paths)
    end
  fun baseline dir =
    let
      val () = mkdirs dir
      fun capture (name, args) = write (dir ^ "/" ^ name, git dir args)
      val () = capture ("revision.txt", ["rev-parse", "HEAD"])
      val () = capture ("status.txt", ["status", "--porcelain=v1", "-uall"])
      val () = capture ("pending.patch", ["diff", "--binary", "HEAD"])
      val () = capture ("tracked-blobs.tsv", ["ls-files", "-s"])
      val () = capture ("host-provisioning.sh", ["show", "HEAD:scripts/fetch-hosts.sh"])
      val () = write (dir ^ "/migration.tsv", read inventory)
      val () = write (dir ^ "/root.txt", root ^ "\n")
      val () = write (dir ^ "/script-paths.txt", String.concat
        (List.map (fn r : entry => #path r ^ "\n") (parse (read inventory))))
      val callerStatus = exec {cmd = ["git", "grep", "-n", "-F", "-f", dir ^ "/script-paths.txt", "--",
                                     "Makefile", ".github", "scripts", "tests", "tools", "docs"],
                               dir = SOME root, stdin = "", stdout = dir ^ "/callers.txt", stderr = dir ^ "/callers.err", timeout = 60}
      val () = if callerStatus <= 1 then () else raise Fail "cannot record script callers"
      val () = List.app (fn p => let val dest = dir ^ "/untracked/" ^ p
                                in mkdirs (OS.Path.dir dest); write (dest, read p) end)
        (lines (git dir ["ls-files", "--others", "--exclude-standard"]))
      fun selection (flag, name) =
        let val status = exec {cmd = ["bin/rune-test", "list", flag, name], dir = SOME root, stdin = "",
                              stdout = dir ^ "/" ^ name ^ ".list", stderr = dir ^ "/" ^ name ^ ".err", timeout = 60}
        in if status = 0 then () else raise Fail ("cannot record selection " ^ name) end
      val () = List.app (fn tier => selection ("--tier", tier)) ["check", "quick", "nightly"]
      val () = List.app (fn profile => selection ("--profile", profile)) ["library", "vm", "layout", "docs"]
      val () = write (dir ^ "/environment.tsv", String.concat (List.map
        (fn key => key ^ "\t" ^ env (key, "unset") ^ "\n")
        ["RUNE_HOSTS", "MLTON", "SMLNJ", "SMLNJ32", "SMLNJ_DEV", "POLY", "MLKIT", "MLKIT_LIB", "GC_STRESS"]))
      val hosts = List.map Hosts.get Hosts.names
      val () = write (dir ^ "/host-paths.tsv", String.concat (List.map
        (fn h : Hosts.host => #name h ^ "\t" ^ (OS.FileSys.realPath (#program h) handle OS.SysErr _ => #program h) ^ "\n") hosts))
      val () = List.app (fn h : Hosts.host =>
        let val log = dir ^ "/version-" ^ #name h
            val status = exec {cmd = [#program h, if #name h = "polyml" then "--version" else "-version"],
                               dir = SOME root, stdin = "", stdout = log, stderr = log, timeout = 15}
        in write (log ^ ".status", Int.toString status ^ "\n") end) hosts
      val status = exec {cmd = "sha256sum" :: List.map #program hosts, dir = SOME root, stdin = "",
                         stdout = dir ^ "/host-binaries.sha256", stderr = dir ^ "/host-binaries.err", timeout = 60}
    in if status = 0 then say ("baseline: " ^ dir ^ "\n") else raise Fail "cannot fingerprint host binaries" end
  fun command ["migration-check"] = SOME check
    | command ["migration-faults"] = SOME faults
    | command ["migration-baseline", dir] = SOME (fn () => baseline dir)
    | command _ = NONE
  val tree = Test.tag "check" (Test.tag "quick" (Test.tag ("covers:" ^ inventory)
    (Test.tag "covers:tests/runner/migration.sml"
      (Test.describe "runner"
        [LibHosts.job ("migration-inventory", ["migration-check"], [], 100),
         LibHosts.job ("migration-faults", ["migration-faults"], [], 100)]))))
end
