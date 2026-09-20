(* IntN: integers of `precision` bits, kept in an int of the VM (64 bits).
   Every operation works on the int and raises Overflow when the result is
   outside the range of the precision. One file per instance (int8.sml,
   int16.sml, int32.sml); Int64 is Int itself. *)
functor RuneIntNFn (val precision : int) :> INTEGER =
struct
  type int = Int.int

  local
    fun pow2 k = if k = 0 then 1 else Int.* (2, pow2 (Int.- (k, 1)))
  in
    val largest = Int.- (pow2 (Int.- (precision, 1)), 1)
    val smallest = Int.- (Int.~ largest, 1)
  end
  fun check i = if Int.< (i, smallest) orelse Int.> (i, largest) then raise Overflow else i

  val precision = SOME precision
  val minInt = SOME smallest
  val maxInt = SOME largest

  val toLarge = Int.toLarge
  fun fromLarge i = check (Int.fromLarge i)
  fun toInt (i : int) = i
  val fromInt = check

  fun a + b = check (Int.+ (a, b))
  fun a - b = check (Int.- (a, b))
  fun a * b = check (Int.* (a, b))
  fun a div b = check (Int.div (a, b))
  val op mod = Int.mod
  fun quot (a, b) = check (Int.quot (a, b))
  val rem = Int.rem

  val compare = Int.compare
  val op < = Int.<
  val op <= = Int.<=
  val op > = Int.>
  val op >= = Int.>=

  fun ~ i = check (Int.~ i)
  fun abs i = check (Int.abs i)
  val min = Int.min
  val max = Int.max
  val sign = Int.sign
  val sameSign = Int.sameSign

  val fmt = Int.fmt
  val toString = Int.toString
  (* Int.scan raises Overflow beyond 64 bits; so does a value beyond the
     precision ("Overflow is raised if the value ... is too large") *)
  fun scan radix getc src =
    case Int.scan radix getc src of
      SOME (i, rest) => SOME (check i, rest)
    | NONE => NONE
  fun fromString s = StringCvt.scanString (scan StringCvt.DEC) s
end
