(* rhc's interpreter against its VM, on the run programs of tests/hs/lang
   (the haskell98 roadmap's M15 done-when and G1; docs/testing.md, rhc's
   interpreter against its VM): each program through rhc to Core, run on
   Core's interpreter (`bin/rhc --lint=3 FILE`, as hs/core runs `--read-core
   FILE`), and compiled through Mid to the VM (`bin/rhc --lint=2 FILE -o
   OUT`, bin/runevm OUT), each with the program's .stdin, the VM with its
   .vmargs; a program of one file interpreted as a copy named prog.hs, so
   that getProgName is prog both ways. What the VM prints
   is what the interpreter printed, and it ends as the interpreter did: a
   status of 0, or every bottom one bottom, a status other than 0. A program
   the interpreter alone can run says so on a line `-- vm: no: REASON`
   (hs/core's `; vm: no:`): one whose exception passes a suspension the
   interpreter puts back and form C leaves under evaluation (impl/progress/b.md,
   D12). One whose output is the runtime's and not Core's says so on a line
   `-- interp: no: REASON`: Core's interpreter writes a file at once, with no
   buffer, so a program that shows a handle's buffering is the VM's alone
   (lang/lib.r.io.buffer.line_shown). A program is held while every row it tests is Planned, as the
   suite's own jobs are (HsConformance). *)
structure HsInterpVm =
struct
  open Sh

  val rhc = "bin/rhc"
  (* the reason the text gives on a line `MARK REASON`, if it has one *)
  fun marked mark src =
    let val text = if exists (src ^ "/Main.hs") then read (src ^ "/Main.hs") else read src
    in
      case List.find (String.isPrefix mark) (String.fields (fn c => c = #"\n") text) of
        SOME l => SOME (String.extract (l, size mark, NONE))
      | NONE => NONE
    end
  (* the reason a program is the interpreter's alone, or the VM's alone *)
  val interpreterOnly = marked "-- vm: no: "
  val vmOnly = marked "-- interp: no: "
  fun stdinOf (p : Lang.program) = if exists (#base p ^ ".stdin") then fromRoot (#base p ^ ".stdin") else ""
  (* the VM's options, the program's .vmargs (Lang's header) *)
  fun vmargsOf (p : Lang.program) =
    if exists (#base p ^ ".vmargs") then String.tokens Char.isSpace (read (#base p ^ ".vmargs")) else []

  fun copyBytes (a, b) =
    let val i = BinIO.openIn a
        val v = BinIO.inputAll i before BinIO.closeIn i
        val out = BinIO.openOut b
    in BinIO.output (out, v); BinIO.closeOut out end

  fun one (p : Lang.program) () =
    case (interpreterOnly (fromRoot (#src p)), vmOnly (fromRoot (#src p))) of
      (SOME why, _) => say ("PASS " ^ #name p ^ ": the interpreter's alone: " ^ why ^ "\n")
    | (NONE, SOME why) => say ("PASS " ^ #name p ^ ": the VM's alone: " ^ why ^ "\n")
    | (NONE, NONE) =>
        let
          val work = run ^ "/hs-interp-vm/" ^ #name p
          val () = (rmTree work; mkdirs work)
          fun f x = work ^ "/" ^ x
          val src = fromRoot (#src p)
          (* a program of one file is interpreted as prog.hs, a copy, so that
             its getProgName, the source's base name on the interpreter, is
             prog, as the VM's prog.rbc gives (the lead's ruling 33) *)
          val isrc =
            if String.isPrefix (#base p ^ "/") (#src p) then src
            else let val copy = f ("prog" ^ (if String.isSuffix ".lhs" src then ".lhs" else ".hs"))
                 in write (copy, read src); copy end
          val ic = exec {cmd = [fromRoot rhc, "--lint=3", isrc], dir = SOME work, stdin = stdinOf p, stdout = f "interp.out",
                         stderr = f "interp.err", timeout = 600}
          (* compiled once (the lead's ruling 52): the bytecode
             hs/compile/register/NAME made in this run, the same program,
             target and options (bin/rhc at RUNE_LINT=2, no .cargs), where
             there is one; else compiled here *)
          val shared = run ^ "/hs/c/register/" ^ #name p ^ "/prog.rbc"
          val cc =
            if not (exists (#base p ^ ".cargs")) andalso exists shared then (copyBytes (shared, f "prog.rbc"); 0)
            else exec {cmd = [fromRoot rhc, "--lint=2", src, "-o", f "prog.rbc"], dir = SOME work, stdin = "", stdout = f "c.err",
                       stderr = f "c.err", timeout = 600}
        in
          if cc <> 0 then say ("FAIL " ^ #name p ^ ": rhc does not compile it for the VM: " ^ firstNonEmpty (f "c.err") ^ "\n")
          else
            let
              val vc = exec {cmd = [fromRoot "bin/runevm"] @ vmargsOf p @ [f "prog.rbc"], dir = SOME work, stdin = stdinOf p, stdout = f "vm.out",
                             stderr = f "vm.err", timeout = 600}
              fun ends c = if c = 0 then "a value" else "a bottom"
            in
              if read (f "interp.out") <> read (f "vm.out") then
                say ("FAIL " ^ #name p ^ ": the VM printed otherwise than the interpreter (" ^ work ^ "/interp.out, vm.out)\n")
              else if (ic = 0) <> (vc = 0) then
                say ("FAIL " ^ #name p ^ ": the interpreter ended in " ^ ends ic ^ ", the VM in " ^ ends vc ^ "\n")
              else rmTree work
            end
        end

  fun programs () = Lang.programsOf ("tests/hs/lang", [".hs", ".lhs"], ["Main.hs", "Main.lhs"])
  fun command args =
    case args of
      ["hs-interp-vm", name] =>
        (case List.find (fn (p : Lang.program) => #name p = name) (programs ()) of
           SOME p => SOME (one p)
         | NONE => SOME (fn () => say ("FAIL hs-interp-vm: no program " ^ name ^ " in tests/hs/lang\n")))
    | _ => NONE

  val covers = ["covers:tests/runner/hsinterp.sml", "covers:tests/hs/lang/*", "covers:lib/language/haskell/*", "covers:src/rhc/*"]
  fun tree () =
    List.foldl (fn (c, t) => Test.tag c t)
      (* nightly, every program, and in make check the sample of ruling 47
         (HsLang.sampled, never a program of lang-nightly.txt): each
         program's three ways run in make check (the roadmap's D56, the lead's
         rulings 45 and 47) *)
      (Test.tag "hs" (Test.describe "hs/interp-vm"
         (List.map (fn (p : Lang.program) =>
                      let val t = HsLang.tagAll (HsLang.sampleTags (#name p))
                                    (Test.requires ["rhc"] (Oracles.jobIn ("", #name p, ["hs-interp-vm", #name p],
                                                                           ["hs/compile/register/" ^ #name p], 1, 600, 1800)))
                      in case HsConformance.pending p of SOME why => Test.pending why t | NONE => t end)
                   (programs ()))))
      covers
end
