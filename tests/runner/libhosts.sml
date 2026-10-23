(* The libraries on the native hosts' own Basis, M13. Each program is a
   job; a host's final job rejects deviations matching none of its failures.
   HOST-ABSENT here explains a build failure, as in the former shell suite;
   it does not skip the program. *)
structure LibHosts =
struct
  open Sh

  val random = ["lib/random/random_sig.sml", "lib/random/random.sml"]
  fun unit () = random @ Hosts.portable "test/property" @ Hosts.portable "test/unit"
  type test = {label : string, libraries : string list, source : string, judge : string}
  val tests =
    [{label = "random.kat", libraries = [], source = "tests/lib/random/kat.sml", judge = "kat"},
     {label = "random.props", libraries = ["unit"], source = "tests/lib/random/props.sml", judge = "props"},
     {label = "property.core", libraries = ["property"], source = "tests/lib/property/core.sml", judge = "core"},
     {label = "property.shrink", libraries = ["property"], source = "tests/lib/property/shrink.sml", judge = "props"},
     {label = "unit.core", libraries = ["unit"], source = "tests/lib/unit/core.sml", judge = "props"}]
    @ List.map (fn (label, libraries, source) => {label = label, libraries = "unit" :: libraries,
                                               source = "tests/lib/" ^ source ^ ".sml", judge = "props"})
      [("unicode.utf8", ["unicode"], "unicode/utf8"),
       ("unicode.graphemes", ["unicode"], "unicode/graphemes"),
       ("unicode.normalize", ["unicode"], "unicode/normalize"),
       ("unicode.normalize-props", ["unicode"], "unicode/normalize_props"),
       ("unicode.identifier", ["unicode"], "unicode/identifier"),
       ("unicode.security", ["unicode"], "unicode/security"),
       ("json.suite", ["unicode", "json"], "json/suite"),
       ("json.roundtrip", ["unicode", "json"], "json/roundtrip"),
       ("terminal.key", ["unicode", "terminal"], "terminal/key"),
       ("terminal.style", ["unicode", "terminal"], "terminal/style"),
       ("terminal.emulator", ["unicode", "terminal"], "terminal/emulator"),
       ("terminal.edit", ["unicode", "terminal"], "terminal/edit"),
       ("digest.digest", ["digest"], "digest/digest"),
       ("jsonrpc.jsonrpc", ["unicode", "json", "jsonrpc"], "jsonrpc/jsonrpc"),
       ("dap.dap", ["unicode", "json", "jsonrpc", "dap"], "dap/dap"),
       ("pretty.pretty", ["unicode", "pretty"], "pretty/pretty"),
       ("markdown.spec", ["unicode", "json", "pretty", "markdown"], "markdown/spec"),
       ("zmtp.zmtp", ["zmtp"], "zmtp/zmtp"),
       ("jupyter.jupyter", ["unicode", "json", "digest", "zmtp", "jupyter"], "jupyter/jupyter"),
       ("language.c.frontend", ["language/c"], "language/c/frontend"),
       ("language.c.target", ["language/c"], "language/c/target"),
       ("language.c.analysis", ["language/c"], "language/c/analysis"),
       ("ffi.marshal.core", ["unicode", "ffi/marshal"], "ffi/marshal/core"),
       ("ffi.model.shim", ["unicode", "json", "language/c", "ffi/model"], "ffi/model/shim"),
       ("ffi.model.target", ["unicode", "json", "language/c", "ffi/model"], "ffi/model/target"),
       ("ffi.model.generate", ["unicode", "json", "language/c", "ffi/model"], "ffi/model/generate"),
       ("ffi.model.policy", ["unicode", "json", "language/c", "ffi/model"], "ffi/model/policy"),
       ("ffi.win32.common", ["ffi/win32/common"], "ffi/win32/common/core"),
       ("ffi.win32.values", ["ffi/win32/common"], "ffi/win32/common/values")]
  fun files libraries =
    let fun one "unit" = unit ()
          | one "property" = random @ Hosts.portable "test/property" @ Hosts.portable "test/property/basis"
          | one lib = Hosts.portable lib
    in if null libraries then random else List.concat (List.map one libraries) end

  val out = run ^ "/lib-hosts"
  fun location (host, label) = out ^ "/" ^ host ^ "/" ^ label
  val deviations = "tests/lib/deviations.txt"
  fun explains ls host label = Expectations.find (ls, {way = "native:" ^ host, path = label, label = NONE})

  fun reference () =
    let
      val () = mkdirs out
      val log = out ^ "/reference.err"
      fun command args stdout = exec {cmd = args, dir = NONE, stdin = "", stdout = stdout, stderr = log, timeout = 60}
    in
      if command [env ("CC", "cc"), "-O2", "-o", out ^ "/random-reference", "tests/lib/random/reference.c"] log = 0
         andalso command [out ^ "/random-reference"] (out ^ "/random-kat.expected") = 0 then ()
      else say ("FAIL random-reference: does not build or run: " ^ firstLine log ^ "\n")
    end

  fun outputOK kind output expected fingerprint =
    let
      val ls = lines output
      fun starts p = List.exists (String.isPrefix p) ls
      val props = starts "PASS" andalso not (starts "FAIL")
      val kat = String.concat (List.map (fn l => l ^ "\n")
                    (List.filter (fn l => List.exists (fn p => String.isPrefix p l) ["seed", "split", "below"]) ls))
      val prints = List.mapPartial (fn l => if String.isPrefix "fingerprint" l then
                     (case String.fields (fn c => c = #" ") l of _ :: f :: _ => SOME f | _ => SOME "") else NONE) ls
    in case kind of
         "kat" => kat = expected
       | "props" => props
       | "core" => props andalso String.concatWith "\n" prints = fingerprint
       | _ => false
    end

  fun accepts kind {built, status, output} expected fingerprint =
    built andalso status = 0 andalso outputOK kind output expected fingerprint

  (* These two new generator deviations have exact observed failure shapes.
     A different assertion, build failure, timeout, or post-PASS crash must
     remain a failure even when a label has a HOST-BUG entry. *)
  fun generatorHostBug host label {built, status, output} =
    if label <> "ffi.model.generate" then true
    else if String.isPrefix "smlnj" host then
      let fun verdict [] = ""
            | verdict (line :: rest) =
                if String.isPrefix "PASS " line then String.concat (List.map (fn s => s ^ "\n") (line :: rest))
                else verdict rest
      in built andalso status = 1 andalso verdict (lines output) = read "tests/lib/ffi/model/generate.smlnj.expected" end
    else if host = "mlkit" then built andalso status = 139 andalso output = ""
    else true

  fun generatorNoRegionInference () =
    let
      val host = Hosts.get "mlkit"
      val dir = location ("mlkit", "ffi.model.generate-no-ri")
      val () = mkdirs dir
      val wrapper = OS.FileSys.fullPath dir ^ "/mlkit-no-ri"
      val () = write (wrapper, "#!/bin/sh\nexec " ^ quote (#program host) ^ " -no_ri \"$@\"\n")
      val () = Posix.FileSys.chmod (wrapper, Posix.FileSys.S.flags
        [Posix.FileSys.S.irusr, Posix.FileSys.S.iwusr, Posix.FileSys.S.ixusr])
      val result = Hosts.build {host = {name = "mlkit", program = wrapper, library = #library host},
        name = "generate-no-ri", sources = files ["unit", "unicode", "json", "language/c", "ffi/model"]
          @ ["tests/lib/ffi/model/generate.sml"], dir = dir, runDir = root, timeout = 600, memory = 2048}
      val expected = read "tests/lib/ffi/model/generate.smlnj.expected"
      (* The positive comparison still checks every named verdict, in order. *)
      val expected = String.concat (List.map (fn line =>
        if line = "FAIL ffi/model/generate/duplicate narrowed selectors rejected" then "PASS ffi/model/generate/duplicate narrowed selectors rejected\n"
        else if line = "  - duplicate narrowed selectors rejected" then ""
        else if line = "SUMMARY 32 tests, 31 passed, 1 failed, 0 skipped" then "SUMMARY 32 tests, 32 passed, 0 failed, 0 skipped\n"
        else line ^ "\n") (lines expected))
      val () = write (dir ^ "/output", #output result)
    in
      if #built result andalso #status result = 0 andalso #output result = expected then
        say "PASS unchanged generator: 32 checks on MLKit -no_ri; default region inference remains HOST-BUG\n"
      else say ("FAIL MLKit generator -no_ri control: " ^ #messages result ^ #output result ^ "\n")
    end

  fun one (host, label) =
    let
      val t = case List.find (fn t : test => #label t = label) tests of
                SOME t => t | NONE => raise Fail ("unknown library test: " ^ label)
      val dir = location (host, label)
      val result = Hosts.build {host = Hosts.get host, name = label, sources = files (#libraries t) @ [#source t], dir = dir,
                               runDir = root,
                               timeout = getOpt (Int.fromString (env ("LIB_HOST_TIMEOUT", "600")), 600), memory = 2048}
      val output = Hosts.libraryOutput host (#output result)
      val () = write (dir ^ "/output", output)
      (* Shell command substitution strips trailing newlines, not spaces. *)
      val fingerprint = Substring.string (Substring.dropr (fn c => c = #"\n")
                          (Substring.full (read "tests/lib/property/fingerprint.expected")))
      val passed = accepts (#judge t) {built = #built result, status = #status result, output = output}
                             (read (out ^ "/random-kat.expected"))
                             fingerprint
      val () = write (dir ^ "/result", if passed then "PASS\n" else "FAIL\n")
    in
      if passed then ()
      else case explains (Expectations.read deviations) host label of
        SOME l => if generatorHostBug host label {built = #built result, status = #status result, output = output} then
          say ("EXPLAINED " ^ host ^ " " ^ label ^ ": " ^ #category l ^ ": " ^ #reason l ^ "\n")
        else say ("FAIL " ^ host ^ " " ^ label ^ ": failure differs from the recorded generator HOST-BUG (see " ^ dir ^ ")\n")
      | NONE => say ("FAIL " ^ host ^ " " ^ label ^ ": "
                    ^ (if not (#built result) then "does not build" else if #status result <> 0 then
                         (if #status result = 125 then "left a process behind" else "exited with " ^ Int.toString (#status result))
                         else "the " ^ #judge t ^ " oracle differs")
                    ^ " (see " ^ dir ^ ")\n")
    end

  fun unused ls host failed =
    List.filter (fn l : Expectations.line =>
      #category l <> "HOST-FLAKY" andalso Expectations.glob (#way l, "native:" ^ host)
      andalso not (List.exists (fn label => isSome (Expectations.find ([l], {way = "native:" ^ host, path = label, label = NONE}))) failed)) ls

  fun stale host =
    let
      val failed = List.map #label (List.filter (fn t : test => read (location (host, #label t) ^ "/result") = "FAIL\n") tests)
    in List.app (fn l => say ("FAIL stale " ^ host ^ ": " ^ Expectations.describe l ^ "\n"))
                (unused (Expectations.read deviations) host failed) end

  fun command ["lib-host-reference"] = SOME reference
    | command ["lib-host-one", host, label] = SOME (fn () => one (host, label))
    | command ["lib-host-generate-no-ri"] = SOME generatorNoRegionInference
    | command ["lib-host-stale", host] = SOME (fn () => stale host)
    | command _ = NONE

  fun jobIn pools (name, args, after, memory) =
    Test.it name {program = "/bin/sh",
                  args = ["sh", "-c", "exec \"$RUNE_TEST_ROOT\"/bin/rune-test " ^ String.concatWith " " (List.map quote args)],
                  env = NONE, dir = SOME ".", stdin = NONE,
                  timeout = Time.fromSeconds 1800, cap = 0, cpus = 1, memory = memory, pools = pools, exclusive = false,
                  after = after, judge = failLines} : Run.command Test.tree
  fun job x = jobIn [] x

  val tree = Test.tag "nightly" (Test.tag "library" (Test.tag "test-lib-hosts"
    (Test.tag "covers:tests/lib/*" (Test.tag "covers:tests/runner/hosts.sml" (Test.tag "covers:tests/runner/libhosts.sml"
      (Test.describe "lib-hosts"
        (Test.requires ["cc"] (job ("@reference", ["lib-host-reference"], [], 100)) ::
         List.map (fn host => Test.requires ["host:" ^ host]
           (Test.describe host
             (List.map (fn t : test => jobIn (if host = "mlkit" then ["matrix"] else [])
                (#label t, ["lib-host-one", host, #label t], ["lib-hosts/@reference"], 2048)) tests
              @ (if host = "mlkit" then [jobIn ["matrix"] ("ffi.model.generate-no-ri", ["lib-host-generate-no-ri"], ["lib-hosts/@reference"], 2048)] else [])
              @ [job ("@stale", ["lib-host-stale", host], List.map (fn t : test => "lib-hosts/" ^ host ^ "/" ^ #label t) tests, 10)])))
           Hosts.names)))))))
end
