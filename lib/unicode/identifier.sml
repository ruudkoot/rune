(* Identifiers (UAX #31; docs/plans/utf8.md, D10 and M5). The profile is a
   table of two stages that a lookup reads where it stands, so that no
   table is built: the number of the block of a code point is two
   hexadecimal digits of stage1, and its value two bits of the block's
   digits in stage2 (lib/unicode/identifier_data.sml). What the profile
   leaves out of XID_Start, the default ignorables and the lookalikes are
   ranges for a binary search, built at their first use. *)

(* Implements: IDENTIFIER *)
structure Identifier :> IDENTIFIER =
struct
  structure D = UnicodeIdentifierData

  val version = D.version

  datatype exclusion = Ignorable | Lookalike of char

  (* the value of the range of v (triples lo, hi, value) that holds c, or 0 *)
  fun lookup (v : int vector) c =
    let
      fun go (lo, hi) =
        if lo >= hi then 0
        else
          let val m = (lo + hi) div 2
          in
            if c < Vector.sub (v, 3 * m) then go (lo, m)
            else if c > Vector.sub (v, 3 * m + 1) then go (m + 1, hi)
            else Vector.sub (v, 3 * m + 2)
          end
    in
      go (0, Vector.length v div 3)
    end

  (* the hexadecimal digit at i of s *)
  fun hex (s, i) =
    let val d = Char.ord (String.sub (s, i))
    in if d < 65 then d - 48 else d - 55 end

  (* the profile's value of a code point c above ASCII: 0 not XID_Continue,
     1 XID_Continue only, 2 XID_Start, 3 left out *)
  fun class c =
    if c >= D.limit then (if lookup (D.beyond ()) c = 0 then 0 else 3)
    else
      let
        val k = 2 * (c div D.block)
        val j = D.block * (16 * hex (D.stage1, k) + hex (D.stage1, k + 1)) + c mod D.block
        val d = hex (D.stage2, j div 2)
      in
        if j mod 2 = 0 then d div 4 else d mod 4
      end

  fun asciiLetter c = (c >= 0x41 andalso c <= 0x5A) orelse (c >= 0x61 andalso c <= 0x7A)
  fun asciiDigit c = c >= 0x30 andalso c <= 0x39
  fun asciiContinue c = asciiLetter c orelse asciiDigit c orelse c = 0x5F orelse c = 0x27

  fun isXIDStart c =
    if c < 0x80 then asciiLetter c
    else
      case class c of
        2 => true
      | 3 => lookup (D.startLeftOut ()) c <> 0
      | _ => false

  fun isXIDContinue c = if c < 0x80 then asciiLetter c orelse asciiDigit c orelse c = 0x5F else class c <> 0

  fun isDefaultIgnorable c = lookup (D.defaultIgnorable ()) c <> 0

  fun exclusion c =
    if c < 0x80 orelse class c <> 3 then NONE
    else
      case lookup (D.lookalikes ()) c of
        0 => SOME Ignorable
      | a => SOME (Lookalike (Char.chr a))

  fun isStart c = if c < 0x80 then asciiLetter c else class c = 2

  fun isContinue c =
    if c < 0x80 then asciiContinue c
    else
      case class c of
        1 => true
      | 2 => true
      | _ => false

  fun isAlphanumeric s =
    let
      val n = String.size s
      fun go (i, first) =
        if i >= n then not first
        else
          let val b = Char.ord (String.sub (s, i))
          in
            if b < 0x80 then (if first then asciiLetter b else asciiContinue b) andalso go (i + 1, false)
            else
              case Utf8.decode (s, i) of
                NONE => false
              | SOME (c, m) => (if first then isStart c else isContinue c) andalso go (i + m, false)
          end
    in
      go (0, true)
    end
end
