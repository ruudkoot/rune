(* Display widths (docs/plans/repl.md, D9): a binary search over the
   ranges of lib/unicode/width_data.sml. The compiler shares this file and
   its tables (sources.txt), for the columns of a diagnostic's excerpt. *)

(* Implements: DISPLAY_WIDTH *)
structure DisplayWidth :> DISPLAY_WIDTH =
struct
  val version = UnicodeWidthData.version

  (* whether c is in one of the ranges of v, pairs lo, hi in order *)
  fun within (v : int vector) c =
    let
      fun go (lo, hi) =
        if lo >= hi then false
        else
          let val m = (lo + hi) div 2
          in
            if c < Vector.sub (v, 2 * m) then go (lo, m)
            else if c > Vector.sub (v, 2 * m + 1) then go (m + 1, hi)
            else true
          end
    in
      go (0, Vector.length v div 2)
    end

  fun isControl c = within (UnicodeWidthData.control ()) c

  fun codePoint c =
    if c < 0x20 then 0
    else if c < 0x7F then 1
    else if isControl c orelse within (UnicodeWidthData.zero ()) c then 0
    else if within (UnicodeWidthData.wide ()) c then 2
    else 1

  fun columns s = Utf8.foldl (fn (c, n) => n + codePoint c) 0 s
end
