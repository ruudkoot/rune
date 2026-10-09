(* What the collector's latency workloads share (latency-ring, latency-map and
   latency-static-map; docs/plans/garbage-collector-v2.md, The workloads):
   the messages of the window and their digest, a histogram of latencies in
   microseconds whose recording allocates nothing, and the clock. Each
   program times its own loop: a step passed to a shared loop as a function
   would be an unknown call, and its arguments a tuple allocated at every
   step.

   The histogram is HdrHistogram's idea in miniature: a fixed array of
   buckets, 1 us wide below 2 ms, 100 us wide below 2 s, 10 ms wide below
   120 s and one for everything longer, so that its size depends neither on
   the number of samples nor on the live data under test. A percentile is
   reported as the largest value its bucket holds (never more than the
   largest sample), so it is exact below 2 ms and at most 100 us high below
   2 s.

   The clock is read only when a program is asked to time itself, and then
   through Time.toReal: on Rune a LargeInt that is not small is an object, so
   Time.toMicroseconds would allocate whenever the clock had ticked far
   enough, and where the collections fall would depend on the timing. A real
   of this size is an immediate, and rounding a whole number of microseconds
   is exact.

   Every digest is taken modulo a prime under 2^24, so that no intermediate
   value reaches 2^30 and a 31-bit int (SML/NJ's on 32-bit) never overflows. *)
structure Latency =
struct
  val modulus = 16777213

  (* message i of SIZE bytes: i mod 251 throughout, then i mod 256 in the
     first byte and (i div 256) mod 256 in the last, in that order *)
  fun message (i, size) =
    let
      val m = Word8Array.array (size, Word8.fromInt (i mod 251))
    in
      Word8Array.update (m, 0, Word8.fromInt (i mod 256));
      Word8Array.update (m, size - 1, Word8.fromInt ((i div 256) mod 256));
      m
    end

  (* the digest so far, ACC, extended by message M: its first, middle and
     last byte and its size *)
  fun digest (m, acc) =
    let
      val size = Word8Array.length m
      val a = Word8.toInt (Word8Array.sub (m, 0))
      val b = Word8.toInt (Word8Array.sub (m, size div 2))
      val c = Word8.toInt (Word8Array.sub (m, size - 1))
    in
      (acc * 31 + a * 65536 + b * 256 + c + size) mod modulus
    end

  val exactEnd = 2000
  val midEnd = 2000000
  val midStep = 100
  val hiEnd = 120000000
  val hiStep = 10000
  val nMid = (midEnd - exactEnd) div midStep
  val nHi = (hiEnd - midEnd) div hiStep
  val buckets = exactEnd + nMid + nHi + 1

  type histogram = {counts : int array, max : int ref, total : int ref, sum : int ref}

  fun histogram () : histogram =
    {counts = Array.array (buckets, 0), max = ref 0, total = ref 0, sum = ref 0}

  fun index d =
    if d < exactEnd then (if d < 0 then 0 else d)
    else if d < midEnd then exactEnd + (d - exactEnd) div midStep
    else if d < hiEnd then exactEnd + nMid + (d - midEnd) div hiStep
    else buckets - 1

  (* the largest value bucket i holds *)
  fun upper i =
    if i < exactEnd then i
    else if i < exactEnd + nMid then exactEnd + (i - exactEnd + 1) * midStep - 1
    else if i < buckets - 1 then midEnd + (i - exactEnd - nMid + 1) * hiStep - 1
    else hiEnd

  fun add ({counts, max, total, sum} : histogram, d) =
    let val i = index d
    in
      Array.update (counts, i, Array.sub (counts, i) + 1);
      if d > !max then max := d else ();
      total := !total + 1;
      sum := !sum + d
    end

  (* the value under which num/den of the samples fall *)
  fun percentile ({counts, max, total, ...} : histogram, num, den) =
    if !total = 0 then 0
    else
      let
        val rank = Int.max (1, (!total * num + den - 1) div den)
        fun go (i, seen) =
          if i >= buckets then !max
          else
            let val seen = seen + Array.sub (counts, i)
            in if seen >= rank then Int.min (upper i, !max) else go (i + 1, seen) end
      in go (0, 0) end

  (* the samples above d microseconds *)
  fun above ({counts, ...} : histogram, d) =
    let fun go (i, n) = if i >= buckets then n else go (i + 1, n + Array.sub (counts, i))
    in go (index d + 1, 0) end

  (* N (from 0) in WIDTH digits, with PAD before its first digit: one
     string, of the same length whatever N is, so that what a report
     allocates does not depend on the times it reports and --count stays
     exact when a program times itself *)
  fun digits (n, width, pad) =
    let
      fun power 0 = 1
        | power k = 10 * power (k - 1)
    in
      CharVector.tabulate (width, fn k =>
        let val p = power (width - 1 - k)
        in if n < p andalso k < width - 1 then pad else Char.chr (48 + n div p mod 10) end)
    end

  fun count n = digits (n, 10, #" ")

  (* microseconds as milliseconds, with three decimals *)
  fun ms us = digits (us div 1000, 6, #" ") ^ "." ^ digits (us mod 1000, 3, #"0")

  (* one line: the label, the samples, the mean, percentiles and maximum in
     ms, and the samples over 1, 10 and 100 ms *)
  fun line (label, h as {max, total, sum, ...} : histogram) =
    label ^ ": " ^ count (!total) ^ " samples, mean "
    ^ ms (if !total = 0 then 0 else !sum div !total)
    ^ " ms, p50 " ^ ms (percentile (h, 1, 2))
    ^ " ms, p90 " ^ ms (percentile (h, 9, 10))
    ^ " ms, p99 " ^ ms (percentile (h, 99, 100))
    ^ " ms, p99.9 " ^ ms (percentile (h, 999, 1000))
    ^ " ms, p99.99 " ^ ms (percentile (h, 9999, 10000))
    ^ " ms, max " ^ ms (!max)
    ^ " ms; over 1 ms " ^ count (above (h, 1000))
    ^ ", over 10 ms " ^ count (above (h, 10000))
    ^ ", over 100 ms " ^ count (above (h, 100000)) ^ "\n"

  fun now () = Time.now ()

  (* the microseconds since t0 *)
  fun since t0 = Real.round (Time.toReal (Time.- (Time.now (), t0)) * 1000000.0)

  fun report text = TextIO.output (TextIO.stdErr, text)
end
