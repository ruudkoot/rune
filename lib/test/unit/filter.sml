(* The filter language: words, tags and ways, combined. *)
structure TestFilter :> TEST_FILTER =
struct
  datatype filter = All | Word of string | Tag of string | Not of filter | And of filter * filter | Or of filter * filter
  exception Parse of string

  val all = All

  fun glob (p, s) =
    let
      fun m ([], []) = true
        | m (#"*" :: ps, cs) = m (ps, cs) orelse (case cs of [] => false | _ :: cs' => m (#"*" :: ps, cs'))
        | m (#"?" :: ps, _ :: cs) = m (ps, cs)
        | m (c :: ps, c' :: cs) = c = c' andalso m (ps, cs)
        | m _ = false
    in m (explode p, explode s) end

  fun tokens s =
    let
      fun flush ([], acc) = acc
        | flush (cur, acc) = implode (rev cur) :: acc
      fun go ([], acc, cur) = rev (flush (cur, acc))
        | go (c :: cs, acc, cur) =
            if Char.isSpace c then go (cs, flush (cur, acc), [])
            else if Char.contains "()!&|" c then go (cs, str c :: flush (cur, acc), [])
            else go (cs, acc, c :: cur)
    in go (explode s, [], []) end

  fun parse s =
    let
      fun orE ts = orRest (andE ts)
      and orRest (e, "|" :: ts) = let val (e', ts) = andE ts in orRest (Or (e, e'), ts) end
        | orRest r = r
      and andE ts = andRest (unary ts)
      and andRest (e, "&" :: ts) = let val (e', ts) = unary ts in andRest (And (e, e'), ts) end
        | andRest r = r
      and unary ("!" :: ts) = let val (e, ts) = unary ts in (Not e, ts) end
        | unary ("(" :: ts) = (case orE ts of (e, ")" :: ts) => (e, ts) | _ => raise Parse "a ( without its )")
        | unary (w :: ts) =
            if w = ")" orelse w = "&" orelse w = "|" then raise Parse ("an unexpected " ^ w)
            else if String.isPrefix "tag:" w then (Tag (String.extract (w, 4, NONE)), ts)
            else if String.isPrefix "way:" w then (Tag w, ts)
            else (Word w, ts)
        | unary [] = raise Parse "the filter ends too early"
    in
      case tokens s of
        [] => All
      | ts => (case orE ts of (e, []) => e | (_, t :: _) => raise Parse ("an unexpected " ^ t))
    end

  fun matches f {path, tags} =
    case f of
      All => true
    | Word p => if CharVector.exists (fn c => c = #"*" orelse c = #"?") p then glob (p, path)
                else String.isSubstring p path
    | Tag t => List.exists (fn x => x = t) tags
    | Not f => not (matches f {path = path, tags = tags})
    | And (a, b) => matches a {path = path, tags = tags} andalso matches b {path = path, tags = tags}
    | Or (a, b) => matches a {path = path, tags = tags} orelse matches b {path = path, tags = tags}
end
