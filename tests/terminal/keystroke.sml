(* What a keystroke costs lib/terminal's editor at 10, 100 and 1,000
   lines of input (docs/plans/repl.md, M5: under 16 ms at 1,000): the
   step, the layout of the whole input at 80 columns, the 24 rows a
   terminal shows of it, and the diff from the frame before -- what
   LineEdit.readLine does for a key -- for keys typed at the end and in
   the middle. scripts/perf-repl.sh runs it; it prints the median and the
   worst in milliseconds. *)
structure L = LineEditFn (structure Device = PosixTerminal)

fun ms t = Real.fromLargeInt (Time.toMicroseconds t) / 1000.0

fun lines n = String.concatWith "\n" (List.tabulate (n, fn i => "val x" ^ Int.toString i ^ " = List.map (fn y => y + " ^ Int.toString i ^ ") xs"))

fun window ({rows, cursor = (r, c)} : L.frame) =
  let
    val n = Vector.length rows
    val top = Int.max (0, Int.min (r - 23, n - 24))
    val shown = Int.min (24, n - top)
  in
    {rows = VectorSlice.vector (VectorSlice.slice (rows, top, SOME shown)), cursor = (r - top, c)} : L.frame
  end

fun measure (n, keys) =
  let
    val s0 = L.start (Vector.fromList [], lines n)
    val f0 = window (L.layout (L.defaults, s0, 80))
    fun go ([], _, _, acc) = acc
      | go (k :: rest, s, f, acc) =
          let
            val t = Time.now ()
            val (s, _) = L.step (L.defaults, s, k)
            val f' = window (L.layout (L.defaults, s, 80))
            val (bytes, _) = L.diff {old = SOME f, new = f', columns = 80, drawn = 24}
            val d = ms (Time.- (Time.now (), t))
          in
            go (rest, s, f', (d, size bytes) :: acc)
          end
    val got = go (keys, s0, f0, [])
  in
    got
  end

fun sorted (xs : real list) =
  let
    fun insert (x, []) = [x]
      | insert (x, y :: ys) = if x <= y then x :: y :: ys else y :: insert (x, ys)
  in
    foldl insert [] xs
  end

fun report (label, n, keys) =
  let
    val got = measure (n, keys)
    val ts = sorted (map #1 got)
    val median = List.nth (ts, List.length ts div 2)
    val worst = List.last ts
    val bytes = foldl (fn ((_, b), m) => Int.max (m, b)) 0 got
  in
    print (StringCvt.padRight #" " 40 ("a keystroke " ^ label ^ ", " ^ Int.toString n ^ " lines")
           ^ StringCvt.padLeft #" " 8 (Real.fmt (StringCvt.FIX (SOME 2)) median) ^ " ms (worst "
           ^ Real.fmt (StringCvt.FIX (SOME 2)) worst ^ ", at most " ^ Int.toString bytes ^ " bytes)\n")
  end

val typing = List.tabulate (30, fn i => Key.Char (97 + i mod 26, Key.none))
val middle = Key.Named (Key.PageUp, Key.none) :: List.tabulate (12, fn _ => Key.Named (Key.Down, Key.none)) @ typing
val () = List.app (fn n => (report ("at the end", n, typing); report ("in the middle", n, middle))) [10, 100, 1000]
