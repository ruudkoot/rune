(* The VMs of other machines on the runner (docs/plans/unit-testing.md, M13;
   make test-portability): what tests/run-portability.sh did, and the rest
   of that target.

   tests/lang on each VM is ways of tests/runner/lang.sml (`lang/port-*`):
   a 32-bit x86 (bin/runevm-stack32, bin/runevm32), a big-endian PowerPC
   (bin/runevm-stack-ppc64, bin/runevm-ppc64) and an aarch64
   (bin/runevm-aarch64) under qemu, each but the aarch64 also with a cycle
   of incremental marking always under way. Here, for each VM: the
   bytecode files and options it must refuse (tests/runtime/run-vm-tests.sh,
   which the Windows runner shares); the counts of --count, the same to the
   byte on every VM and on this machine (`portability/count/*`); an image
   written by each VM and read by every other (`portability/image/*`); the
   JIT's checks on the aarch64 (`port-jit/*`); and the Basis Library suite
   in the matrix's configuration `portability`, a job of run-matrix.sh. *)
structure Portability =
struct
  open Sh

  (* the VMs of each bytecode: this machine's, and the others' *)
  val families =
    [("stack", "bin/rune-stack", "bin/runevm-stack", ["bin/runevm-stack32", "bin/runevm-stack-ppc64"], "runtime/stack/opcodes.def"),
     ("register", "bin/rune", "bin/runevm", ["bin/runevm32", "bin/runevm-ppc64", "bin/runevm-aarch64"], "runtime/register/regs.def")]

  (* a few programs that allocate in different ways *)
  val counted = ["exp.arith_ops", "basis.list_ops", "basis.string_ops", "rt.gc_pressure", "mono.word8array"]

  fun fail s = say ("FAIL " ^ s ^ "\n")

  (* the counts of one program: compiled once, counted on this machine and
     on each VM *)
  fun countOne (family, name) =
    case List.find (fn (f, _, _, _, _) => f = family) families of
      NONE => fail ("count: no family " ^ family)
    | SOME (_, rune, native, vms, _) =>
        let
          val dir = run ^ "/portability/count-" ^ family
          val () = mkdirs dir
          val rbc = dir ^ "/" ^ name ^ ".rbc"
          fun counts vm =
            let val err = dir ^ "/" ^ name ^ "." ^ OS.Path.file vm ^ ".err"
            in ignore (exec {cmd = [vm, "--count", rbc], dir = NONE, stdin = "", stdout = "", stderr = err, timeout = 600});
               countOf err
            end
        in
          if not (exists ("tests/lang/" ^ name ^ ".sml")) then ()
          else if exec {cmd = [rune, "tests/lang/" ^ name ^ ".sml", "-o", rbc], dir = NONE, stdin = "", stdout = "", stderr = "",
                        timeout = 600} <> 0 then ()
          else
            let val want = counts native
            in
              List.app (fn vm => let val got = counts vm
                                 in if got = want then ()
                                    else fail ("count." ^ name ^ " on " ^ OS.Path.file vm ^ ": " ^ got ^ ", where this machine says " ^ want)
                                 end)
                       vms
            end
        end

  (* an image of each VM, read by every other: a difference of width or of
     the order of bytes shows whichever way round it is *)
  val crossSource = String.concatWith "\n"
    ["fun count (0, acc) = acc | count (n, acc) = count (n - 1, n :: acc)",
     "val live = count (3000, [])",
     "val text = String.concat (List.map Int.toString (List.take (live, 50)))",
     "val r = 3.14159265358979",
     "fun answer () =",
     "  Int.toString (List.foldl (op +) 0 live) ^ \" \" ^ Int.toString (String.size text)",
     "  ^ \" \" ^ Real.fmt (StringCvt.FIX (SOME 8)) r ^ \" \" ^ Int.toString (List.length (Runtime.trace ()))",
     "val () =",
     "  case Runtime.save \"cross.img\" of",
     "    Runtime.Saved => print (answer () ^ \"\\n\")",
     "  | Runtime.Restored => print (answer () ^ \"\\n\")", ""]

  fun imageCross family =
    case List.find (fn (f, _, _, _, _) => f = family) families of
      NONE => fail ("image: no family " ^ family)
    | SOME (_, rune, native, vms, _) =>
        let
          val dir = run ^ "/portability/image-" ^ family
          val () = (rmTree dir; mkdirs dir)
          val () = write (dir ^ "/cross.sml", crossSource)
          val all = native :: vms
          fun output f = String.concatWith "\n" (lines (read f))
        in
          if exec {cmd = [rune, dir ^ "/cross.sml", "-o", dir ^ "/cross.rbc"], dir = NONE, stdin = "", stdout = "", stderr = "",
                   timeout = 600} <> 0
          then fail ("image: cross.sml does not compile")
          else
            List.app (fn writer =>
                        List.app (fn reader =>
                                    if writer = reader then ()
                                    else
                                      let
                                        val () = (OS.FileSys.remove (dir ^ "/cross.img") handle OS.SysErr _ => ())
                                        val _ = exec {cmd = [writer, "cross.rbc"], dir = SOME dir, stdin = "", stdout = dir ^ "/want",
                                                      stderr = dir ^ "/want", timeout = 600}
                                      in
                                        if not (exists (dir ^ "/cross.img")) then
                                          fail ("image: " ^ OS.Path.file writer ^ " wrote none: " ^ output (dir ^ "/want"))
                                        else
                                          (ignore (exec {cmd = [reader, "--restore", "cross.img"], dir = SOME dir, stdin = "",
                                                         stdout = dir ^ "/got", stderr = dir ^ "/got", timeout = 600});
                                           if output (dir ^ "/got") = output (dir ^ "/want") then ()
                                           else fail ("image: " ^ OS.Path.file writer ^ " -> " ^ OS.Path.file reader ^ ": "
                                                      ^ output (dir ^ "/got") ^ ", where it was saved as " ^ output (dir ^ "/want")))
                                      end)
                                 all)
                     all
        end

  fun command args =
    case args of
      ["port-count", family, name] => SOME (fn () => countOne (family, name))
    | ["port-image", family] => SOME (fn () => imageCross family)
    | _ => NONE

  fun job (path, args, memory) =
    Test.it path
      {program = "/bin/sh",
       args = ["sh", "-c", "exec \"$RUNE_TEST_ROOT\"/bin/rune-test " ^ String.concatWith " " (List.map quote args)],
       env = NONE, dir = SOME ".", stdin = NONE, timeout = Time.fromSeconds 3600, cap = 0, cpus = 1, memory = memory,
       pools = [], exclusive = false, after = [], judge = failLines} : Run.command Test.tree

  fun script (path, text, cpus, memory, pools) =
    Test.it path
      {program = "/bin/sh", args = ["sh", "-c", text], env = NONE, dir = SOME ".", stdin = NONE,
       timeout = Time.fromSeconds 7200, cap = 0, cpus = cpus, memory = memory, pools = pools, exclusive = false, after = [],
       judge = Run.exitZero} : Run.command Test.tree

  (* a VM under qemu needs qemu, registered for its machine *)
  fun needs vm t = if String.isSubstring "ppc64" vm orelse String.isSubstring "aarch64" vm then Test.requires ["qemu"] t else t

  val tree =
    Test.tag "nightly" (Test.tag "test-portability" (Test.tag "portability" (Test.tag "vm"
      (Test.describe ""
         [Test.describe "portability"
            (List.concat (List.map (fn (family, _, _, vms, def) =>
                                      List.map (fn vm => needs vm (script ("vm/" ^ OS.Path.file vm,
                                                                           "exec sh tests/runtime/run-vm-tests.sh --vm " ^ vm ^ " --out \"$RUNE_TEST_RUN\"/portability/vm-"
                                                                           ^ OS.Path.file vm ^ " --def " ^ def, 1, 100, [])))
                                               vms
                                      @ List.map (fn n => Test.requires ["qemu"] (job ("count/" ^ family ^ "/" ^ n, ["port-count", family, n], 300)))
                                                 counted
                                      @ [Test.requires ["qemu"] (job ("image/" ^ family, ["port-image", family], 300))])
                                   families)
             @ [Test.requires ["qemu"] (script ("matrix", "RUNE=\"$RUNE_TEST_ROOT\"/bin/rune-stack RUNE_MATRIX_TIMEOUT=" ^ env ("PORT_TIMEOUT", "900")
                                                         ^ " exec sh tests/basis/run-matrix.sh -j \"$RUNE_TEST_CPUS\" --configs portability",
                                                         Int.max (1, Runtime.processors () div 2), 2000, ["matrix"]))]),
          Test.requires ["qemu"] (Oracles.jitTree ("bin/runevm-aarch64", "port-jit"))]))))
end
