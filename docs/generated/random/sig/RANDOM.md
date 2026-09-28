# signature RANDOM

[Random numbers](../README.md) &rsaquo; Random numbers &rsaquo; **RANDOM**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 13 of 13 entries documented |
| Tests | not listed |
| Source | [lib/random/random\_sig.sml](../../../../lib/random/random_sig.sml) |

## Synopsis

```sml
signature RANDOM
structure Random :> RANDOM
```

| Implementation |  | Source |
| --- | --- | --- |
| [`Random`](../str/Random.md) |  | [lib/random/random.sml](../../../../lib/random/random.sml) |

Pseudo-random numbers: SplitMix64, a generator that can be split into two
independent ones and read as a hash of a counter.

A generator is a value, not a place: every draw returns the next
generator beside the number, and the same generator always gives the same
numbers. [`split`](#val-split) makes two generators from one, for parts of a
computation that draw independently. The numbers are those of Vigna's
splitmix64.c and of Java's `SplittableRandom` (Steele, Lea and Flood,
"Fast splittable pseudorandom number generators", OOPSLA 2014). They are
good for testing and simulation, and no good for secrets.

## Interface

<pre>
signature RANDOM =
sig
  type <a href="#type-gen">gen</a>
  val <a href="#val-fromseed">fromSeed</a> : Word64.word -&gt; gen
  val <a href="#val-fromentropy">fromEntropy</a> : unit -&gt; gen
  val <a href="#val-split">split</a> : gen -&gt; gen * gen
  val <a href="#val-word64">word64</a> : gen -&gt; Word64.word * gen
  val <a href="#val-below">below</a> : Word64.word -&gt; gen -&gt; Word64.word * gen
  val <a href="#val-int">int</a> : int * int -&gt; gen -&gt; int * gen
  val <a href="#val-real">real</a> : gen -&gt; real * gen
  val <a href="#val-bool">bool</a> : gen -&gt; bool * gen
  val <a href="#val-hash">hash</a> : Word64.word -&gt; Word64.word
  val <a href="#val-hashstring">hashString</a> : string -&gt; Word64.word
  val <a href="#val-tostring">toString</a> : gen -&gt; string
  val <a href="#val-fromstring">fromString</a> : string -&gt; gen option
end
</pre>

### <a name="type-gen"></a>`gen`

```sml
type gen
```

A generator: a seed and an odd increment, the gamma.

### <a name="val-fromseed"></a>`fromSeed`

```sml
val fromSeed : Word64.word -> gen
```

`fromSeed s` is the generator of the seed `s`, with the gamma of
splitmix64.c, so that it draws the numbers that program draws from
`s`.

**Example** `#1 (word64 (fromSeed 0w0)) = 0wxE220A8397B1DCDAF`

### <a name="val-fromentropy"></a>`fromEntropy`

```sml
val fromEntropy : unit -> gen
```

`fromEntropy ()` is a generator seeded afresh at every call.

The seed is the operating system's random bytes (/dev/urandom) where
there are any, and the clock otherwise. A test that must be repeated
takes [`fromSeed`](#val-fromseed) instead.

### <a name="val-split"></a>`split`

```sml
val split : gen -> gen * gen
```

`split g` is two generators whose numbers are independent of each other.

The first is `g` moved on, the second a new one with a gamma of its own,
as Java's SplittableRandom.split makes it.

### <a name="val-word64"></a>`word64`

```sml
val word64 : gen -> Word64.word * gen
```

`word64 g` is the next number of `g`, uniform over all 64-bit words,
and the generator after it.

### <a name="val-below"></a>`below`

```sml
val below : Word64.word -> gen -> Word64.word * gen
```

`below n g` is a number uniform in `[0, n)` and the generator after
it, by Lemire's multiplication with rejection, which divides only when
it must.

**Raises** [`Domain`](../../basis/sig/GENERAL.md#exn-domain) if `n` is zero.

**Law** `#1 (below n g) < n = true` for `n <> 0w0`

**Example** `#1 (below 0w1 (fromSeed 0w3)) = 0w0`

### <a name="val-int"></a>`int`

```sml
val int : int * int -> gen -> int * gen
```

`int (lo, hi) g` is an integer uniform in `[lo, hi]`, and the generator
after it.

**Raises** [`Domain`](../../basis/sig/GENERAL.md#exn-domain) if `hi < lo`.

**Example** `let val (d, _) = int (1, 6) (fromSeed 0w7) in 1 <= d andalso d <= 6 end`

### <a name="val-real"></a>`real`

```sml
val real : gen -> real * gen
```

`real g` is a real uniform in `[0, 1)`, a multiple of `2^~53`, and the
generator after it.

**Example** `let val (x, _) = real (fromSeed 0w1) in 0.0 <= x andalso x < 1.0 end`

### <a name="val-bool"></a>`bool`

```sml
val bool : gen -> bool * gen
```

`bool g` is `true` or `false`, each half the time, and the generator
after it.

### <a name="val-hash"></a>`hash`

```sml
val hash : Word64.word -> Word64.word
```

`hash w` is SplitMix64's finaliser of `w`, a bijection of the 64-bit words.

It mixes every bit into every other. `hash (s + k * g)` for a counter `k`
is the generator read at `k`: that is how a tree of generators is read
without splitting.

**Example** `hash 0w0 = 0w0`

### <a name="val-hashstring"></a>`hashString`

```sml
val hashString : string -> Word64.word
```

`hashString s` is a 64-bit hash of the characters of `s`, for a seed
named by a string. It is not a cryptographic hash.

**Example** `hashString "a" <> hashString "b"`

### <a name="val-tostring"></a>`toString`

```sml
val toString : gen -> string
```

`toString g` is the seed and the gamma of `g` in hexadecimal, with a
colon between them: a token from which [`fromString`](#val-fromstring) makes `g` again.

**Example** `toString (fromSeed 0w0) = "0000000000000000:9E3779B97F4A7C15"`

### <a name="val-fromstring"></a>`fromString`

```sml
val fromString : string -> gen option
```

`fromString s` is the generator of a token of [`toString`](#val-tostring), or `NONE`
when `s` is none: two hexadecimal numbers with a colon between them,
the second odd.

**Law** `Option.map toString (fromString (toString g)) = SOME (toString g)`

**Example** `not (isSome (fromString "12:34"))`, for the gamma is even

---

<sub>Generated by runedoc from lib/random/random\_sig.sml; do not edit.</sub>
