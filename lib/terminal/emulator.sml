(* Emulator: a terminal in memory, for the tests of what is drawn.

   Implements: EMULATOR *)
structure Emulator :> EMULATOR =
struct
  type cell = {text : string, style : Style.style}
  type screen = {columns : int, height : int, policy : Grapheme.policy,
                 cells : cell vector vector, row : int, col : int, wrapPending : bool,
                 style : Style.style, scrolled : int, pending : string,
                 bracketedPaste : bool, cursorVisible : bool}

  val blank : cell = {text = " ", style = Style.plain}

  fun new {columns, rows, policy} =
    {columns = columns, height = rows, policy = policy,
     cells = Vector.tabulate (rows, fn _ => Vector.tabulate (columns, fn _ => blank)),
     row = 0, col = 0, wrapPending = false, style = Style.plain, scrolled = 0, pending = "",
     bracketedPaste = false, cursorVisible = true}

  fun cursor (s : screen) = (#row s, #col s)
  fun scrolled (s : screen) = #scrolled s
  fun modes (s : screen) = {bracketedPaste = #bracketedPaste s, cursorVisible = #cursorVisible s}

  fun resize (s : screen, {columns, rows}) =
    if columns < 1 orelse rows < 1 then raise Size else
    let fun cell (i, j) =
          if i >= #height s orelse j >= #columns s then blank
          else if j = columns - 1 andalso j + 1 < #columns s
               andalso #text (Vector.sub (Vector.sub (#cells s, i), j + 1)) = "" then blank
          else Vector.sub (Vector.sub (#cells s, i), j)
    in {columns = columns, height = rows, policy = #policy s,
        cells = Vector.tabulate (rows, fn i => Vector.tabulate (columns, fn j => cell (i, j))),
        row = Int.min (#row s, rows - 1), col = Int.min (#col s, columns - 1), wrapPending = false,
        style = #style s, scrolled = #scrolled s, pending = #pending s,
        bracketedPaste = #bracketedPaste s, cursorVisible = #cursorVisible s} end

  fun row (s : screen, i) =
    let
      val r = Vector.sub (#cells s, i)
      fun last k = if k > 0 andalso Vector.sub (r, k - 1) = blank then last (k - 1) else k
    in
      List.tabulate (last (Vector.length r), fn k => Vector.sub (r, k))
    end

  fun text (s : screen) =
    let
      val lines = List.tabulate (#height s, fn i => String.concat (map #text (row (s, i))))
      fun trim [] = []
        | trim ("" :: rest) = (case trim rest of [] => [] | rest' => "" :: rest')
        | trim (l :: rest) = l :: trim rest
    in
      String.concatWith "\n" (trim lines)
    end

  (* SGR's parameters applied to a style: the style's own escape, then
     them *)
  fun applySgr (_, "") = Style.plain
    | applySgr (st, params) =
        let val e = Style.sgr st
        in Style.parameters (String.substring (e, 2, size e - 3) ^ ";" ^ params) end

  (* The bytes of a write are applied to a mutable copy of the screen; an
     escape or a character that the bytes end inside waits for the next
     write. *)
  fun write (s : screen, bytes) =
    if #pending s <> "" then
      write ({columns = #columns s, height = #height s, policy = #policy s, cells = #cells s,
              row = #row s, col = #col s, wrapPending = #wrapPending s, style = #style s,
              scrolled = #scrolled s, pending = "", bracketedPaste = #bracketedPaste s,
              cursorVisible = #cursorVisible s}, #pending s ^ bytes)
    else
    let
      val columns = #columns s
      val height = #height s
      val grid = Array.tabulate (height, fn i => Array.tabulate (columns, fn j => Vector.sub (Vector.sub (#cells s, i), j)))
      val r = ref (#row s)
      val c = ref (#col s)
      val wrap = ref (#wrapPending s)
      val style = ref (#style s)
      val scrolledBy = ref (#scrolled s)
      val paste = ref (#bracketedPaste s)
      val visible = ref (#cursorVisible s)
      fun put (i, j, cell) = Array.update (Array.sub (grid, i), j, cell)
      fun get (i, j) = Array.sub (Array.sub (grid, i), j)
      fun clamp (x, lo, hi) = Int.max (lo, Int.min (x, hi))
      fun blankRow () = Array.tabulate (columns, fn _ => blank)
      fun scroll () =
        let
          fun shift i = if i + 1 >= height then () else (Array.update (grid, i, Array.sub (grid, i + 1)); shift (i + 1))
        in
          shift 0;
          Array.update (grid, height - 1, blankRow ());
          scrolledBy := !scrolledBy + 1
        end
      fun lineFeed () = if !r + 1 >= height then scroll () else r := !r + 1
      (* a wide cluster that a write covers half of: its other half is blank *)
      fun clearAt (i, j) =
        if #text (get (i, j)) = "" andalso j > 0 then put (i, j - 1, blank)
        else if j + 1 < columns andalso #text (get (i, j + 1)) = "" then put (i, j + 1, blank)
        else ()
      fun printCluster cl =
        let val w = Int.min (Grapheme.width (#policy s) cl, 2)
        in
          if w = 0 then
            (* a cluster of no width joins the cell before it *)
            let val j = if !wrap then !c else !c - 1
            in
              if j >= 0 then let val cell = get (!r, j) in put (!r, j, {text = #text cell ^ cl, style = #style cell}) end
              else ()
            end
          else
            ((if !wrap orelse !c + w > columns then (c := 0; lineFeed ()) else ());
             wrap := false;
             clearAt (!r, !c);
             put (!r, !c, {text = cl, style = !style});
             (if w = 2 andalso !c + 1 < columns then (clearAt (!r, !c + 1); put (!r, !c + 1, {text = "", style = !style}))
              else ());
             if !c + w >= columns then (c := columns - 1; wrap := true) else c := !c + w)
        end
      fun eraseLine (from, to) =
        let fun go j = if j > to then () else (put (!r, j, blank); go (j + 1))
        in go (clamp (from, 0, columns)) end
      fun eraseRows (from, to) =
        let fun go i = if i > to then () else (Array.update (grid, i, blankRow ()); go (i + 1))
        in go (Int.max (from, 0)) end
      fun numbers p = map (fn f => getOpt (Int.fromString f, 0)) (String.fields (fn ch => ch = #";") p)
      fun first (p, default) = case numbers p of n :: _ => if n = 0 then default else n | [] => default
      fun mode p = if p = "" then 0 else hd (numbers p)
      fun csi (params, final) =
        (if Char.contains "mhl" final then () else wrap := false;
         case final of
           #"A" => r := clamp (!r - first (params, 1), 0, height - 1)
         | #"B" => r := clamp (!r + first (params, 1), 0, height - 1)
         | #"C" => c := clamp (!c + first (params, 1), 0, columns - 1)
         | #"D" => c := clamp (!c - first (params, 1), 0, columns - 1)
         | #"G" => c := clamp (first (params, 1) - 1, 0, columns - 1)
         | #"H" =>
             (case numbers params of
                a :: b :: _ => (r := clamp (Int.max (a, 1) - 1, 0, height - 1); c := clamp (Int.max (b, 1) - 1, 0, columns - 1))
              | [a] => (r := clamp (Int.max (a, 1) - 1, 0, height - 1); c := 0)
              | [] => (r := 0; c := 0))
         | #"K" =>
             (case mode params of
                0 => eraseLine (!c, columns - 1)
              | 1 => eraseLine (0, !c)
              | _ => eraseLine (0, columns - 1))
         | #"J" =>
             (case mode params of
                0 => (eraseLine (!c, columns - 1); eraseRows (!r + 1, height - 1))
              | 1 => (eraseRows (0, !r - 1); eraseLine (0, !c))
              | _ => eraseRows (0, height - 1))
         | #"m" => style := applySgr (!style, params)
         | #"h" => if params = "?2004" then paste := true else if params = "?25" then visible := true else ()
         | #"l" => if params = "?2004" then paste := false else if params = "?25" then visible := false else ()
         | _ => ())
      fun isText k = k < size bytes andalso Char.ord (String.sub (bytes, k)) >= 32
                     andalso Char.ord (String.sub (bytes, k)) <> 127
      (* the bytes from i; what is left unread at the end *)
      fun go i =
        if i >= size bytes then ""
        else
          let val b = Char.ord (String.sub (bytes, i))
          in
            if b = 27 then
              if i + 1 >= size bytes then String.extract (bytes, i, NONE)
              else if String.sub (bytes, i + 1) = #"[" then
                let
                  fun scan j =
                    if j >= size bytes then NONE
                    else
                      let val x = Char.ord (String.sub (bytes, j))
                      in if x >= 0x40 andalso x <= 0x7E then SOME j else scan (j + 1) end
                in
                  case scan (i + 2) of
                    NONE => String.extract (bytes, i, NONE)
                  | SOME j => (csi (String.substring (bytes, i + 2, j - i - 2), String.sub (bytes, j)); go (j + 1))
                end
              else if List.exists (fn c => c = String.sub (bytes, i + 1)) [#"]", #"P", #"^", #"_"] then
                let val osc = String.sub (bytes, i + 1) = #"]"
                    fun scan j =
                      if j >= size bytes then NONE
                      else if osc andalso String.sub (bytes, j) = #"\007" then SOME (j + 1)
                      else if String.sub (bytes, j) = #"\027" andalso j + 1 < size bytes andalso String.sub (bytes, j + 1) = #"\\" then SOME (j + 2)
                      else scan (j + 1)
                in case scan (i + 2) of NONE => String.extract (bytes, i, NONE) | SOME j => go j end
              else go (i + 2)
            else if b = 13 then (c := 0; wrap := false; go (i + 1))
            else if b = 10 then (lineFeed (); go (i + 1))
            else if b = 8 then (c := Int.max (0, !c - 1); wrap := false; go (i + 1))
            else if b = 9 then (c := Int.min (columns - 1, (!c div 8 + 1) * 8); wrap := false; go (i + 1))
            else if b < 32 orelse b = 127 then go (i + 1)
            else
              let
                (* the text up to the next escape or control *)
                fun stop k = if isText k then stop (k + 1) else k
                val e = stop i
                val run = String.substring (bytes, i, e - i)
                (* a UTF-8 character that the bytes end inside waits *)
                val n = size run
                fun cont k = let val x = Char.ord (String.sub (run, k)) in x >= 0x80 andalso x <= 0xBF end
                fun back k = if k > 0 andalso n - k < 3 andalso cont (k - 1) then back (k - 1) else k
                val lead = back n - 1
                fun need x = if x >= 0xC2 andalso x <= 0xDF then 2 else if x >= 0xE0 andalso x <= 0xEF then 3
                             else if x >= 0xF0 andalso x <= 0xF4 then 4 else 1
                val keep = if e = size bytes andalso lead >= 0 andalso n - lead < need (Char.ord (String.sub (run, lead)))
                           then lead else n
                val () = List.app printCluster (Grapheme.clusters (String.substring (run, 0, keep)))
              in
                if keep < size run then String.extract (run, keep, NONE) else go e
              end
          end
      val rest = go 0
    in
      {columns = columns, height = height, policy = #policy s,
       cells = Vector.tabulate (height, fn i => Array.vector (Array.sub (grid, i))),
       row = !r, col = !c, wrapPending = !wrap, style = !style, scrolled = !scrolledBy, pending = rest,
       bracketedPaste = !paste, cursorVisible = !visible}
    end
end
