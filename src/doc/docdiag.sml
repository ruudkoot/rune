(* The diagnostics of the documentation generator. The compiler stops at its
   first error; a documentation run reports everything it finds, in the order
   of the sources, and fails at the end if there was an error. *)
structure DocDiag =
struct
  datatype severity = Error | Warning

  val all : (Source.span * severity * string) list ref = ref []

  fun error (sp : Source.span, msg : string) : unit = all := (sp, Error, msg) :: !all
  fun warn (sp : Source.span, msg : string) : unit = all := (sp, Warning, msg) :: !all

  fun reset () : unit = all := []

  fun earlier ((a : Source.span, _, _), (b : Source.span, _, _)) =
    case String.compare (#file a, #file b) of
      LESS => true
    | GREATER => false
    | EQUAL => #start a < #start b

  (* a stable insertion sort: there are few diagnostics *)
  fun sorted ds =
    let
      fun insert (d, []) = [d]
        | insert (d, d' :: rest) = if earlier (d, d') then d :: d' :: rest else d' :: insert (d, rest)
    in
      List.foldl (fn (d, acc) => insert (d, acc)) [] (List.rev ds)
    end

  fun format (sp, severity, msg) =
    Source.describe sp ^ (case severity of Error => ": error: " | Warning => ": warning: ") ^ msg

  (* The diagnostics as lines, in source order; those found first come first
     among equals. *)
  fun lines () : string list = List.map format (sorted (!all))

  fun numErrors () : int = List.length (List.filter (fn (_, s, _) => s = Error) (!all))
end
