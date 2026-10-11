(* Extended grapheme clusters (docs/plans/repl.md, D9): the rules GB3 to
   GB999 of UAX #29, over the properties of lib/unicode/grapheme_data.sml.
   Between one code point and the next a break is decided from the two
   break properties and from three things carried along the cluster: the
   run of regional indicators before (GB12, GB13), whether the text before
   is an Extended_Pictographic, its Extend marks and a ZWJ (GB11), and
   whether it is an Indic linker and its extenders (GB9c, which Unicode 18
   made \p{InCB=Linker} \p{InCB=Extend}* × \p{InCB=Consonant}: no consonant
   is needed before the linker any more). *)

(* Implements: GRAPHEME *)
structure Grapheme :> GRAPHEME =
struct
  val version = UnicodeGraphemeData.version

  datatype policy = ByCluster | ByCodePoint

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

  fun pictographic c =
    c >= 0x80 andalso
    let
      val v = UnicodeGraphemeData.pictographic ()
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

  (* the values of the break property (grapheme_data.sml) *)
  val CR = 1 and LF = 2 and Control = 3 and Extend = 4 and ZWJ = 5 and RI = 6
  val Prepend = 7 and SpacingMark = 8 and L = 9 and V = 10 and T = 11
  val LV = 12 and LVT = 13
  (* and of Indic_Conjunct_Break *)
  val Linker = 1 and Consonant = 2 and Extender = 3

  (* ASCII without the tables: CR, LF, the other controls, and the rest,
     which have no property, are not pictographic and are no conjunct *)
  fun property c =
    if c < 0x80 then (if c = 13 then CR else if c = 10 then LF else if c < 0x20 orelse c = 0x7F then Control else 0)
    else lookup (UnicodeGraphemeData.breakProperty ()) c
  fun conjunct c = if c < 0x80 then 0 else lookup (UnicodeGraphemeData.conjunct ()) c

  (* the state carried along a cluster: the run of regional indicators, the
     emoji sequence (0 none, 1 a pictographic and its Extend marks, 2 those
     and a ZWJ), the conjunct (0 none, 1 a linker and its extenders) *)
  type state = {prop : int, ri : int, emoji : int, conj : int}

  fun start c =
    let val p = property c
    in
      {prop = p, ri = if p = RI then 1 else 0,
       emoji = if pictographic c then 1 else 0,
       conj = if conjunct c = Linker then 1 else 0}
    end

  fun step ({ri, emoji, conj, ...} : state) c =
    let
      val p = property c
      val k = conjunct c
    in
      {prop = p,
       ri = if p = RI then ri + 1 else 0,
       emoji = if pictographic c then 1
               else if p = Extend andalso emoji = 1 then 1
               else if p = ZWJ andalso emoji = 1 then 2
               else 0,
       conj = if k = Linker then 1
              else if k = Extender andalso conj = 1 then 1
              else 0}
    end

  fun breaks ({prop = p, ri, emoji, conj} : state) c =
    let
      val q = property c
    in
      if p = CR andalso q = LF then false                                        (* GB3 *)
      else if p = Control orelse p = CR orelse p = LF then true                  (* GB4 *)
      else if q = Control orelse q = CR orelse q = LF then true                  (* GB5 *)
      else if p = L andalso (q = L orelse q = V orelse q = LV orelse q = LVT) then false (* GB6 *)
      else if (p = LV orelse p = V) andalso (q = V orelse q = T) then false      (* GB7 *)
      else if (p = LVT orelse p = T) andalso q = T then false                    (* GB8 *)
      else if q = Extend orelse q = ZWJ then false                               (* GB9 *)
      else if q = SpacingMark then false                                         (* GB9a *)
      else if p = Prepend then false                                             (* GB9b *)
      else if conj = 1 andalso conjunct c = Consonant then false                 (* GB9c *)
      else if emoji = 2 andalso pictographic c then false                        (* GB11 *)
      else if p = RI andalso q = RI then ri mod 2 = 0                            (* GB12, GB13 *)
      else true                                                                  (* GB999 *)
    end

  fun next (s, i) =
    let
      val n = String.size s
      val (c, k) = Utf8.next (s, i)
      fun go (j, st) =
        if j >= n then n
        else
          case Utf8.decode (s, j) of
            NONE => j
          | SOME (d, m) => if breaks st d then j else go (j + m, step st d)
    in
      case Utf8.decode (s, i) of
        NONE => i + k
      | SOME _ => go (i + k, start c)
    end

  fun foldClusters f init s =
    let
      val n = String.size s
      fun go (i, acc) =
        if i >= n then acc
        else let val j = next (s, i) in go (j, f (i, j, acc)) end
    in
      go (0, init)
    end

  fun clusters s = rev (foldClusters (fn (i, j, acc) => String.substring (s, i, j - i) :: acc) [] s)
  fun count s = foldClusters (fn (_, _, n) => n + 1) 0 s

  (* a cluster's width, measured as a whole: its widest code point, and two
     for a sequence with the emoji presentation selector *)
  fun clusterWidth (s, i, j) =
    let
      fun go (k, w, vs16) =
        if k >= j then (if vs16 andalso w > 0 then 2 else w)
        else
          let val (c, m) = Utf8.next (s, k)
          in go (k + m, Int.max (w, DisplayWidth.codePoint c), vs16 orelse c = 0xFE0F) end
    in
      go (i, 0, false)
    end

  fun width ByCodePoint s = DisplayWidth.columns s
    | width ByCluster s = foldClusters (fn (i, j, n) => n + clusterWidth (s, i, j)) 0 s
end
