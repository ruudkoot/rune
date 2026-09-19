(* signature OS, transcribed from https://smlfamily.github.io/Basis/os.html

   The signatures of the substructures are those of tests/basis/spec-sigs:
   OS_FILE_SYS.sml, OS_IO.sml, OS_PATH.sml and OS_PROCESS.sml, which have to
   be loaded first. The page declares `structure OS :> OS`; the checks of
   tests/basis/os.process_os_sig.sml match OS both ways. *)
signature SPEC_OS =
sig
  structure FileSys : SPEC_OS_FILE_SYS
  structure IO : SPEC_OS_IO
  structure Path : SPEC_OS_PATH
  structure Process : SPEC_OS_PROCESS

  eqtype syserror

  exception SysErr of string * syserror option

  val errorMsg : syserror -> string
  val errorName : syserror -> string
  val syserror : string -> syserror option
end
