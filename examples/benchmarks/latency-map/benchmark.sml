(* The message window as a persistent map: latency-ring's window held in an
   AVL tree keyed by message number instead of an array. A step inserts the
   newest message and, once the window is full, removes the oldest, copying
   the paths it changes. There is no mutation at all: every step allocates a
   path of O(log N) nodes, and the old paths die in the middle of what is
   old, which a copier copies and a collector that does not move must leave
   as holes.

   Arguments: N STEPS SIZE TIME, as latency-ring's. The result is N, STEPS,
   SIZE and the digest of every message in the order made (those removed,
   then the tree in order), the same as latency-ring's. *)
structure Benchmark =
struct
  val name = "latency-map"

  datatype tree = E | T of tree * int * Word8Array.array * tree * int

  fun height E = 0
    | height (T (_, _, _, _, h)) = h

  fun node (l, k, v, r) = T (l, k, v, r, 1 + Int.max (height l, height r))

  fun balance (l, k, v, r) =
    let
      val hl = height l
      val hr = height r
    in
      if hl > hr + 1 then
        (case l of
           T (ll, lk, lv, lr, _) =>
             if height ll >= height lr then node (ll, lk, lv, node (lr, k, v, r))
             else
               (case lr of
                  T (lrl, lrk, lrv, lrr, _) => node (node (ll, lk, lv, lrl), lrk, lrv, node (lrr, k, v, r))
                | E => raise Fail "unbalanced window")
         | E => raise Fail "unbalanced window")
      else if hr > hl + 1 then
        (case r of
           T (rl, rk, rv, rr, _) =>
             if height rr >= height rl then node (node (l, k, v, rl), rk, rv, rr)
             else
               (case rl of
                  T (rll, rlk, rlv, rlr, _) => node (node (l, k, v, rll), rlk, rlv, node (rlr, rk, rv, rr))
                | E => raise Fail "unbalanced window")
         | E => raise Fail "unbalanced window")
      else node (l, k, v, r)
    end

  fun insert (E, k, v) = node (E, k, v, E)
    | insert (T (l, k', v', r, h), k, v) =
        if k < k' then balance (insert (l, k, v), k', v', r)
        else if k > k' then balance (l, k', v', insert (r, k, v))
        else T (l, k, v, r, h)

  (* the least key's message, and the tree without it *)
  fun removeMin (T (E, _, v, r, _)) = (v, r)
    | removeMin (T (l, k, v, r, _)) =
        let val (m, l') = removeMin l in (m, balance (l', k, v, r)) end
    | removeMin E = raise Fail "empty window"

  fun inorder (E, acc) = acc
    | inorder (T (l, _, v, r, _), acc) = inorder (r, Latency.digest (v, inorder (l, acc)))

  fun window (n, steps, size, timing) =
    let
      fun push (i, t, acc) =
        let val t = insert (t, i, Latency.message (i, size))
        in
          if i >= n then
            let val (m, t) = removeMin t in (t, Latency.digest (m, acc)) end
          else (t, acc)
        end
      val total = n + steps
      val all = Latency.histogram ()
      val steady = Latency.histogram ()
      fun untimed (i, t, acc) =
        if i = total then (t, acc) else let val (t, acc) = push (i, t, acc) in untimed (i + 1, t, acc) end
      fun timed (i, t, acc) =
        if i = total then (t, acc)
        else
          let
            val t0 = Latency.now ()
            val (t, acc) = push (i, t, acc)
            val d = Latency.since t0
          in
            Latency.add (all, d);
            if i >= n then Latency.add (steady, d) else ();
            timed (i + 1, t, acc)
          end
      val ((t, acc), wall) =
        if timing then
          let val t0 = Latency.now () val r = timed (0, E, 0) in (r, Latency.since t0) end
        else (untimed (0, E, 0), 0)
    in
      (inorder (t, acc), all, steady, wall)
    end

  fun run [n, steps, size, time] =
        let
          val n = BenchInput.between (1, 100000000) (BenchInput.integer n)
          val steps = BenchInput.between (0, 1000000000) (BenchInput.integer steps)
          val size = BenchInput.between (1, 1048576) (BenchInput.integer size)
          val timing = BenchInput.between (0, 1) (BenchInput.integer time) = 1
          val (sum, all, steady, wall) = window (n, steps, size, timing)
          val result = String.concatWith " " (List.map Int.toString [n, steps, size, sum])
        in
          if timing then
            Latency.report (Latency.line (name ^ " " ^ result ^ " all", all)
                            ^ Latency.line (name ^ " " ^ result ^ " steady", steady)
                            ^ name ^ " " ^ result ^ " wall: " ^ Latency.ms wall ^ " ms\n")
          else ();
          result
        end
    | run _ = raise Fail "latency-map expects N STEPS SIZE TIME"
end
