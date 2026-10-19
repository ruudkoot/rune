(* A large static map and requests that make garbage: the collector's pause
   against the size of what is live when nothing that is old changes.

   The map is a perfectly balanced tree of ENTRIES keys, each with a string
   of VLEN bytes, built once without garbage and never changed (at VLEN 100
   an entry is about 155 bytes, so 1,300,000 entries are about 200 MB live).
   Then REQUESTS requests, each of which draws LOOKUPS keys from a
   deterministic generator, concatenates their strings into a response, and
   folds a list of GARBAGE triples made from the response: about LOOKUPS *
   VLEN + GARBAGE * 56 bytes a request, none of which outlives it. A copier
   copies the whole map at every collection; a nursery need not touch it.

   Arguments: ENTRIES VLEN REQUESTS LOOKUPS GARBAGE TIME. TIME 1 times every
   request and writes their histogram and the time the build took to the
   standard error; TIME 0 reads no clock. The result is the size of the map
   (counted after the last request, so the map is live to the end),
   REQUESTS, and the digest of every response. *)
structure Benchmark =
struct
  val name = "latency-static-map"

  datatype tree = E | T of tree * int * string * tree

  (* Park and Miller's multiplier 16807 by Schrage's method, modulo the
     prime 1073741789 instead of 2^31 - 1, so that no intermediate value
     reaches 2^30 *)
  fun random seed =
    let
      val t = 16807 * (seed mod 63886) - 9787 * (seed div 63886)
    in
      if t > 0 then t else t + 1073741789
    end

  (* key k's string: VLEN letters from the (k mod 26)th on, each a copy out
     of one string made once *)
  fun letters vlen = CharVector.tabulate (vlen + 26, fn j => Char.chr (97 + j mod 26))
  fun value (base, k, vlen) = String.substring (base, k mod 26, vlen)

  (* the keys lo to hi - 1, balanced *)
  fun build (base, lo, hi, vlen) =
    if lo >= hi then E
    else
      let val mid = lo + (hi - lo) div 2
      in T (build (base, lo, mid, vlen), mid, value (base, mid, vlen), build (base, mid + 1, hi, vlen)) end

  fun find (E, _) = raise Fail "missing key"
    | find (T (l, k', v, r), k) =
        if k < k' then find (l, k) else if k > k' then find (r, k) else v

  fun count E = 0
    | count (T (l, _, _, r)) = count l + 1 + count r

  (* one request from SEED: the generator's next seed and the response's
     digest *)
  fun request (map, entries, lookups, garbage, seed) =
    let
      fun draw (0, seed, found) = (seed, found)
        | draw (j, seed, found) =
            let val seed = random seed
            in draw (j - 1, seed, find (map, seed mod entries) :: found) end
      val (seed, found) = draw (lookups, seed, [])
      val response = String.concat found
      val size = String.size response
      fun records (0, acc) = acc
        | records (j, acc) =
            let val c = Char.ord (String.sub (response, (j * 7919) mod size))
            in records (j - 1, (j, c, size - j) :: acc) end
      val sum = List.foldl (fn ((a, b, c), s) => (s + a * b + c) mod Latency.modulus) 0 (records (garbage, []))
    in
      (seed, (sum + size) mod Latency.modulus)
    end

  fun run [entries, vlen, requests, lookups, garbage, time] =
        let
          val entries = BenchInput.between (1, 100000000) (BenchInput.integer entries)
          val vlen = BenchInput.between (1, 65536) (BenchInput.integer vlen)
          val requests = BenchInput.between (0, 1000000000) (BenchInput.integer requests)
          val lookups = BenchInput.between (1, 1000) (BenchInput.integer lookups)
          val garbage = BenchInput.between (0, 100000) (BenchInput.integer garbage)
          val timing = BenchInput.between (0, 1) (BenchInput.integer time) = 1
          val t0 = if timing then SOME (Latency.now ()) else NONE
          val map = build (letters vlen, 0, entries, vlen)
          val built = case t0 of SOME t0 => Latency.since t0 | NONE => 0
          val all = Latency.histogram ()
          fun untimed (0, _, acc) = acc
            | untimed (j, seed, acc) =
                let val (seed, d) = request (map, entries, lookups, garbage, seed)
                in untimed (j - 1, seed, (acc * 31 + d) mod Latency.modulus) end
          fun timed (0, _, acc) = acc
            | timed (j, seed, acc) =
                let
                  val t0 = Latency.now ()
                  val (seed, d) = request (map, entries, lookups, garbage, seed)
                in
                  Latency.add (all, Latency.since t0);
                  timed (j - 1, seed, (acc * 31 + d) mod Latency.modulus)
                end
          val (sum, wall) =
            if timing then
              let val t0 = Latency.now () val sum = timed (requests, 42, 0) in (sum, Latency.since t0) end
            else (untimed (requests, 42, 0), 0)
          val result = String.concatWith " " (List.map Int.toString [count map, requests, sum])
        in
          if timing then
            Latency.report (Latency.line (name ^ " " ^ result ^ " requests", all)
                            ^ name ^ " " ^ result ^ " build: " ^ Latency.ms built ^ " ms, requests wall: "
                            ^ Latency.ms wall ^ " ms\n")
          else ();
          result
        end
    | run _ = raise Fail "latency-static-map expects ENTRIES VLEN REQUESTS LOOKUPS GARBAGE TIME"
end
