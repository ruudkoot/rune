(* LineEditFn: the line editor over a terminal device; LineEdit is it
   over Device, and a program on another compiler applies it to
   PosixDevice.

   Implements: LINE_EDIT *)
functor LineEditFn (structure Device : DEVICE) :> LINE_EDIT =
struct
  datatype command =
      Insert
    | BeginningOfLine | EndOfLine | ForwardChar | BackwardChar | ForwardWord | BackwardWord
    | PreviousLine | NextLine | PreviousHistory | NextHistory | BeginningOfHistory | EndOfHistory
    | BeginningOfBuffer | EndOfBuffer
    | DeleteChar | DeleteCharOrEnd | BackwardDeleteChar | KillLine | BackwardKillLine
    | KillWord | BackwardKillWord | KillWordBehind | Yank | YankPop
    | TransposeChars | UpcaseWord | DowncaseWord | CapitalizeWord | Undo
    | AcceptOrNewline | Newline | Complete | ReverseSearch | Abort | Cancel | ClearScreen | Suspend
    | Ignore

  type config = {
    prompt : string, continuation : string,
    isComplete : string -> bool,
    complete : string * int -> {start : int, candidates : string list},
    hint : string -> string option,
    highlight : string -> (int * int * Style.style) list,
    styles : {prompt : Style.style, hint : Style.style, menu : Style.style, search : Style.style,
              control : Style.style, mark : Style.style},
    bindings : (Key.event * command) list,
    escapeTimeout : Time.time,
    policy : Grapheme.policy,
    basic : bool}

  type cell = {text : string, style : Style.style}
  type frame = {rows : cell list vector, cursor : int * int}
  datatype outcome = Continue | Accept of string | Cancelled | EndOfInput | Clear | Stop
  datatype result = Line of string | Interrupted | End

  (* ------------------------------------------------------------ keys *)

  fun ctrlKey ch = Key.Char (Char.ord ch, {shift = false, alt = false, ctrl = true})
  fun altKey ch = Key.Char (Char.ord ch, {shift = false, alt = true, ctrl = false})
  fun named n = Key.Named (n, Key.none)
  fun namedWith (n, alt, ctrl) = Key.Named (n, {shift = false, alt = alt, ctrl = ctrl})

  val emacs = [
    (ctrlKey #"a", BeginningOfLine), (named Key.Home, BeginningOfLine),
    (ctrlKey #"e", EndOfLine), (named Key.End, EndOfLine),
    (ctrlKey #"f", ForwardChar), (named Key.Right, ForwardChar),
    (ctrlKey #"b", BackwardChar), (named Key.Left, BackwardChar),
    (altKey #"f", ForwardWord), (namedWith (Key.Right, false, true), ForwardWord), (namedWith (Key.Right, true, false), ForwardWord),
    (altKey #"b", BackwardWord), (namedWith (Key.Left, false, true), BackwardWord), (namedWith (Key.Left, true, false), BackwardWord),
    (named Key.Up, PreviousLine), (named Key.Down, NextLine),
    (ctrlKey #"p", PreviousHistory), (ctrlKey #"n", NextHistory),
    (altKey #"<", BeginningOfHistory), (altKey #">", EndOfHistory),
    (named Key.PageUp, BeginningOfBuffer), (named Key.PageDown, EndOfBuffer),
    (named Key.Delete, DeleteChar), (ctrlKey #"d", DeleteCharOrEnd),
    (named Key.Backspace, BackwardDeleteChar), (namedWith (Key.Backspace, false, true), BackwardDeleteChar),
    (ctrlKey #"k", KillLine), (ctrlKey #"u", BackwardKillLine),
    (altKey #"d", KillWord), (namedWith (Key.Backspace, true, false), BackwardKillWord), (ctrlKey #"w", KillWordBehind),
    (ctrlKey #"y", Yank), (altKey #"y", YankPop),
    (ctrlKey #"t", TransposeChars), (altKey #"u", UpcaseWord), (altKey #"l", DowncaseWord), (altKey #"c", CapitalizeWord),
    (ctrlKey #"_", Undo),
    (named Key.Enter, AcceptOrNewline), (namedWith (Key.Enter, true, false), Newline), (ctrlKey #"j", Newline),
    (named Key.Tab, Complete), (ctrlKey #"r", ReverseSearch),
    (ctrlKey #"g", Abort), (named Key.Escape, Abort), (ctrlKey #"c", Cancel),
    (ctrlKey #"l", ClearScreen), (ctrlKey #"z", Suspend)]

  val defaults : config = {
    prompt = "> ", continuation = "  ",
    isComplete = fn _ => true,
    complete = fn (_, i) => {start = i, candidates = []},
    hint = fn _ => NONE,
    highlight = fn _ => [],
    styles = {prompt = Style.plain, hint = Style.parameters "2", menu = Style.plain, search = Style.parameters "1",
              control = Style.parameters "7", mark = Style.parameters "7"},
    bindings = emacs,
    escapeTimeout = Time.fromMilliseconds 50,
    policy = Grapheme.ByCluster,
    basic = false}

  fun commandOf (c : config, e) =
    case List.find (fn (k, _) => k = e) (#bindings c) of
      SOME (_, cmd) => cmd
    | NONE =>
        case e of
          Key.Char (ch, {ctrl = false, alt = false, ...}) => if ch >= 32 andalso ch <> 127 then Insert else Ignore
        | Key.Named (n, {shift = true, alt, ctrl}) =>
            (case List.find (fn (k, _) => k = Key.Named (n, {shift = false, alt = alt, ctrl = ctrl})) (#bindings c) of
               SOME (_, cmd) => cmd
             | NONE => Ignore)
        | _ => Ignore

  (* ------------------------------------------------------------ the buffer *)

  (* the lines of the text and the cursor: a line and a byte of it *)
  type buffer = {lines : string vector, row : int, col : int}

  fun textOf ({lines, ...} : buffer) = String.concatWith "\n" (Vector.foldr (op ::) [] lines)

  fun offsetOf ({lines, row, col} : buffer) =
    Vector.foldli (fn (i, l, n) => if i < row then n + size l + 1 else n) 0 lines + col

  fun fromText (t, offset) =
    let
      val lines = Vector.fromList (String.fields (fn c => c = #"\n") t)
      fun find (i, at) =
        let val l = Vector.sub (lines, i)
        in
          if offset <= at + size l orelse i + 1 >= Vector.length lines then {lines = lines, row = i, col = Int.min (offset - at, size l)}
          else find (i + 1, at + size l + 1)
        end
    in
      find (0, 0)
    end

  fun lineOf ({lines, row, ...} : buffer) = Vector.sub (lines, row)

  fun setLine ({lines, row, ...} : buffer, l, col) = {lines = Vector.update (lines, row, l), row = row, col = col}

  (* the boundaries of clusters in a line *)
  fun nextBoundary (l, i) = if i >= size l then size l else Int.min (size l, Grapheme.next (l, i))
  fun prevBoundary (l, i) =
    let fun go j = let val k = nextBoundary (l, j) in if k >= i orelse k = j then j else go k end
    in if i <= 0 then 0 else go 0 end

  fun isWord c = Char.isAlphaNum c orelse c = #"_" orelse c = #"'" orelse Char.ord c >= 128

  (* the end of the next word of t from i, and the start of the one before *)
  fun wordEnd (t, i) =
    let
      fun skip (j, p) = if j < size t andalso p (String.sub (t, j)) then skip (j + 1, p) else j
    in
      skip (skip (i, not o isWord), isWord)
    end
  fun wordStart (t, i) =
    let
      fun skip (j, p) = if j > 0 andalso p (String.sub (t, j - 1)) then skip (j - 1, p) else j
    in
      skip (skip (i, not o isWord), isWord)
    end
  (* Ctrl-W's word: up to a blank *)
  fun blankStart (t, i) =
    let
      fun skip (j, p) = if j > 0 andalso p (String.sub (t, j - 1)) then skip (j - 1, p) else j
    in
      skip (skip (i, Char.isSpace), not o Char.isSpace)
    end

  fun replaceText (b : buffer, from, to, s) =
    let val t = textOf b
    in fromText (String.substring (t, 0, from) ^ s ^ String.extract (t, to, NONE), from + size s) end

  fun insertText (b : buffer, s) =
    if CharVector.exists (fn c => c = #"\n") s then let val i = offsetOf b in replaceText (b, i, i, s) end
    else
      let val l = lineOf b
      in setLine (b, String.substring (l, 0, #col b) ^ s ^ String.extract (l, #col b, NONE), #col b + size s) end

  (* ------------------------------------------------------------ the state *)

  datatype last = Other | Typed | Killed | Yanked of int | Tabbed

  type search = {query : string, at : int, original : buffer, failing : bool}

  type state = {buf : buffer, ring : string list, last : last, undo : buffer list,
                history : string vector, place : int, saved : buffer, prefix : string,
                search : search option, menu : string list option}

  fun start (history, t) =
    let val b = fromText (t, size t)
    in
      {buf = b, ring = [], last = Other, undo = [], history = history, place = Vector.length history,
       saved = b, prefix = "", search = NONE, menu = NONE}
    end

  fun text (s : state) = textOf (#buf s)
  fun cursor (s : state) = offsetOf (#buf s)

  fun withBuf ({ring, last, undo, history, place, saved, prefix, search, menu, ...} : state) b : state =
    {buf = b, ring = ring, last = last, undo = undo, history = history, place = place, saved = saved,
     prefix = prefix, search = search, menu = menu}
  fun withLast ({buf, ring, undo, history, place, saved, prefix, search, menu, ...} : state) l : state =
    {buf = buf, ring = ring, last = l, undo = undo, history = history, place = place, saved = saved,
     prefix = prefix, search = search, menu = menu}
  fun withRing ({buf, last, undo, history, place, saved, prefix, search, menu, ...} : state) r : state =
    {buf = buf, ring = r, last = last, undo = undo, history = history, place = place, saved = saved,
     prefix = prefix, search = search, menu = menu}
  fun withUndo ({buf, ring, last, history, place, saved, prefix, search, menu, ...} : state) u : state =
    {buf = buf, ring = ring, last = last, undo = u, history = history, place = place, saved = saved,
     prefix = prefix, search = search, menu = menu}
  fun withPlace ({buf, ring, last, undo, history, search, menu, ...} : state) (place, saved, prefix) : state =
    {buf = buf, ring = ring, last = last, undo = undo, history = history, place = place, saved = saved,
     prefix = prefix, search = search, menu = menu}
  fun withSearch ({buf, ring, last, undo, history, place, saved, prefix, menu, ...} : state) se : state =
    {buf = buf, ring = ring, last = last, undo = undo, history = history, place = place, saved = saved,
     prefix = prefix, search = se, menu = menu}
  fun withMenu ({buf, ring, last, undo, history, place, saved, prefix, search, ...} : state) m : state =
    {buf = buf, ring = ring, last = last, undo = undo, history = history, place = place, saved = saved,
     prefix = prefix, search = search, menu = m}

  (* an edit: what was there pushed to be undone (typing groups until a
     blank), then the new buffer *)
  fun edit (s : state, b, l) =
    let
      val group = (case (#last s, l) of (Typed, Typed) => true | _ => false)
      val undo = if group then #undo s else List.take (#buf s :: #undo s, Int.min (100, 1 + List.length (#undo s)))
    in
      withLast (withUndo (withBuf s b) undo) l
    end

  fun move (s, b) = withLast (withBuf s b) Other

  (* the killed text joined to the last kill when this one follows it *)
  fun kill (s : state, from, to, backward) =
    let
      val t = textOf (#buf s)
      val k = String.substring (t, from, to - from)
      val ring = case (#last s, #ring s) of
                   (Killed, r :: rest) => (if backward then k ^ r else r ^ k) :: rest
                 | (_, ring) => List.take (k :: ring, Int.min (60, 1 + List.length ring))
    in
      if from = to then withLast s Other
      else withLast (withRing (edit (s, replaceText (#buf s, from, to, ""), Other)) ring) Killed
    end

  (* ------------------------------------------------------------ history *)

  fun load (s : state, i) =
    let val e = Vector.sub (#history s, i)
    in withLast (withBuf (withPlace s (i, #saved s, #prefix s)) (fromText (e, size e))) Other end

  fun fresh (s : state) = #place s = Vector.length (#history s)

  (* the entry before or after the place that begins with what was typed *)
  fun previous (s : state) =
    let
      val s = if fresh s then withPlace s (#place s, #buf s, textOf (#buf s)) else s
      val now = textOf (#buf s)
      fun go i = if i < 0 then s
                 else let val e = Vector.sub (#history s, i)
                      in if String.isPrefix (#prefix s) e andalso e <> now then load (s, i) else go (i - 1) end
    in
      go (#place s - 1)
    end

  fun next (s : state) =
    let
      val n = Vector.length (#history s)
      val now = textOf (#buf s)
      fun go i = if i >= n then
                   if fresh s then s
                   else withLast (withBuf (withPlace s (n, #saved s, "")) (#saved s)) Other
                 else let val e = Vector.sub (#history s, i)
                      in if String.isPrefix (#prefix s) e andalso e <> now then load (s, i) else go (i + 1) end
    in
      go (#place s + 1)
    end

  (* the newest entry from i down that has the query, and where in it *)
  fun searchFrom (s : state, query, i) =
    let
      fun has e =
        let fun at j = if j + size query > size e then NONE
                       else if String.substring (e, j, size query) = query then SOME j else at (j + 1)
        in at 0 end
      fun go i = if i < 0 then NONE
                 else case has (Vector.sub (#history s, i)) of SOME j => SOME (i, j) | NONE => go (i - 1)
    in
      go i
    end

  (* ------------------------------------------------------------ commands *)

  (* a paste's line ends, CR LF and CR, as newlines *)
  fun normalise t =
    let
      fun go (#"\r" :: #"\n" :: rest, acc) = go (rest, #"\n" :: acc)
        | go (#"\r" :: rest, acc) = go (rest, #"\n" :: acc)
        | go (c :: rest, acc) = go (rest, c :: acc)
        | go ([], acc) = String.implode (rev acc)
    in
      go (String.explode t, [])
    end

  fun commonPrefix [] = ""
    | commonPrefix (x :: xs) =
        let
          fun two (a, b) =
            let fun go i = if i < size a andalso i < size b andalso String.sub (a, i) = String.sub (b, i) then go (i + 1) else i
            in String.substring (a, 0, go 0) end
          val p = foldl two x xs
          fun valid p = if Utf8.isValid p then p else valid (String.substring (p, 0, size p - 1))
        in
          valid p
        end

  fun caseWord (s : state, f) =
    let
      val t = textOf (#buf s)
      val i = offsetOf (#buf s)
      val j = wordEnd (t, i)
      val w = f (String.substring (t, i, j - i))
    in
      edit (s, replaceText (#buf s, i, j, w), Other)
    end

  fun capitalize w =
    let
      fun go (_, []) = []
        | go (seen, c :: rest) =
            if isWord c then (if seen then Char.toLower c else Char.toUpper c) :: go (true, rest)
            else c :: go (seen, rest)
    in
      String.implode (go (false, String.explode w))
    end

  fun command (c : config, s : state, cmd, e) : state * outcome =
    let
      val b = #buf s
      val l = lineOf b
      val t = textOf b
      val i = offsetOf b
      val lastRow = Vector.length (#lines b) - 1
      val atEnd = #row b = lastRow andalso #col b = size l
      fun cont s = (s, Continue)
      fun hinted () = case #hint c t of SOME h => if atEnd andalso h <> "" then SOME h else NONE | NONE => NONE
      fun column (line, col) = Grapheme.width (#policy c) (String.substring (line, 0, col))
      fun atColumn (line, w) =
        let fun go j = let val k = nextBoundary (line, j)
                       in if k = j orelse column (line, k) > w then j else go k end
        in go 0 end
      fun toRow r = move (s, {lines = #lines b, row = r, col = atColumn (Vector.sub (#lines b, r), column (l, #col b))})
    in
      case cmd of
        Insert =>
          (case e of
             Key.Char (ch, _) =>
               let val str = Utf8.encode ch handle Chr => ""
               in cont (edit (s, insertText (b, str), if CharVector.all (fn x => isWord x) str then Typed else Other)) end
           | _ => cont s)
      | BeginningOfLine => cont (move (s, setLine (b, l, 0)))
      | EndOfLine =>
          (case hinted () of
             SOME h => cont (edit (s, insertText (b, h), Other))
           | NONE => cont (move (s, setLine (b, l, size l))))
      | ForwardChar =>
          (case hinted () of
             SOME h => cont (edit (s, insertText (b, h), Other))
           | NONE =>
               if #col b < size l then cont (move (s, setLine (b, l, nextBoundary (l, #col b))))
               else if #row b < lastRow then cont (move (s, {lines = #lines b, row = #row b + 1, col = 0}))
               else cont s)
      | BackwardChar =>
          if #col b > 0 then cont (move (s, setLine (b, l, prevBoundary (l, #col b))))
          else if #row b > 0 then
            let val r = #row b - 1 in cont (move (s, {lines = #lines b, row = r, col = size (Vector.sub (#lines b, r))})) end
          else cont s
      | ForwardWord => cont (move (s, fromText (t, wordEnd (t, i))))
      | BackwardWord => cont (move (s, fromText (t, wordStart (t, i))))
      | PreviousLine => if #row b > 0 then cont (toRow (#row b - 1)) else cont (previous s)
      | NextLine => if #row b < lastRow then cont (toRow (#row b + 1)) else cont (next s)
      | PreviousHistory => cont (previous s)
      | NextHistory => cont (next s)
      | BeginningOfHistory =>
          if Vector.length (#history s) = 0 then cont s
          else
            let val s = if fresh s then withPlace s (#place s, b, "") else withPlace s (#place s, #saved s, "")
            in cont (load (s, 0)) end
      | EndOfHistory =>
          if fresh s then cont s
          else cont (withLast (withBuf (withPlace s (Vector.length (#history s), #saved s, "")) (#saved s)) Other)
      | BeginningOfBuffer => cont (move (s, fromText (t, 0)))
      | EndOfBuffer => cont (move (s, fromText (t, size t)))
      | DeleteChar =>
          if i >= size t then cont s
          else
            let val j = if #col b < size l then i + (nextBoundary (l, #col b) - #col b) else i + 1
            in cont (edit (s, replaceText (b, i, j, ""), Other)) end
      | DeleteCharOrEnd => if t = "" then (s, EndOfInput) else command (c, s, DeleteChar, e)
      | BackwardDeleteChar =>
          if i = 0 then cont s
          else
            let val j = if #col b > 0 then i - (#col b - prevBoundary (l, #col b)) else i - 1
            in cont (edit (s, replaceText (b, j, i, ""), Other)) end
      | KillLine =>
          if #col b = size l then (if #row b < lastRow then cont (kill (s, i, i + 1, false)) else cont s)
          else cont (kill (s, i, i + (size l - #col b), false))
      | BackwardKillLine => cont (kill (s, i - #col b, i, true))
      | KillWord => cont (kill (s, i, wordEnd (t, i), false))
      | BackwardKillWord => cont (kill (s, wordStart (t, i), i, true))
      | KillWordBehind => cont (kill (s, blankStart (t, i), i, true))
      | Yank =>
          (case #ring s of
             [] => cont s
           | k :: _ => cont (edit (s, insertText (b, k), Yanked (size k))))
      | YankPop =>
          (case (#last s, #ring s) of
             (Yanked n, k :: rest) =>
               let
                 val ring = rest @ [k]
                 val y = hd ring
               in
                 cont (withLast (withRing (withBuf s (replaceText (b, i - n, i, y))) ring) (Yanked (size y)))
               end
           | _ => cont s)
      | TransposeChars =>
          if #col b = 0 orelse size l < 2 then cont s
          else
            let
              val at = if #col b = size l then prevBoundary (l, #col b) else #col b
              val p = prevBoundary (l, at)
              val q = nextBoundary (l, at)
              val swapped = String.substring (l, 0, p) ^ String.substring (l, at, q - at) ^ String.substring (l, p, at - p)
                            ^ String.extract (l, q, NONE)
            in
              cont (edit (s, setLine (b, swapped, q), Other))
            end
      | UpcaseWord => cont (caseWord (s, String.map Char.toUpper))
      | DowncaseWord => cont (caseWord (s, String.map Char.toLower))
      | CapitalizeWord => cont (caseWord (s, capitalize))
      | Undo =>
          (case #undo s of
             [] => cont s
           | u :: rest => cont (withLast (withUndo (withBuf s u) rest) Other))
      | AcceptOrNewline =>
          if #isComplete c t then (s, Accept t) else command (c, s, Newline, e)
      | Newline =>
          let
            fun indent j = if j < size l andalso (String.sub (l, j) = #" " orelse String.sub (l, j) = #"\t") then indent (j + 1) else j
          in
            cont (edit (s, insertText (b, "\n" ^ String.substring (l, 0, indent 0)), Other))
          end
      | Complete =>
          let
            val {start = st, candidates} = #complete c (t, i)
            val st = Int.max (0, Int.min (st, i))
            val typed = i - st
          in
            case candidates of
              [] => cont (withLast s Other)
            | [one] => cont (edit (s, replaceText (b, st, i, one), Other))
            | many =>
                let val p = commonPrefix many
                in
                  if size p > typed then cont (withLast (edit (s, replaceText (b, st, i, p), Other)) Tabbed)
                  else if #last s = Tabbed then cont (withMenu (withLast s Other) (SOME many))
                  else cont (withLast s Tabbed)
                end
          end
      | ReverseSearch =>
          cont (withSearch (withLast s Other) (SOME {query = "", at = Vector.length (#history s), original = b, failing = false}))
      | Abort => cont (withMenu (withSearch (withLast s Other) NONE) NONE)
      | Cancel => (s, Cancelled)
      | ClearScreen => (s, Clear)
      | Suspend => (s, Stop)
      | Ignore => cont s
    end

  (* a key while searching: the query grows or shrinks and the match is
     sought again; Ctrl-R seeks an older one; Enter accepts the match, and
     Ctrl-G or Escape gives back what was there; any other key ends the
     search, keeping the match, and does what it does *)
  fun searching (c : config, s : state, se : search, e) =
    let
      val {query, at, original, ...} = se
      fun seek (q, from) =
        case searchFrom (s, q, from) of
          SOME (k, j) =>
            let
              val entry = Vector.sub (#history s, k)
              val s = withPlace (withSearch s (SOME {query = q, at = k, original = original, failing = false}))
                                (k, original, "")
            in
              (withBuf s (fromText (entry, j)), Continue)
            end
        | NONE => (withSearch s (SOME {query = q, at = at, original = original, failing = q <> ""}), Continue)
      val cmd = commandOf (c, e)
    in
      case (cmd, e) of
        (Insert, Key.Char (ch, _)) => seek (query ^ (Utf8.encode ch handle Chr => ""),
                                            if at < Vector.length (#history s) then at else at - 1)
      | (ReverseSearch, _) => seek (query, at - 1)
      | (BackwardDeleteChar, _) =>
          let val q = if query = "" then "" else String.substring (query, 0, prevBoundary (query, size query))
          in seek (q, Vector.length (#history s) - 1) end
      | (AcceptOrNewline, _) => let val s = withSearch s NONE in (s, Accept (text s)) end
      | (Abort, _) => (withPlace (withBuf (withSearch s NONE) original) (Vector.length (#history s), original, ""), Continue)
      | _ => command (c, withSearch s NONE, cmd, e)
    end

  fun step (c : config, s : state, e) =
    let val s = case e of Key.Named (Key.Tab, _) => s | _ => withMenu s NONE
    in
      case (#search s, e) of
        (SOME se, _) => searching (c, s, se, e)
      | (NONE, Key.Paste p) => (edit (s, insertText (#buf s, normalise p), Other), Continue)
      | (NONE, _) => command (c, s, commandOf (c, e), e)
    end

  (* ------------------------------------------------------------ layout *)

  fun cellsOf (policy, t, style, control) =
    List.concat (map (fn cl =>
      let val b = Char.ord (String.sub (cl, 0))
      in
        if b < 32 orelse b = 127 then
          [{text = "^", style = control}, {text = String.str (Char.chr (if b = 127 then 63 else b + 64)), style = control}]
        else
          case Grapheme.width policy cl of
            0 => [{text = cl, style = style}]
          | 1 => [{text = cl, style = style}]
          | _ => [{text = cl, style = style}, {text = "", style = style}]
      end) (Grapheme.clusters t))

  (* spans by where they begin, those that begin together in their order *)
  fun sortSpans [] = []
    | sortSpans [x] = [x]
    | sortSpans xs =
        let
          val half = List.length xs div 2
          fun merge ([], ys) = ys
            | merge (xs, []) = xs
            | merge ((x as (a, _, _)) :: xs', (y as (b, _, _)) :: ys') =
                if b < a then y :: merge (x :: xs', ys') else x :: merge (xs', y :: ys')
        in
          merge (sortSpans (List.take (xs, half)), sortSpans (List.drop (xs, half)))
        end

  fun trimRow cells =
    let
      fun drop [] = []
        | drop (x :: rest) = if x = {text = " ", style = Style.plain} then drop rest else x :: rest
    in
      rev (drop (rev cells))
    end

  (* A row being built: the rows finished, the cells of the one begun
     (last first) and its column. *)
  type builder = {rows : cell list list ref, cur : cell list ref, col : int ref, columns : int, policy : Grapheme.policy}

  fun builder (columns, policy) : builder = {rows = ref [], cur = ref [], col = ref 0, columns = columns, policy = policy}

  fun finish (b : builder) = (#rows b := rev (!(#cur b)) :: !(#rows b); #cur b := []; #col b := 0)

  fun emit (b : builder) (cell : cell, w) =
    if w = 0 then
      (case !(#cur b) of
         (p : cell) :: rest => #cur b := {text = #text p ^ #text cell, style = #style p} :: rest
       | [] => (#cur b := [cell]; #col b := 1))
    else ((if !(#col b) + w > #columns b then finish b else ()); #cur b := cell :: !(#cur b); #col b := !(#col b) + 1)

  fun emitCells (b : builder) cells =
    let
      fun width (x : cell) = if Grapheme.width (#policy b) (#text x) = 0 andalso #text x <> " " then 0 else 1
      fun go [] = ()
        | go ((x : cell) :: (y : cell) :: rest) =
            if #text y = "" andalso #text x <> "" then
              ((if !(#col b) + 2 > #columns b then finish b else ());
               #cur b := y :: x :: !(#cur b); #col b := !(#col b) + 2; go rest)
            else (emit b (x, width x); go (y :: rest))
        | go [x] = emit b (x, width x)
    in
      go cells
    end

  (* The rows of one line of the input: its prompt, its text in the styles
     of its spans (offsets in the line), wrapped at the width, and the hint
     after it when there is one; and where the cursor is in them, when it
     is in this line at byte cursorCol. A line that fills its last row has
     a row of its own after it, where the cursor after it is. *)
  fun lineRows (c : config, columns, prompt, l, spans, cursorCol, hint) =
    let
      val styles = #styles c
      val policy = #policy c
      val b = builder (columns, policy)
      val cursorAt = ref NONE
      fun mark w =
        cursorAt := SOME (if !(#col b) >= columns orelse (w > 0 andalso !(#col b) + w > columns)
                          then (List.length (!(#rows b)) + 1, 0)
                          else (List.length (!(#rows b)), !(#col b)))
      (* the style at p, which only grows: the spans that have begun by p,
         the one that began last winning *)
      val waiting = ref (sortSpans spans)
      val active = ref [] : (int * int * Style.style) list ref
      fun styleAt p =
        let
          fun take () =
            case !waiting of
              (sp as (a, _, _)) :: rest => if a <= p then (active := sp :: !active; waiting := rest; take ()) else ()
            | [] => ()
        in
          take ();
          active := List.filter (fn (_, z, _) => z > p) (!active);
          case !active of (_, _, st) :: _ => st | [] => Style.plain
        end
      fun go j =
        if j >= size l then (if cursorCol = SOME j then mark 0 else ())
        else
          let
            val n = nextBoundary (l, j)
            val cl = String.substring (l, j, n - j)
            val first = Char.ord (String.sub (cl, 0))
            val w = if cl = "\t" then 1 else if first < 32 orelse first = 127 then 2 else Grapheme.width policy cl
            val () = if cursorCol = SOME j then mark w else ()
          in
            if cl = "\t" then
              let fun pad () = (emit b ({text = " ", style = styleAt j}, 1);
                                if !(#col b) mod 8 <> 0 andalso !(#col b) < columns then pad () else ())
              in pad () end
            else emitCells b (cellsOf (policy, cl, styleAt j, #control styles));
            go n
          end
    in
      emitCells b (cellsOf (policy, prompt, #prompt styles, #control styles));
      go 0;
      (case hint of SOME h => emitCells b (cellsOf (policy, h, #hint styles, #control styles)) | NONE => ());
      if !(#col b) >= columns then finish b else ();
      finish b;
      (rev (!(#rows b)), !cursorAt)
    end

  (* The rows of the lines of the last layout, by line, and what they were
     laid out with: a line whose text, prompt and spans have not changed is
     not laid out again (most keys change one line of the input). *)
  val laidOut : {context : (int * string * string * Style.style * Style.style * Style.style * Grapheme.policy),
                 lines : (string * string * (int * int * Style.style) list * cell list list) vector} option ref = ref NONE

  fun layoutWith (c : config, s : state, columns, extras) : frame =
    let
      val b = #buf s
      val policy = #policy c
      val styles = #styles c
      val lines = #lines b
      val n = Vector.length lines
      val t = textOf b
      val spans = sortSpans (#highlight c t)
      val lastLine = n - 1
      val atEnd = #row b = lastLine andalso #col b = size (Vector.sub (lines, lastLine))
      val hint = if extras andalso atEnd andalso not (isSome (#search s)) then #hint c t else NONE
      (* the spans of each line, relative to it *)
      val starts = Vector.fromList (rev (#2 (Vector.foldl (fn (l, (at, acc)) => (at + size l + 1, at :: acc)) (0, []) lines)))
      val perLine = Array.array (n, []) : (int * int * Style.style) list array
      (* the spans come by where they begin, so the line of each is found
         from the line of the one before *)
      val () =
        let
          fun place (_, []) = ()
            | place (k, (a, z, st) :: rest) =
                let
                  fun line j = if j + 1 < n andalso Vector.sub (starts, j + 1) <= a then line (j + 1) else j
                  val k = line k
                  fun put j =
                    if j >= n orelse Vector.sub (starts, j) >= z then ()
                    else
                      let val at = Vector.sub (starts, j)
                      in Array.update (perLine, j, (Int.max (a - at, 0), z - at, st) :: Array.sub (perLine, j)); put (j + 1) end
                in
                  put k; place (k, rest)
                end
        in
          place (0, spans);
          Array.modify rev perLine
        end
      val context = (columns, #prompt c, #continuation c, #prompt styles, #control styles, #hint styles, policy)
      val previous = case !laidOut of SOME {context = c', lines = ls} => if c' = context then ls else Vector.fromList [] | NONE => Vector.fromList []
      val shift = n - Vector.length previous
      (* a line's rows from the last layout: at the same place, or where it
         was before lines were added or taken away above it; with the same
         prompt, since the first line has its own *)
      fun cached (k, prompt, l, sp) =
        let
          fun at i = if i >= 0 andalso i < Vector.length previous then
                       let val (p', l', sp', rows) = Vector.sub (previous, i)
                       in if l' = l andalso p' = prompt andalso sp' = sp then SOME rows else NONE end
                     else NONE
        in
          case at k of SOME r => SOME r | NONE => if shift <> 0 then at (k - shift) else NONE
        end
      val cursorRow = ref 0
      val cursorCol = ref 0
      val count = ref 0
      val built =
        Vector.tabulate (n, fn k =>
          let
            val l = Vector.sub (lines, k)
            val sp = Array.sub (perLine, k)
            val prompt = if k = 0 then #prompt c else #continuation c
            val here = if k = #row b then SOME (#col b) else NONE
            val h = if k = lastLine then hint else NONE
            val rows =
              case (here, h, cached (k, prompt, l, sp)) of
                (NONE, NONE, SOME rows) => rows
              | _ =>
                  let val (rows, at) = lineRows (c, columns, prompt, l, sp, here, h)
                  in
                    (case at of SOME (r, col) => (cursorRow := !count + r; cursorCol := col) | NONE => ());
                    rows
                  end
          in
            count := !count + List.length rows;
            (prompt, l, sp, rows)
          end)
      val () = laidOut := SOME {context = context, lines = built}
      val bodyRows = Vector.foldr (fn ((_, _, _, rows), acc) => rows @ acc) [] built
      (* the cursor after a full row is at the start of the next *)
      val bodyRows = if !cursorRow >= List.length bodyRows then bodyRows @ [[]] else bodyRows
      val extra = builder (columns, policy)
      val () =
        if not extras then ()
        else
          case (#search s, #menu s) of
            (SOME {query, failing, ...}, _) =>
              (emitCells extra (cellsOf (policy, (if failing then "(failing reverse-i-search)`" else "(reverse-i-search)`")
                                                 ^ query ^ "'", #search styles, #control styles));
               finish extra)
          | (NONE, SOME cands) =>
              let
                val w = foldl (fn (x, m) => Int.max (Grapheme.width policy x, m)) 0 cands + 2
                val per = Int.max (1, columns div w)
                val shown = List.take (cands, Int.min (List.length cands, per * 8))
                fun put [] = ()
                  | put xs =
                      let
                        val now = List.take (xs, Int.min (per, List.length xs))
                        val rest = List.drop (xs, List.length now)
                      in
                        List.app (fn x => (emitCells extra (cellsOf (policy, x, #menu styles, #control styles));
                                           List.app (fn _ => emit extra ({text = " ", style = Style.plain}, 1))
                                                    (List.tabulate (Int.max (0, w - Grapheme.width policy x), fn _ => ()))))
                                 now;
                        finish extra;
                        put rest
                      end
              in
                put shown;
                if List.length cands > List.length shown then
                  (emitCells extra (cellsOf (policy, "(" ^ Int.toString (List.length cands - List.length shown) ^ " more)",
                                             #menu styles, #control styles));
                   finish extra)
                else ()
              end
          | (NONE, NONE) => ()
    in
      {rows = Vector.fromList (map trimRow (bodyRows @ rev (!(#rows extra)))), cursor = (!cursorRow, !cursorCol)}
    end

  fun layout (c, s, columns) = layoutWith (c, s, Int.max (columns, 2), true)

  (* ------------------------------------------------------------ drawing *)

  fun diff {old : frame option, new : frame, columns, drawn} =
    let
      val out = ref [] : string list ref
      fun put s = out := s :: !out
      val oldRows = case old of SOME f => #rows f | NONE => Vector.fromList []
      val cur = ref (case old of SOME f => #1 (#cursor f) | NONE => 0)
      val drawn = ref (Int.max (drawn, 1))
      fun csi (n, f) = put ("\027[" ^ Int.toString n ^ f)
      fun moveTo i =
        if i < !cur then (csi (!cur - i, "A"); cur := i)
        else if i > !cur then
          let val existing = Int.min (i, !drawn - 1)
          in
            (if existing > !cur then csi (existing - !cur, "B") else ());
            cur := existing;
            while !cur < i do (put "\r\n"; cur := !cur + 1; drawn := Int.max (!drawn, !cur + 1))
          end
        else ()
      fun firstDifference (old, new) =
        let
          fun go (k, (x : cell) :: xs, y :: ys) = if x = y then go (k + 1, xs, ys) else k
            | go (k, _, _) = k
        in
          go (0, old, new)
        end
      val n = Vector.length (#rows new)
      fun row i =
        let
          val now = Vector.sub (#rows new, i)
          val was = if i < Vector.length oldRows then SOME (Vector.sub (oldRows, i)) else NONE
        in
          if was = SOME now then ()
          else
            let
              val oldCells = getOpt (was, [])
              val k = firstDifference (oldCells, now)
              (* not inside a wide cluster, of either row *)
              fun half (cells : cell list, j) = j < List.length cells andalso #text (List.nth (cells, j)) = ""
              fun back j = if j > 0 andalso (half (now, j) orelse half (oldCells, j)) then back (j - 1) else j
              val k = back k
              val style = ref Style.plain
              val rest = List.drop (now, Int.min (k, List.length now))
            in
              moveTo i;
              csi (k + 1, "G");
              List.app (fn {text, style = st} => (put (Style.change (!style, st)); style := st; put text)) rest;
              (if !style <> Style.plain then put (Style.sgr Style.plain) else ());
              if List.length now < columns then put "\027[K" else ()
            end
        end
      val () = List.app row (List.tabulate (n, fn i => i))
      val () = if Vector.length oldRows > n then (moveTo n; put "\r\027[J") else ()
      val (r, col) = #cursor new
      val () = moveTo r
      val () = csi (col + 1, "G")
    in
      (String.concat (rev (!out)), !drawn)
    end

  (* the rows of a frame that fit a terminal of that height, around the
     cursor, from the top the last frame showed when the cursor is still
     among them *)
  fun window ({rows, cursor = (r, col)} : frame, height, top) =
    let
      val n = Vector.length rows
      val height = Int.max (height, 1)
      val top = if n <= height then 0
                else if r < top then r
                else if r >= top + height then r - height + 1
                else Int.min (top, n - height)
      val shown = Int.min (height, n - top)
    in
      ({rows = VectorSlice.vector (VectorSlice.slice (rows, top, SOME shown)), cursor = (r - top, col)}, top)
    end

  (* ------------------------------------------------------------ the loop *)

  fun env name = case OS.Process.getEnv name of SOME v => v | NONE => ""

  fun isBasic (c : config) =
    #basic c orelse not (Device.available ())
    orelse List.exists (fn t => env "TERM" = t) ["dumb", "unknown", "cons25", "emacs"]
    orelse String.isSubstring "comint" (env "INSIDE_EMACS")
    orelse env "RUNE_BASIC_REPL" <> ""

  val basic = isBasic

  fun basicLine (c : config) =
    let
      fun ask (prompt, acc) =
        (TextIO.output (TextIO.stdOut, prompt); TextIO.flushOut TextIO.stdOut;
         case TextIO.inputLine TextIO.stdIn of
           NONE => if null acc then End else Line (String.concatWith "\n" (rev acc))
         | SOME l =>
             let
               val l = if String.isSuffix "\n" l then String.substring (l, 0, size l - 1) else l
               val t = String.concatWith "\n" (rev (l :: acc))
             in
               if #isComplete c t then Line t else ask (#continuation c, l :: acc)
             end)
    in
      ask (#prompt c, [])
    end

  val pasteOn = "\027[?2004h"
  val pasteOff = "\027[?2004l"
  val syncOn = "\027[?2026h"
  val syncOff = "\027[?2026l"

  fun suspend () =
    Posix.Process.kill (Posix.Process.K_PROC (Posix.ProcEnv.getpid ()), Posix.Signal.tstp)
    handle OS.SysErr _ => ()

  (* Windows stops no process: there Ctrl-Z does nothing *)
  fun canStop () =
    not (List.exists (fn (k, v) => k = "sysname" andalso v = "Windows") (Posix.ProcEnv.uname ()))
    handle _ => false

  fun readLine (c : config, h) =
    if isBasic c then
      (case basicLine c of
         Line t => (case h of SOME h => History.add (h, t) | NONE => (); Line t)
       | r => r)
    else
      let
        val () = case h of SOME h => History.refresh h | NONE => ()
        val history = case h of SOME h => History.entries h | NONE => Vector.fromList []
        val seen = ref (Device.resizes ())
        val size = ref (Device.size ())
        val shown : frame option ref = ref NONE
        val top = ref 0
        val drawn = ref 1
        fun columns () = #columns (!size)
        fun draw (s, extras) =
          let
            val full = layoutWith (c, s, Int.max (columns (), 2), extras)
            val (w, t) = window (full, #rows (!size), !top)
            val (bytes, d) = diff {old = !shown, new = w, columns = columns (), drawn = !drawn}
          in
            Device.write (syncOn ^ bytes ^ syncOff);
            shown := SOME w; top := t; drawn := d
          end
        (* the mark of a line the program left unfinished, as zsh's
           PROMPT_SP: on a line of its own it is overwritten *)
        fun mark () =
          Device.write (Style.sgr (#mark (#styles c)) ^ "%" ^ Style.sgr Style.plain
                          ^ CharVector.tabulate (Int.max (0, columns () - 1), fn _ => #" ") ^ "\r\027[K")
        (* the frame drawn again after a resize. Wider, the rows drawn are
           where they were, and it is drawn over them. Narrower, a terminal
           that reflows (VTE, kitty, Windows' console) has wrapped them onto
           more rows and one that does not (xterm, tmux) has cut them, and
           the editor cannot tell which: it leaves what it drew, as fish
           does, and draws again on a line of its own below the cursor,
           which keeps every line the program wrote above. *)
        fun redraw (s, wider) =
          ((case (!shown, wider) of
              (SOME f, true) =>
                if #1 (#cursor f) > 0 then Device.write ("\027[" ^ Int.toString (#1 (#cursor f)) ^ "A") else ()
            | (SOME _, false) => Device.write "\r\n"
            | (NONE, _) => ());
           Device.write "\r\027[J";
           shown := NONE; drawn := 1; top := 0; draw (s, true))
        fun finish (s, ending) =
          let
            val full = layoutWith (c, s, Int.max (columns (), 2), false)
            val (w, t) = window (full, #rows (!size), !top)
            val last = Vector.length (#rows w) - 1
            val (bytes, _) = diff {old = !shown, new = {rows = #rows w, cursor = (last, 0)},
                                   columns = columns (), drawn = !drawn}
          in
            Device.write (bytes ^ "\027[" ^ Int.toString (List.length (Vector.sub (#rows w, last)) + 1) ^ "G"
                            ^ ending ^ "\r\n");
            top := t
          end
        fun loop (s, d) =
          let
            val wait = if Key.pending d then SOME (#escapeTimeout c) else NONE
            val got = Device.read wait
            val r = Device.resizes ()
            val (s, d) =
              if r <> !seen then
                let val earlier = columns ()
                in seen := r; size := Device.size (); redraw (s, columns () >= earlier); (s, d) end
              else (s, d)
          in
            case got of
              NONE => (finish (s, ""); End)
            | SOME bytes =>
                let
                  val (events, d) = if bytes = "" then (if Key.pending d then Key.flush d else ([], d))
                                    else Key.feed (d, bytes)
                  fun run (s, []) = (s, NONE)
                    | run (s, e :: es) =
                        case step (c, s, e) of
                          (s, Continue) => run (s, es)
                        | (s, Clear) => (Device.write "\027[H\027[2J"; shown := NONE; drawn := 1; top := 0; run (s, es))
                        | (s, Stop) =>
                            if not (canStop ()) then run (s, es) else
                            (finish (s, ""); Device.leave (); suspend ();
                             Device.enter {undo = pasteOff}; Device.write pasteOn;
                             size := Device.size (); seen := Device.resizes ();
                             shown := NONE; drawn := 1; top := 0; run (s, es))
                        | (s, outcome) => (s, SOME outcome)
                in
                  case run (s, events) of
                    (s, NONE) => (if bytes <> "" orelse not (null events) then draw (s, true) else (); loop (s, d))
                  | (s, SOME (Accept t)) => (finish (s, ""); Line t)
                  | (s, SOME Cancelled) => (finish (s, "^C"); Interrupted)
                  | (s, SOME _) => (finish (s, ""); End)
                end
          end
        val () = Device.enter {undo = pasteOff}
        val () = Device.write pasteOn
        val () = mark ()
        val s = start (history, "")
        val result = (draw (s, true); loop (s, Key.empty))
                     handle x => (Device.leave (); raise x)
      in
        Device.leave ();
        (case (result, h) of (Line t, SOME h) => History.add (h, t) | _ => ());
        result
      end
end
