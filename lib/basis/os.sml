(* OS: SysErr, OS.Process and the I/O descriptors. *)
structure OS =
struct
  type syserror = int
  exception SysErr of string * syserror option

  structure Process =
  struct
    type status = int
    val success = 0
    val failure = 1
    fun isSuccess s = s = 0
    val exit = _prim "exit" : int -> 'a
    fun terminate s = exit s
  end

  (* The rest of OS.IO (poll and its kin) comes with the system layer; the
     type is here because PRIM_IO names it. A descriptor is the handle of the
     VM's file table. *)
  structure IO =
  struct
    datatype iodesc = FD of int
    fun hash (FD fd) = Word.fromInt fd
    fun compare (FD a, FD b) = Int.compare (a, b)
  end
end
