(* A family of Core's primitives (CORE_PRIM_FAMILY): what the IO library
   asks of handles and of the system's errors beyond CorePrim's own (the
   haskell98 roadmap's M18; L's asks of 2026-11-10): the position of a
   file, the error of the last failure of a file's and of the system's,
   the size of a file, whether input waits. The interpreter's are over
   CoreFiles, the VM's over Mid's primitives of the same work. *)
structure CorePrimIo =
struct
  structure F = CorePrimFamily

  fun int v = case v of F.Int i => i | _ => raise Fail "CorePrimIo: an Int is wanted"
  fun str v = case v of F.Str s => s | _ => raise Fail "CorePrimIo: a Str is wanted"

  (* the name the system gives an error's number, "ENOENT", as Mid's
     sys_error_name: OS.errorName's, which writes it in lower case with no
     E, written back *)
  fun errorName n =
    let val e = OS.errorName (Posix.Error.fromWord (SysWord.fromInt n))
    in
      if e = "toobig" then "E2BIG"
      else if String.isPrefix "error" e andalso CharVector.all Char.isDigit (String.extract (e, 5, NONE)) then ""
      else "E" ^ String.map Char.toUpper e
    end

  val prims : F.prim list =
    [{name = "h_tell", ty = "(-> !Int World (utuple World !Int))",
      doc = "the position of a file in bytes, ~1 where it has none (a pipe, a terminal); h_errno says why",
      run = fn [h] => F.Int (CoreFiles.tell (int h)) | _ => raise Fail "h_tell", mid = "gioTell"},
     {name = "h_seek", ty = "(-> !Int !Int World (utuple World !Int))",
      doc = "moves a file to a position in bytes from its start: 0, or ~1, h_errno saying why",
      run = fn [h, p] => F.Int (CoreFiles.seek (int h, int p)) | _ => raise Fail "h_seek", mid = "gioSeek"},
     {name = "h_errno", ty = "(-> World (utuple World !Int))",
      doc = "the system's number of the error of the last h_open, h_write, h_tell, h_seek, h_flush_ok or h_close_ok that failed",
      run = fn _ => F.Int (!CoreFiles.lastErrno), mid = "gioErrno"},
     {name = "h_ready", ty = "(-> !Int !Int World (utuple World !Bool))",
      doc = "whether input waits on a handle, or comes within so many milliseconds (no limit below 0)",
      run = fn [h, ms] => F.Bool (CoreFiles.ready (int h, int ms)) | _ => raise Fail "h_ready", mid = "gioReady"},
     {name = "os_file_size", ty = "(-> !Str World (utuple World !Int))",
      doc = "the size of a file in bytes, ~1 where it has none, sys_errno saying why",
      run = fn [p] => (F.Int (Position.toInt (OS.FileSys.fileSize (str p)))
                       handle e as OS.SysErr _ => (CoreFiles.sysErrno := CoreFiles.errnoOf e; F.Int ~1))
             | _ => raise Fail "os_file_size",
      mid = "gioFileSize"},
     {name = "h_flush_ok", ty = "(-> !Int World (utuple World !Bool))",
      doc = "writes what a handle holds: False where the system's flush fails (a full device), h_errno saying why",
      run = fn [h] => F.Bool (CoreFiles.flush (int h)) | _ => raise Fail "h_flush_ok", mid = "gioFlush"},
     {name = "h_close_ok", ty = "(-> !Int World (utuple World !Bool))",
      doc = "closes a handle (nothing for 0 to 2): False where the system's close fails, h_errno saying why; closed either way",
      run = fn [h] => F.Bool (CoreFiles.closeOk (int h)) | _ => raise Fail "h_close_ok", mid = "gioClose"},
     {name = "sys_errno", ty = "(-> World (utuple World !Int))",
      doc = "the system's number of the error of the last call of the system's that failed (os_file_size's)",
      run = fn _ => F.Int (!CoreFiles.sysErrno), mid = "gioSysErrno"},
     {name = "sys_error_name", ty = "(-> !Int Str)", doc = "the name of an error's number, \"ENOENT\"; \"\" where it has none",
      run = fn [n] => F.Str (errorName (int n)) | _ => raise Fail "sys_error_name", mid = "gioErrorName"},
     {name = "sys_error_message", ty = "(-> !Int Str)", doc = "the system's text of an error's number",
      run = fn [n] => F.Str (OS.errorMsg (Posix.Error.fromWord (SysWord.fromInt (int n)))) | _ => raise Fail "sys_error_message",
      mid = "gioErrorMessage"}]

  val midText = String.concatWith "\n"
    ["(funs",
     "  (fn gioTell ((vitH : int)) : int \"h_tell\" (return (prim file_tell vitH : int -> int)))",
     "  (fn gioSeek ((visH : int) (visP : int)) : int \"h_seek\" (return (prim file_seek visH visP : (int * int) -> int)))",
     "  (fn gioErrno ((vieU : unit)) : int \"h_errno\" (return (prim file_errno () : unit -> int)))",
     "  (fn gioReady ((vqH : int) (vqM : int)) : bool \"h_ready\"",
     "    (let (vqF : int) (prim file_descriptor vqH : int -> int)",
     "    (let (vqT : int) (prim int_mul vqM 1000 : (int * int) -> int)",
     "    (let (vqP : int * int list) (tuple vqF (con0 0 : int list))",
     "    (let (vqL : int list) (con 1 vqP : int list)",
     "    (let (vqE : int * int list) (tuple 1 (con0 0 : int list))",
     "    (let (vqK : int list) (con 1 vqE : int list)",
     "    (let (vqR : int list) (prim os_poll vqL vqK vqT : (int list * int list * int) -> int list)",
     "    (let (vqG : int) (tag vqR)",
     "    (let (vqN : bool) (prim poly_eq vqG 0 : (int * int) -> bool)",
     "    (if vqN (return (con0 0 : bool))",
     "      (let (vqC : int * int list) (decon 1 vqR : int list)",
     "      (let (vqV : int) (select 0 vqC)",
     "      (let (vqZ : bool) (prim poly_eq vqV 0 : (int * int) -> bool)",
     "      (if vqZ (return (con0 0 : bool)) (return (con0 1 : bool)))))))))))))))))",
     "  (fn gioFileSize ((vifP : string)) : int \"os_file_size\" (return (prim os_file_size vifP : string -> int)))",
     "  (fn gioFlush ((vlfH : int)) : bool \"h_flush_ok\" (return (prim file_flush vlfH : int -> bool)))",
     "  (fn gioClose ((vlcH : int)) : bool \"h_close_ok\" (return (prim file_close vlcH : int -> bool)))",
     "  (fn gioSysErrno ((viyU : unit)) : int \"sys_errno\" (return (prim sys_errno () : unit -> int)))",
     "  (fn gioErrorName ((vinN : int)) : string \"sys_error_name\" (return (prim sys_error_name vinN : int -> string)))",
     "  (fn gioErrorMessage ((vimN : int)) : string \"sys_error_message\" (return (prim sys_error_msg vimN : int -> string))))\n"]

  val family : F.family = {name = "io", prims = prims, midText = midText}
end
