(* OS: SysErr and OS.Process *)
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
end
