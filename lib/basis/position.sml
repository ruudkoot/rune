(* Position: the positions in a file and in a stream of I/O, as `lseek` and
   `ftruncate` take them and `fileSize` gives them: 64 bits, as a file
   offset of the system has, and a type of its own. It is `Int64` behind,
   but not `Int.int` nor `Int64.int`, as the specification makes it the
   same as neither and other implementations keep it apart from `Int`
   (MLton's and SML/NJ's are `Int64`, Poly/ML's `LargeInt`). A program
   converts with `fromInt`, `toInt`, `fromLarge` and `toLarge`.

   Implements: INTEGER *)
structure Position :> INTEGER = Int64

(* Integer constants at Position.int, converted from their digits where
   they are evaluated; one beyond the 64 bits raises Overflow. *)
structure RunePosition =
struct
  fun fromLit (digits : string) : Position.int =
    case IntInf.fromString digits of
      SOME i => Position.fromLarge i
    | NONE => raise Fail "RunePosition.fromLit"
end

_overload int Position via RunePosition.fromLit
