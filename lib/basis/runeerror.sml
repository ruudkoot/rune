(* The errors of the system, shared by OS and by what is built on it. A
   syserror is an errno value. Its name, for OS.errorName and OS.syserror,
   is the one Posix.Error gives it, the same syserror there ("a unique name
   used for the syserror value"): the C name in lower case without its
   initial E ("noent" for ENOENT, "toobig" for E2BIG), or "error" and the
   number for an errno the system has no name for. *)
structure RuneError :>
sig
  (* abstract, as the specification has `OS.syserror`: the errno goes in and
     out through fromInt and toInt, which only the library names *)
  eqtype syserror
  exception SysErr of string * syserror option
  val errorMsg : syserror -> string
  val errorName : syserror -> string
  val syserror : string -> syserror option
  val lastError : unit -> exn
  val toInt : syserror -> int
  val fromInt : int -> syserror
end =
struct
  type syserror = int
  exception SysErr of string * syserror option
  fun toInt (e : syserror) = e
  fun fromInt (e : int) : syserror = e

  local
    val errno = _prim "sys_errno" : unit -> int
    val message = _prim "sys_error_msg" : int -> string
    val name = _prim "sys_error_name" : int -> string
    val ofName = _prim "sys_error_of_name" : string -> int
    fun isLower c = c >= #"a" andalso c <= #"z"
    fun isDigit c = c >= #"0" andalso c <= #"9"
    fun all _ [] = true
      | all p (c :: r) = p c andalso all p r
    fun lower c = if c >= #"A" andalso c <= #"Z" then chr (ord c + 32) else c
    fun upper c = if isLower c then chr (ord c - 32) else c
    fun number (n, []) = n
      | number (n, d :: r) = number (n * 10 + ord d - ord #"0", r)
  in
    fun errorMsg e = message e
    fun errorName e =
      case name e of
        "" => "error" ^ Int.toString e
      | "E2BIG" => "toobig"
      | n => implode (map lower (tl (explode n)))
    (* The inverse of errorName: "SOME e = syserror(errorName e)". *)
    fun syserror s =
      case explode s of
        #"e" :: #"r" :: #"r" :: #"o" :: #"r" :: (digits as d :: _) =>
          if d <> #"0" andalso all isDigit digits andalso length digits <= 9 then
            let val e = number (0, digits) in if name e = "" then SOME e else NONE end
          else NONE
      | chars =>
          if null chars orelse not (all isLower chars) then NONE
          else
            case (ofName (implode (#"E" :: map upper chars)), s) of
              (~1, "toobig") => (case ofName "E2BIG" of ~1 => NONE | e => SOME e)
            | (~1, _) => NONE
            | (e, _) => SOME e
    (* The last failure of the system, as an exception. *)
    fun lastError () = let val e = errno () in SysErr (message e, SOME e) end
  end
end
