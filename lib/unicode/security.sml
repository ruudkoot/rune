(* UTS #39 (docs/plans/utf8.md, D13 and M5), over the tables of
   lib/unicode/security_data.sml: Identifier_Type by ranges, a mask of
   types each; the augmented script sets by ranges, an index into the
   sets each, a set being the indexes of its scripts in order; the
   confusables as three vectors, the sources in order, where the prototype
   of each begins in the third, and that of all prototypes one after
   another. *)

(* Implements: UNICODE_SECURITY *)
structure UnicodeSecurity :> UNICODE_SECURITY =
struct
  structure D = UnicodeSecurityData

  val version = D.version

  datatype status = Allowed | Restricted

  datatype identifierType =
      Recommended | Inclusion | LimitedUse | Technical | UncommonUse | Obsolete | Exclusion
    | NotXID | NotNFKC | DefaultIgnorable | Deprecated | NotCharacter

  datatype restriction =
      ASCIIOnly | SingleScript | HighlyRestrictive | ModeratelyRestrictive | MinimallyRestrictive | Unrestricted

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

  (* ---- types and status *)

  (* the types in the order of their bits in a mask *)
  val allTypes = [Recommended, Inclusion, LimitedUse, Technical, UncommonUse, Obsolete, Exclusion,
                  NotXID, NotNFKC, DefaultIgnorable, Deprecated, NotCharacter]

  fun mask c = Vector.sub (D.typeMasks (), lookup (D.types ()) c)

  fun types c =
    let
      fun go ([], _, acc) = rev acc
        | go (t :: ts, m, acc) = go (ts, m div 2, if m mod 2 = 1 then t :: acc else acc)
    in
      go (allTypes, mask c, [])
    end

  (* Allowed is Recommended or Inclusion, the two lowest bits *)
  fun status c = if mask c < 4 then Allowed else Restricted

  (* ---- scripts *)

  (* the script sets, each the indexes of its scripts in order; the first
     stands for every script *)
  val sets : unit -> int list vector =
    D.once (fn () =>
      let
        val v = D.scriptSets ()
        fun take (i, 0, acc) = (rev acc, i)
          | take (i, k, acc) = take (i + 1, k - 1, Vector.sub (v, i) :: acc)
        fun go (i, acc) =
          if i >= Vector.length v then Vector.fromList (rev acc)
          else
            let val (set, next) = take (i + 1, Vector.sub (v, i), [])
            in go (next, set :: acc) end
      in
        go (0, [])
      end)

  (* the index of the augmented script set of c in sets; 0 for every script *)
  fun setOf c = lookup (D.scripts ()) c

  fun name i = String.substring (D.scriptNames, 4 * i, 4)

  fun scripts c =
    case setOf c of
      0 => NONE
    | k => SOME (map name (Vector.sub (sets (), k)))

  (* the scripts two ordered sets share *)
  fun intersect (a as x :: xs, b as y :: ys) =
        if x < y then intersect (xs, b) else if y < x then intersect (a, ys) else x :: intersect (xs, ys)
    | intersect _ = []

  (* the distinct sets of the code points of s that are not every script,
     each once: UTS #39's set of script sets *)
  fun soss s =
    Utf8.foldl (fn (c, acc) =>
                  case setOf c of
                    0 => acc
                  | k => if List.exists (fn j => j = k) acc then acc else k :: acc) [] s

  (* the resolved script set of the sets ks, NONE for every script *)
  fun resolve [] = NONE
    | resolve (k :: ks) = SOME (List.foldl (fn (j, acc) => intersect (Vector.sub (sets (), j), acc)) (Vector.sub (sets (), k)) ks)

  fun resolvedScripts s = Option.map (map name) (resolve (soss s))

  fun isSingleScript s =
    case resolve (soss s) of
      NONE => true
    | SOME r => not (null r)

  (* the index of the script named n *)
  fun index n =
    let
      fun go i = if String.substring (D.scriptNames, 4 * i, 4) = n then i else go (i + 1)
    in
      go 0
    end

  (* the scripts that restriction asks for: Latin, those that cover a
     Highly Restrictive string with it, and the Recommended scripts of a
     Moderately Restrictive one *)
  val named : unit -> {latin : int, covers : int list, moderate : int list} =
    D.once (fn () =>
      {latin = index "Latn", covers = [index "Kore", index "Hanb", index "Jpan"],
       moderate = List.filter (fn i => i <> index "Cyrl" andalso i <> index "Grek") D.recommended})

  fun member (i, l) = List.exists (fn j => j = i) l

  fun restriction s =
    if Utf8.foldl (fn (c, bad) => bad orelse status c = Restricted) false s then Unrestricted
    else if CharVector.all (fn c => Char.ord c < 0x80) s then ASCIIOnly
    else
      let
        val {latin, covers, moderate} = named ()
        val ks = soss s
        fun has i k = member (i, Vector.sub (sets (), k))
        (* the sets without Latin *)
        val rest = List.filter (fn k => not (has latin k)) ks
        fun covered i = List.all (has i) rest
      in
        case resolve ks of
          SOME [] =>
            if List.exists covered covers then HighlyRestrictive
            else
              (case resolve rest of
                 SOME r => if List.exists (fn i => member (i, moderate)) r then ModeratelyRestrictive
                           else MinimallyRestrictive
               | NONE => MinimallyRestrictive)
        | _ => SingleScript
      end

  (* ---- confusables *)

  (* the sources in order, where the prototype of each begins in protos,
     and the prototypes one after another; the last start is the end *)
  val confusables : unit -> int vector * int vector * int vector =
    D.once (fn () =>
      let
        val v = D.confusables ()
        fun go (i, prev, srcs, starts, protos, at) =
          if i >= Vector.length v then
            (Vector.fromList (rev srcs), Vector.fromList (rev (at :: starts)), Vector.fromList (rev protos))
          else
            let
              val c = prev + Vector.sub (v, i)
              val n = Vector.sub (v, i + 1)
              fun copy (k, acc) = if k = n then acc else copy (k + 1, Vector.sub (v, i + 2 + k) :: acc)
            in
              go (i + 2 + n, c, c :: srcs, at :: starts, copy (0, protos), at + n)
            end
      in
        go (0, 0, [], [], [], 0)
      end)

  (* the prototype of c, consed onto acc in reverse *)
  fun prototype (c, acc) =
    let
      val (srcs, starts, protos) = confusables ()
      fun copy (k, stop, acc) = if k = stop then acc else copy (k + 1, stop, Vector.sub (protos, k) :: acc)
      fun go (lo, hi) =
        if lo >= hi then c :: acc
        else
          let val m = (lo + hi) div 2
          in
            if c < Vector.sub (srcs, m) then go (lo, m)
            else if c > Vector.sub (srcs, m) then go (m + 1, hi)
            else copy (Vector.sub (starts, m), Vector.sub (starts, m + 1), acc)
          end
    in
      go (0, Vector.length srcs)
    end

  fun skeleton s =
    let
      val d = List.filter (fn c => not (Identifier.isDefaultIgnorable c)) (Normalize.nfdList (Utf8.explode s))
    in
      Utf8.implode (Normalize.nfdList (rev (List.foldl prototype [] d)))
    end

  fun isConfusable (s, t) = skeleton s = skeleton t
end
