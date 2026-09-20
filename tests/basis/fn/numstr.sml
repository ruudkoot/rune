(* Natural numbers as digit strings, for the tests of the integer and word
   structures (fn/integer_fn.sml, fn/word_fn.sml, ...).

   The expected texts of toString, fmt, fromString and scan must not come from
   the library under test, and the numbers involved (2^(precision - 1),
   2^wordSize - 1, 2^200) do not fit the default int of every system. So they
   are worked out here on digit lists, with int arithmetic on single digits
   only. *)
structure NumStr =
struct
  (* A natural number: its digits in a radix from 2 to 16, least significant
     digit first, without leading zeros; zero is []. *)
  type num = int list

  fun double (radix : int) (ds : num) : num =
    let
      fun go ([], c) = if c = 0 then [] else [c]
        | go (d :: r, c) = let val x = 2 * d + c in (x mod radix) :: go (r, x div radix) end
    in
      go (ds, 0)
    end

  fun succ (radix : int) ([] : num) : num = [1]
    | succ radix (d :: r) = if d + 1 < radix then (d + 1) :: r else 0 :: succ radix r

  (* pred radix ds, for ds > 0. *)
  fun pred (radix : int) ([] : num) : num = raise Domain
    | pred radix [1] = []
    | pred radix (d :: r) = if d > 0 then (d - 1) :: r else (radix - 1) :: pred radix r

  (* fromBits radix bits: the number with the binary digits bits, most
     significant first. *)
  fun fromBits (radix : int) (bits : bool list) : num =
    List.foldl (fn (b, ds) => let val d2 = double radix ds in if b then succ radix d2 else d2 end) [] bits

  (* pow2 radix k = 2^k. *)
  fun pow2 (radix : int) (k : int) : num =
    if k <= 0 then [1] else double radix (pow2 radix (k - 1))

  (* The digits 10 to 15 are A to F, as fmt and toString produce them. *)
  fun toString ([] : num) : string = "0"
    | toString ds = String.implode (List.rev (List.map (fn d => String.sub ("0123456789ABCDEF", d)) ds))

  fun lower (s : string) : string = String.map Char.toLower s

  (* 2^k and 2^k - 1 as text. *)
  fun pow2String (radix : int) (k : int) : string = toString (pow2 radix k)
  fun pow2Minus1String (radix : int) (k : int) : string = toString (pred radix (pow2 radix k))
end
