(* UTF-8 (docs/plans/repl.md, The libraries): Table 3-7 of the Unicode
   Standard, the well-formed byte sequences, read one lead byte at a time.
   The first continuation byte has a range of its own after E0, ED, F0 and
   F4, which is what rules out overlong forms, surrogates and code points
   past 0x10FFFF; a sequence that breaks off is ill-formed for the bytes it
   had so far, its maximal subpart. *)

(* Implements: UTF8 *)
structure Utf8 :> UTF8 =
struct
  val replacement = 0xFFFD

  fun isScalar c = c >= 0 andalso c <= 0x10FFFF andalso (c < 0xD800 orelse c > 0xDFFF)

  fun byte b = Char.chr b

  fun encode c =
    if not (isScalar c) then raise Chr
    else if c < 0x80 then String.str (byte c)
    else if c < 0x800 then String.implode [byte (0xC0 + c div 64), byte (0x80 + c mod 64)]
    else if c < 0x10000 then
      String.implode [byte (0xE0 + c div 4096), byte (0x80 + c div 64 mod 64),
                      byte (0x80 + c mod 64)]
    else
      String.implode [byte (0xF0 + c div 262144), byte (0x80 + c div 4096 mod 64),
                      byte (0x80 + c div 64 mod 64), byte (0x80 + c mod 64)]

  (* what may follow a lead byte: how many continuation bytes, the range of
     the first of them, and what the lead contributes to the code point *)
  fun shape b =
    if b < 0x80 then SOME (0, 0, 0, b)
    else if b >= 0xC2 andalso b <= 0xDF then SOME (1, 0x80, 0xBF, b - 0xC0)
    else if b = 0xE0 then SOME (2, 0xA0, 0xBF, 0)
    else if b = 0xED then SOME (2, 0x80, 0x9F, 0xD)
    else if b >= 0xE1 andalso b <= 0xEF then SOME (2, 0x80, 0xBF, b - 0xE0)
    else if b = 0xF0 then SOME (3, 0x90, 0xBF, 0)
    else if b >= 0xF1 andalso b <= 0xF3 then SOME (3, 0x80, 0xBF, b - 0xF0)
    else if b = 0xF4 then SOME (3, 0x80, 0x8F, 4)
    else NONE

  (* the code point at byte i and its length, or ~1 and the length of the
     maximal subpart of the ill-formed part there *)
  fun scan (s, i) =
    let
      val n = String.size s
      fun at j = Char.ord (String.sub (s, j))
    in
      case shape (at i) of
        NONE => (~1, 1)
      | SOME (0, _, _, c) => (c, 1)
      | SOME (k, lo, hi, lead) =>
          let
            fun go (j, cp) =
              if j = k then (cp, k + 1)
              else if i + 1 + j >= n then (~1, 1 + j)
              else
                let
                  val b = at (i + 1 + j)
                  val (l, h) = if j = 0 then (lo, hi) else (0x80, 0xBF)
                in
                  if b < l orelse b > h then (~1, 1 + j)
                  else go (j + 1, cp * 64 + (b - 0x80))
                end
          in
            go (0, lead)
          end
    end

  fun decode (s, i) =
    if i < 0 orelse i > String.size s then raise Subscript
    else if i = String.size s then NONE
    else case scan (s, i) of
           (~1, _) => NONE
         | r => SOME r

  fun next (s, i) =
    if i < 0 orelse i >= String.size s then raise Subscript
    else case scan (s, i) of
           (~1, k) => (replacement, k)
         | r => r

  fun foldl f init s =
    let
      val n = String.size s
      fun go (i, acc) =
        if i >= n then acc
        else let val (c, k) = next (s, i) in go (i + k, f (c, acc)) end
    in
      go (0, init)
    end

  fun isValid s =
    let
      val n = String.size s
      fun go i = i >= n orelse (case scan (s, i) of (~1, _) => false | (_, k) => go (i + k))
    in
      go 0
    end

  fun explode s = rev (foldl (op ::) [] s)
  fun implode cs = String.concat (map encode cs)
  fun size s = foldl (fn (_, n) => n + 1) 0 s
end
