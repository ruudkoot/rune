# SML/NJ 110.99.9 and 2026.2: `canInput` loses input when it has to read more than one chunk, and undercounts what it found

## Status: not reported

The issue trackers of smlnj/legacy and smlnj/smlnj have nothing on
`canInput` (searched 2026-10-11). `IO/text-io-fn.sml` and
`IO/bin-io-fn.sml` have the same `canInput` in 110.99.9, in smlnj/legacy at
`6ed5a0a` (2026-09-13) and in smlnj/smlnj at `17362d2` (2026-09-24), so
2026.3 has it too (by reading the code).

**What is worth sending SML/NJ:** a new issue on smlnj/legacy, with
`bug.sml` and `fix.diff` (`upstream.md` is the text).

## Summary

* **The trigger:** `TextIO.canInput (f, n)` or `BinIO.canInput (f, n)`, or
  `StreamIO.canInput (s, n)` of either, when `canInput` has to read from
  the reader twice or more to look at `n` elements: `n` more than what is
  buffered plus one chunk of the reader. For `TextIO.openString "ab"` (one
  chunk of 2) that is any `n` above 2; for a file, more than about a block
  (4,096 here) beyond the buffer.
* **What goes wrong:**
  - **Input is lost.** Each chunk read after the first is linked to the
    stream's first buffer in place of the one before it, so every chunk
    but the last one read is dropped: after
    `canInput (TextIO.openString "ab", 5)`, which says `SOME 2`, `input`
    gives `""`; after `canInput (f, 6000)` on a file of 10,000 characters,
    `inputAll f` gives the last 5,904. The functional `StreamIO.canInput`
    loses them too, from a stream value that should not change.
  - **The count is short.** When the elements span chunks and enough are
    found, the result is what was still missing at the last chunk, not
    `n`: `SOME 1904` for the file, where 6,000 were read.
* **Required behaviour:** the
  [Basis `STREAM_IO` specification](https://smlfamily.github.io/Basis/stream-io.html#SIG:STREAM_IO.canInput:VAL)
  (and `IMPERATIVE_IO`'s): `canInput (f, n)` "returns `SOME(k)`, where
  `0 <= k <= n`, if a call to input would return immediately with at least
  `k` characters. Note that `k = 0` corresponds to the stream being at
  end-of-stream." Its implementation note asks for "as large a k as
  possible", and of the lookahead: "Such a lookahead commits the stream to
  the characters read by `readVecNB` ... The only requirement is that any
  future call of `input` on the same input stream must return the same
  vector of elements." MLton, Poly/ML, MLKit and Rune keep the input
  (`input` gives `"ab"`).

## Where it happens

| Build | wrong of 6 |
|---|---|
| 110.99.9, 64-bit | 5 |
| 110.99.9, 32-bit | 5 |
| 2026.2 (64-bit) | 5 |
| `fix.diff`, as a standalone copy (`fix-check.sml`) | 0 |

```
$ sml bug.sml                           # 110.99.9 (32 or 64 bits) or 2026.2
openString "ab": canInput (f, 2), input f = SOME 2, "ab", expected SOME 2, "ab": ok
openString "ab": canInput (f, 5), input f = SOME 2, "", expected SOME 2, "ab": WRONG
openString "ab": canInput (f, 3), inputAll f = SOME 2, "", expected SOME 2, "ab": WRONG
StreamIO: canInput (s, 5), input s = SOME 2, "", expected SOME 2, "ab": WRONG
BinIO, 2 bytes: canInput (g, 5), input g = SOME 2, 0 bytes, expected SOME 2, 2 bytes: WRONG
file of 10000 characters: canInput (f, 6000), inputAll f = SOME 1904, 5904 characters, expected SOME 6000, 10000 characters: WRONG
```

(The last line depends on the chunk size of a file reader, here 4,096.)
After `BinIO.canInput (g, 5)` on the two bytes, `BinIO.StreamIO.canInput
(BinIO.getInstream g, 5)` is `SOME 0`: the stream is at its end.

## The cause

`canInput` in `base/system/Basis/Implementation/IO/text-io-fn.sml` (and the
same lines in `bin-io-fn.sml`):

```sml
	fun canInput (strm as ISTRM(buf, pos), amount) = let
	      ...
	      fun tryInput (buf as IBUF{data, ...}, i, n) = let
		    val len = V.length data
		    val remain = len - i
		    in
		      if (remain >= n)
			then SOME n
			else nextBuf (buf, n - remain)
		    end
	      and nextBuf (IBUF{more, ...}, n) = (case !more
		     of (MORE buf) => tryInput (buf, 0, n)
		      | (EOS _) => SOME(amount - n)
		      | TERMINATED => SOME(amount - n)
		      | NOMORE => ((
			  case extendStream (readVecNB, "canInput", buf)
			   of (MORE b) => tryInput (b, 0, n)
			    | _ => SOME(amount - n)
			  (* end case *))
			    handle IO.Io{cause=WouldBlock, ...} => SOME(amount - n))
		    (* end case *))
```

* **The lost input.** `nextBuf`'s pattern does not bind `buf`, so the
  `buf` it passes to `extendStream` is `canInput`'s argument, the stream's
  first buffer, not the last buffer of the chain. `extendStream` reads a
  chunk and sets the `more` field of the buffer it is given: the second
  read links its chunk to the first buffer, in place of the chunk that the
  first read linked there, and that chunk is gone. With `"ab"`, the first
  read gets `"ab"`, the second gets the end of the stream and puts `EOS`
  where `"ab"` was. (`inputN`'s `nextBuf`, a few lines above, binds
  `buf as IBUF{...}` and passes the right one.)
* **The count.** `n` is what remains of `amount` to be found from buffer
  `buf`, so when the buffer has it, all of `amount` has been found; the
  result should be `SOME amount`, not `SOME n`. The two agree only in the
  first buffer that has data.

## The fix

`fix.diff` (against smlnj/legacy `6ed5a0a`; it also applies to 110.99.9,
and to smlnj/smlnj with `git apply -p2`) makes the same two changes in
both functors: `nextBuf (buf as IBUF{more, ...}, n)`, and `SOME amount`
when the buffer has what remains.

**How it was tested:** SML/NJ was not rebuilt. `fix-check.sml` holds the
functional input streams of `text-io-fn.sml` (from the `instream` type to
`mkInstream`, with only the cleaner registry stubbed) twice, as they are
(`Old`) and with the fix (`New`), and runs both over real readers on
110.99.9 (32 and 64 bits) and 2026.2:
* `Old` loses the input exactly as the Basis does (`""` after
  `canInput (s, 5)` of `"ab"`; 5,904 of a file's 10,000 characters after
  `canInput (s, 6000)`, which says `SOME 1904`);
* `New` keeps it all and says `SOME 6000`;
* on 10,000 random strings, chunk sizes and sequences of `canInput`,
  `input1` and `input` over readers that never block, `New` reads back
  every string and `canInput (s, n)` is always `SOME (min (n, what is
  left))`; `Old` loses input in about 80% of them.

`BinIO`'s copy of the code is the same and was not run separately.

## How Rune met it

By the laws of Rune's Basis Library documentation: each `Law:` is tested
on generated values, and `tests/basis/run-laws-hosts.py` runs them against
the Basis Library of the other compilers (`docs/plans/quickcheck-hunt.md`,
the sections on the other compilers). The law of `IMPERATIVE_IO.canInput`
in `lib/basis/sig_imperative_io.sml`, `(case canInput (f, n) of SOME k =>
k <= n andalso List.all isSome (List.tabulate (k, fn _ => input1 f)) |
NONE => true)`, fails on SML/NJ: after `SOME 2`, `input1` finds nothing.
