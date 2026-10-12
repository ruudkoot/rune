(* Expectations: the one format of deviations and skips, and what each
   category means. *)
structure Expectations :> EXPECTATIONS =
struct
  datatype meaning = Strict | Lenient | Skip | Quarantine
  type line = {file : string, number : int, way : string, path : string, label : string option,
               category : string, reason : string}
  exception Parse of string

  val meanings =
    List.map (fn c => (c, Strict)) ["RUNE-DEV", "HOST-BUG", "WIDTH", "SPEC-AMBIGUOUS", "WINDOWS", "EMULATED", "FAILS"]
    @ List.map (fn c => (c, Lenient)) ["HOST-FLAKY", "FLAKY"]
    @ List.map (fn c => (c, Skip)) ["HOST-ABSENT", "XC1-NA", "XC2-NA", "UNTESTED", "UNSUPPORTED"]
    @ [("QUARANTINE", Quarantine)]

  fun meaning c = Option.map #2 (List.find (fn (k, _) => k = c) meanings)

  fun trim s = Substring.string (Substring.dropl Char.isSpace (Substring.dropr Char.isSpace (Substring.full s)))

  (* the date a quarantine lasts until: its reason's "until YYYY-MM-DD" *)
  fun until reason =
    let val r = trim reason
    in
      if String.isPrefix "until " r andalso size r >= 16 then
        let val d = String.substring (r, 6, 10)
        in if CharVector.all (fn c => Char.isDigit c orelse c = #"-") d then SOME d else NONE end
      else NONE
    end

  fun parse (file, text) =
    let
      fun one (number, raw) =
        let val l = trim (hd (String.fields (fn c => c = #"#") raw))
        in
          if l = "" then NONE
          else
            (* a line whose second field is a category names no way: every way *)
            case (fn fs as (_ :: c :: _) => if isSome (meaning c) then "*" :: fs else fs | fs => fs)
                   (List.map trim (String.fields (fn c => c = #"|") l)) of
              way :: target :: category :: rest =>
                let
                  val where' = file ^ ":" ^ Int.toString number
                  (* PATH::LABEL *)
                  val (path, label) =
                    case CharVector.findi (fn (i, c) => c = #":" andalso i + 1 < size target
                                                        andalso String.sub (target, i + 1) = #":") target of
                      SOME (i, _) => (String.substring (target, 0, i), SOME (String.extract (target, i + 2, NONE)))
                    | NONE => (target, NONE)
                  val reason = String.concatWith "|" rest
                in
                  case meaning category of
                    NONE => raise Parse (where' ^ ": no category " ^ category)
                  | SOME Quarantine =>
                      if isSome (until reason) then ()
                      else raise Parse (where' ^ ": a quarantine says until when: until YYYY-MM-DD: why")
                  | SOME _ => ();
                  if way = "" orelse path = "" then raise Parse (where' ^ ": a way and a path are wanted") else ();
                  SOME {file = file, number = number, way = way, path = path, label = label, category = category,
                        reason = trim reason}
                end
            | _ => raise Parse (file ^ ":" ^ Int.toString number ^ ": WAY | PATH | CATEGORY | reason is wanted")
        end
      val lines = String.fields (fn c => c = #"\n") text
    in
      List.mapPartial (fn x => x) (ListPair.map one (List.tabulate (length lines, fn i => i + 1), lines))
    end

  fun read file =
    let val s = TextIO.openIn file
    in parse (file, TextIO.inputAll s) before TextIO.closeIn s end
    handle IO.Io _ => []

  (* a glob's parts: a character, any one, any run, or a class (negated or
     not, of ranges) *)
  datatype part = Char of char | One | Run | Class of bool * (char * char) list

  fun parts g =
    let
      val n = size g
      fun class (i, neg) =
        let
          (* the ranges up to the closing bracket, or NONE when there is none *)
          fun go (k, acc) =
            if k >= n then NONE
            else if String.sub (g, k) = #"]" andalso k > i then SOME (rev acc, k + 1)
            else if k + 2 < n andalso String.sub (g, k + 1) = #"-" andalso String.sub (g, k + 2) <> #"]"
            then go (k + 3, (String.sub (g, k), String.sub (g, k + 2)) :: acc)
            else go (k + 1, (String.sub (g, k), String.sub (g, k)) :: acc)
        in go (i, []) end
      fun go i =
        if i >= n then []
        else case String.sub (g, i) of
               #"*" => Run :: go (i + 1)
             | #"?" => One :: go (i + 1)
             | #"[" =>
                 let val neg = i + 1 < n andalso String.sub (g, i + 1) = #"!"
                 in case class (if neg then i + 2 else i + 1, neg) of
                      SOME (ranges, k) => Class (neg, ranges) :: go k
                    | NONE => Char #"[" :: go (i + 1)
                 end
             | c => Char c :: go (i + 1)
    in Vector.fromList (go 0) end

  fun glob (g, s) =
    let
      val ps = parts g
      val n = Vector.length ps and m = size s
      fun one (Char c, x) = c = x
        | one (One, _) = true
        | one (Class (neg, ranges), x) = neg <> List.exists (fn (a, b) => a <= x andalso x <= b) ranges
        | one (Run, _) = false
      (* the classic two pointers, with the last run to come back to *)
      fun go (i, j, star) =
        if j = m then
          let fun runs k = k = n orelse (Vector.sub (ps, k) = Run andalso runs (k + 1)) in runs i end
        else if i < n andalso one (Vector.sub (ps, i), String.sub (s, j)) then go (i + 1, j + 1, star)
        else if i < n andalso Vector.sub (ps, i) = Run then go (i + 1, j, SOME (i + 1, j))
        else case star of
               SOME (si, sj) => go (si, sj + 1, SOME (si, sj + 1))
             | NONE => false
    in go (0, 0, NONE) end

  fun matches ({way, path, label, ...} : line) {way = w, path = p, label = l} =
    glob (way, w) andalso glob (path, p)
    andalso (case (label, l) of
               (NONE, _) => true
             | (SOME g, SOME x) => glob (g, x)
             | (SOME _, NONE) => false)

  fun find (ls, t) = List.find (fn l => matches l t) ls

  fun skipped (ls, {way, path}) =
    List.find (fn l => meaning (#category l) = SOME Skip andalso not (isSome (#label l))
                       andalso matches l {way = way, path = path, label = NONE}) ls

  datatype outcome = Pass | Fail | Expected of line | Unexpected of line | Flaky of line
                   | Quarantined of line | Expired of line

  fun judge (ls, {way, path, label, passed, today}) =
    case find (List.filter (fn l => meaning (#category l) <> SOME Skip) ls, {way = way, path = path, label = label}) of
      NONE => if passed then Pass else Fail
    | SOME l =>
        case meaning (#category l) of
          SOME Strict => if passed then Unexpected l else Expected l
        | SOME Lenient => Flaky l
        | SOME Quarantine =>
            if passed then Pass
            else if (case until (#reason l) of SOME d => today <= d | NONE => false) then Quarantined l
            else Expired l
        | _ => if passed then Pass else Fail

  fun failing Fail = true
    | failing (Unexpected _) = true
    | failing (Expired _) = true
    | failing _ = false

  fun stale (ls, {ways, paths, used, today}) =
    List.filter
      (fn l =>
         case meaning (#category l) of
           SOME Strict => List.exists (fn w => glob (#way l, w)) ways
                          andalso not (List.exists (fn u => #file u = #file l andalso #number u = #number l) used)
         | SOME Skip => not (List.exists (fn p => glob (#path l, p)) paths)
         | SOME Quarantine => (case until (#reason l) of SOME d => today > d | NONE => true)
         | _ => false)
      ls

  fun describe ({file, number, way, path, label, category, reason} : line) =
    file ^ ":" ^ Int.toString number ^ ": " ^ way ^ " | " ^ path ^ (case label of SOME x => "::" ^ x | NONE => "")
    ^ " | " ^ category ^ " | " ^ reason
end
