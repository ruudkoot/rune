(* Hex: bytes and hexadecimal.

   Implements: HEX *)
structure Hex :> HEX =
struct
  val digits = "0123456789abcdef"

  fun fromBytes s =
    String.translate (fn c => let val b = Char.ord c
                              in String.implode [String.sub (digits, b div 16), String.sub (digits, b mod 16)] end) s

  fun value c =
    if Char.isDigit c then SOME (Char.ord c - Char.ord #"0")
    else if c >= #"a" andalso c <= #"f" then SOME (Char.ord c - Char.ord #"a" + 10)
    else if c >= #"A" andalso c <= #"F" then SOME (Char.ord c - Char.ord #"A" + 10)
    else NONE

  fun toBytes h =
    if String.size h mod 2 <> 0 then NONE
    else
      let
        fun go (i, acc) =
          if i >= String.size h then SOME (String.implode (rev acc))
          else
            case (value (String.sub (h, i)), value (String.sub (h, i + 1))) of
              (SOME a, SOME b) => go (i + 2, Char.chr (16 * a + b) :: acc)
            | _ => NONE
      in
        go (0, [])
      end
end
