(* Staged installation is a subject under test. No command here changes the
   user's installation: every prefix is below this run's private stage. *)
structure InstallChecks =
struct
  open Sh
  exception Failed of string
  fun need (ok, why) = if ok then () else raise Failed why
  fun entriesStrict directory =
    let val stream = OS.FileSys.openDir directory
        fun loop names = case OS.FileSys.readDir stream of NONE => sort names | SOME name => loop (name :: names)
    in (loop [] before OS.FileSys.closeDir stream) handle e => (OS.FileSys.closeDir stream; raise e) end
  fun files directory = List.concat (List.map (fn name =>
       let val path = directory ^ "/" ^ name
       in if isDir path andalso not (OS.FileSys.isLink path) then files path else [path] end)
         (if exists directory then entriesStrict directory else []))
  fun openTree path =
    if not (exists path) then () else if isDir path andalso not (OS.FileSys.isLink path) then
      (Posix.FileSys.chmod (path, Posix.FileSys.S.flags [Posix.FileSys.S.irusr, Posix.FileSys.S.iwusr, Posix.FileSys.S.ixusr]);
       List.app (fn name => openTree (path ^ "/" ^ name)) (entries path)) else ()
  fun execute dir label working input args =
    let val output = dir ^ "/" ^ label ^ ".out"
        val errors = dir ^ "/" ^ label ^ ".err"
        val status = Children.exec {addressSpace = NONE, cpuTime = SOME 600,
                                    fileSize = SOME (1024 * 1024 * 1024), core = SOME 0}
           (unsetEnv ["FORCE_COLOR", "CLICOLOR_FORCE"])
           {cmd = args, dir = SOME working, stdin = input, stdout = output, stderr = errors, timeout = 600}
    in {status = status, output = read output, errors = read errors} : Scenarios.result end
  fun installed name () =
    let val dir = run ^ "/install-checks/" ^ name
        val () = openTree dir
        val () = rmTree dir
        val () = mkdirs dir
        val stage = dir ^ "/stage"
        val prefix = stage ^ "/opt/rune"
        val bin = prefix ^ "/bin"
        val lib = prefix ^ "/lib/rune"
        val work = dir ^ "/work"
        val () = mkdirs work
        val () = write (work ^ "/hello.sml", "val () = print \"hello\\n\"\n")
        val () = write (work ^ "/property.sml", "val _ = Int8Arb.arb\nval () = print \"property\\n\"\n")
        val host = if name = "rbc" then [] else ["--host", name]
        fun install uninstall = execute dir (if uninstall then "uninstall" else "install") root ""
             (["sh", "scripts/install.sh", "--destdir", stage, "--prefix", "/opt/rune"] @ host @ (if uninstall then ["--uninstall"] else []))
        val () = Scenarios.success (install false)
        val manifests = List.filter (fn path => OS.Path.file path = "MANIFEST") (files (fromRoot "lib"))
        fun manifest path =
          let val library = String.extract (OS.Path.dir path, size (fromRoot "lib") + 1, NONE)
              val source = fromRoot ("lib/" ^ library)
              val names = List.mapPartial (fn line =>
                let val line = Hosts.trim line
                in if line = "" orelse String.isPrefix "#" line then NONE
                   else SOME (Hosts.trim (hd (String.fields (fn c => c = #"|") line))) end) (lines (read path))
              val names = "MANIFEST" :: names @ (if exists (source ^ "/README.md") then ["README.md"] else [])
          in List.app (fn name => need (same (source ^ "/" ^ name, lib ^ "/" ^ library ^ "/" ^ name),
                                    "installed library differs: " ^ library ^ "/" ^ name)) names end
        val () = List.app manifest manifests
        val versionLine = valOf (List.find (String.isPrefix "#define RUNE_VERSION ") (lines (read (fromRoot "runtime/version.h"))))
        val version = List.nth (String.fields (fn c => c = #"\"") versionLine, 1)
        val () = List.app (fn name => need (String.isSubstring ("\"" ^ name ^ " " ^ version ^ "\"")
                      (firstLine (prefix ^ "/share/man/man1/" ^ name ^ ".1")), "installed manual has no matching version: " ^ name))
                      ["rune", "runevm", "runedoc", "runeopt"]
        val () = List.app (fn name => let val text = read (bin ^ "/" ^ name)
                 in if String.isPrefix "#!" text then need (not (String.isSubstring root text), "installed wrapper names source tree: " ^ name) else () end)
                       (entries bin)
        fun command label input args = execute dir label work input args
        fun compile label flags source target =
          let val () = rmTree (work ^ "/" ^ target)
              val result = command label "" ([bin ^ "/rune"] @ flags @ [source, "-o", target])
          in Scenarios.success result; Scenarios.bytecode (work ^ "/" ^ target) end
        val () = compile "compile-register" [] "hello.sml" "hello.rbc"
        val () = Scenarios.output (command "rune" "" [bin ^ "/runevm", "hello.rbc"]) "hello\n"
        val () = compile "compile-units" ["--units"] "hello.sml" "units.rbc"
        val () = Scenarios.output (command "units" "" [bin ^ "/runevm", "units.rbc"]) "hello\n"
        val () = compile "compile-stack" ["--target=stack"] "hello.sml" "stack.rbc"
        val () = Scenarios.output (command "stack" "" [bin ^ "/runevm-stack", "stack.rbc"]) "hello\n"
        val () = compile "compile-library" ["--library", "test/property/basis"] "property.sml" "property.rbc"
        val () = Scenarios.output (command "library" "" [bin ^ "/runevm", "property.rbc"]) "property\n"
        val () = Scenarios.success (command "translate-native" "" [bin ^ "/runeopt", "stack.rbc", "-o", "hello-native"])
        val () = Scenarios.bytecode (work ^ "/hello-native")
        val () = Scenarios.output (command "native" "" [work ^ "/hello-native"]) "hello\n"
        val () = Scenarios.success (command "runedoc" "" [bin ^ "/runedoc", "--library", "json", "--out", "doc"])
        val () = Scenarios.bytecode (work ^ "/doc/README.md")
        val input = work ^ "/repl.input"
        val () = write (input, "val x = 1 + 41;\n")
        fun repl label args =
          let val result = command label input args
              val () = Scenarios.success result
              val values = List.filter (String.isSubstring "val x") (lines (#output result))
          in need (values = ["- val x = 42 : int"], "installed REPL output differs: " ^ label) end
        val () = repl "repl" [bin ^ "/rune-repl"]
        val () = repl "rune-i" [bin ^ "/rune", "-i"]
        val dap = "{\"seq\":1,\"type\":\"request\",\"command\":\"initialize\",\"arguments\":{\"adapterID\":\"rune\"}}"
        val input = work ^ "/dap.input"
        val () = write (input, "Content-Length: " ^ Int.toString (size dap) ^ "\r\n\r\n" ^ dap)
        val response = command "dap" input [bin ^ "/rune-repl", "--dap"]
        val () = Scenarios.success response
        val () = need (String.isSubstring "\"success\":true" (#output response), "installed debug adapter did not initialize")
        val () = Scenarios.success (command "kernel" "" [bin ^ "/rune-kernel", "--install", "--prefix", work ^ "/jupyter"])
        val spec = work ^ "/jupyter/share/jupyter/kernels/rune/kernel.json"
        val () = need (exists spec, "installed kernel did not write its specification")
        fun paths (Json.String path) = if String.isPrefix "/" path then [path] else []
          | paths (Json.Array values) = List.concat (List.map paths values)
          | paths (Json.Object fields) = List.concat (List.map (paths o #2) fields)
          | paths _ = []
        val locations = paths (Json.decode (read spec))
        val () = need (length locations = 4, "kernel specification must name four installed resources")
        val () = List.app (fn path => need (String.isPrefix (stage ^ "/") (OS.Path.mkCanonical path) andalso exists path,
                                    "kernel names a missing or external resource: " ^ path)) locations
        val () = Scenarios.success (install true)
        val () = need (null (files stage), "uninstall left staged files")
    in say ("PASS install/" ^ name ^ "\n") end
end
