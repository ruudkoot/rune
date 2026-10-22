(* The native hosts support compilation and artifact I/O. *)
structure CompilerApiPlatform =
struct
  val inherited : (string * string option) list = []
  fun link (_ : string) : unit -> unit =
    raise Fail "in-process execution requires RuneVM"
  fun prepare (_ : bool) : unit = raise Fail "in-process execution requires RuneVM"
  fun current () : (string * string) list = []
end
