# The types of the Basis: what was decided

A review document for the owner, written 2026-09-21 on branch `docgen`, after
the sealing of the Basis structures (the decisions of 2026-09-21 in
[docgen.md](docgen.md)).

**Everything below has been decided and carried out.** The owner chose: seal
the monomorphic families; seal the byte vector with the merged group; relabel
2A and 2B, which the specification requires; follow MLton on `Array2`; and
let `Int` and `Word` be no `Int<N>` or `Word<N>`, so that the VM may choose
their width. What the counts came to:

| | before the sealing | now |
| --- | ---: | ---: |
| abstract in the specification (leaks) | 47 | **0** |
| types that show what they are made of | 64 | **0** |
| the implementation's choice | 33 | **20** |
| required by the signature | 226 | 348 |
| structures showing names beyond their signature | 40 | **0** |

The twenty that are left are `Position.int` (an `int`), the reals
(`Real64` and `LargeReal` are `Real`, with their five monomorphic families)
and `LargeWord` with `SysWord` (which are `Word`, with `LargeWord`'s five
families). The specification allows each. One consequence to note:
**`LargeWord` being `Word` pins the VM's word to at least 64 bits**, because
`LargeWord.word` must be the largest word type and `Word64` exists. Giving
the VM freedom below 64 needs `LargeWord` to become `Word64`, which means
declaring the largest word before `Word` in `word.sml` with a signature
written out by hand, since `WORD` itself names `LargeWord.word` and cannot
come first. That is a contained change and has not been made.

The rest of this document is the evidence the decisions were taken on. It
holds three things:

1. what the network and position change did (done, on the branch);
2. every equality that `docs/generated/basis/types.md` calls **the
   implementation's choice**, with what the specification says, what the
   three hosts do, and a recommendation for each;
3. the measured cost of making `Word8Vector.vector` and the monomorphic
   vectors and arrays abstract, with a module restructure that removes almost
   all of it.

Sections 2 and 3 record the evidence; everything they recommend has since been carried out.

## Where the numbers come from

* Type identities on the hosts were probed by compiling `fun f (x : A) : B = x`
  with MLton 20210117, SML/NJ 110.99 and Poly/ML 5.9 on this machine. "same"
  means it compiles, "no" means the host rejects it (a type error), except
  where noted that the structure is absent.
* Run-time costs are `runevm --count`: instructions executed and bytes and
  objects allocated. They do not depend on the machine or its load, so a
  difference of 26 instructions is a real difference and not noise.
* The specification is quoted from the pages of
  <https://smlfamily.github.io/Basis/>.

## 1. Done: the network and position types

`types.md` counted 7 types that the specification keeps abstract and the
library showed. Five are now abstract, and the two that are left are the
subject of section 3.

| Type | How |
| --- | --- |
| `NetHostDB.in_addr`, `NetHostDB.addr_family`, `Socket.SOCK.sock_type` | a new `lib/basis/runenet.sml` declares all three in one opaque structure with the conversions the library needs. `socket.sml` is compiled before `netdb.sml`, so neither file could be the one that declares them, and `SOCKET` says `AF.addr_family` is `NetHostDB`'s. |
| `TextPrimIO.pos`, `WideTextPrimIO.pos` | a new `lib/basis/runepos.sml` declares `RuneTextPos` and `RuneWideTextPos`, two abstract types (nothing says a position in a stream of wide characters is one of a stream of characters). `RuneStreamIOFn` no longer demands `pos = int`; it takes `advance : pos * int -> pos`, which is the only arithmetic it did. |

The public `StreamIO` functor no longer constrains `PrimIO.pos` either: with
no way to count in a position it puts the reader back at the start of the
chunk, reads the elements again and asks where it is, as MLton's does, and
raises `Io` with `RandomAccessNotSupported` for a reader that cannot. That
deviation is gone.

Three programs of `tests/lang` and one check of `tests/basis` were written
against the leak and now go through `NetHostDB.fromString`/`toString` and
through a reader's positions.

**One thing to know before keeping this.** All three hosts have
`TextPrimIO.pos = Position.int`:

| | MLton | SML/NJ | Poly/ML |
| --- | --- | --- | --- |
| `TextPrimIO.pos` = `Position.int` | same | same | same |
| `NetHostDB.in_addr` = `string` | no | no | no |
| `Socket.SOCK.sock_type` = `int` | no | no | no |

So on the network types Rune has joined the hosts, and on the text positions
it is now stricter than all three. That is what the specification says, and it
is what the decision asks for, but a program that compiles everywhere else may
stop compiling here. Reverting the position half is a two-line change if you
would rather follow the hosts.

## 2. The implementation's choice: 37 equalities (now 20)

Five structures were invisible to `types.md` until now, because they are plain
aliases with no `Implements:` claim: `Real64`, `LargeWord`, `SysWord`,
`FixedInt` and `Position`. They now carry a claim, and the suite matches each
against the specification's signature, so the table below is complete. That is
why the count is 37 and not 33.

### A. `WideText`: 18 names — relabel, do not change

`WideText.Char.char`, `WideText.String.char`, `WideText.CharArray.elem`,
`WideText.Substring.char`, `WideText.CharVector.elem`,
`WideText.CharArraySlice.elem`, `WideText.CharVectorSlice.elem`,
`WideText.CharArraySlice.slice`, `WideText.Char.string`,
`WideText.String.string`, `WideText.CharArray.vector`,
`WideText.Substring.string`, `WideText.CharVector.vector`,
`WideText.CharArraySlice.vector`, `WideText.CharVectorSlice.vector`,
`WideText.Substring.substring`, `WideText.CharVectorSlice.slice`,
`WideText.CharArraySlice.vector_slice`.

The specification declares

```
structure WideText :> TEXT           (* OPTIONAL *)
  where type Char.char = WideChar.char
  where type String.string = WideString.string
  ...
```

so every one of these is **required by the signature**, not a choice. They are
labelled as a choice only because the `Implements:` claim of
`lib/basis/widetext.sml` says `TEXT` and stops there, while `Text`'s claim
spells its constraints out. `tests/basis/widetext_sig.sml` already checks them.

**Recommendation:** write the constraints into the claim of `widetext.sml`.
One comment; no code changes; 18 names move to "required by the signature".

### B. `LargeInt.int` = `IntInf.int` — relabel, do not change

The INTEGER page: *"If an implementation provides the `IntInf` structure, then
`LargeInt` must be the same structure as `IntInf`."* Required, and all three
hosts agree.

**Recommendation:** claim `INTEGER where type int = IntInf.int` in
`intinf.sml`. One name moves.

### C–I. The scalar aliases: 9 names — keep

| Name | Is | Specification | MLton | SML/NJ | Poly/ML | Recommendation |
| --- | --- | --- | --- | --- | --- | --- |
| `LargeReal.real` | `real` | *"If `LargeReal` is not the same as `Real`, then there must be a structure `Real<N>` equal to `LargeReal`"* — may be the same | same | same | same | **Keep.** `Real` is the only real type here; a second one would be the same 64 bits with conversions on every `toLarge`. |
| `Real64.real` | `real` | silent on `Real64` | same | same | absent | **Keep.** Same 64-bit double. |
| `LargeWord.word` | `word` | *"If `LargeWord` is not the same as `Word` ..."* — may be the same | no | no | no | **Keep, knowing the cost.** Rune's `Word` is 64 bits, so it already is the largest. The hosts differ because their default word is 31 or 63 bits; a program that relies on `LargeWord.word = word` will not compile there. Splitting them means a second word type and a conversion in `Word8.toLarge`, `Word.toLarge`, `PackWord*`, `Posix` and `BIT_FLAGS` — real cost, no gain. |
| `SysWord.word` | `word` | optional; *"large enough to hold any unsigned integral value used by the underlying system"* | no | no | no | **Keep**, as `LargeWord`. |
| `Word64.word` | `word` | silent | no | no | no | **Keep.** Every operation of a distinct `Word64` would convert to `word` and back for the same bits. |
| `Int64.int` | `int` | silent | no | no | no | **Keep.** The same, for integers. All three hosts keep them apart because their default `int` is not 64 bits; Rune's is. |
| `FixedInt.int` | `int` | optional; *"the largest fixed precision integer supported"* | — | — | — | **Keep.** `Int` is that integer here. |
| `Position.int` | `int` | required; nothing fixes its size | — | — | — | **Keep.** A file offset is an `int` on the VM. |

The honest summary of this block: Rune's `int` and `word` are 64 bits, which
makes `Int64`, `Word64`, `FixedInt`, `Position`, `LargeWord`, `SysWord`,
`LargeReal` and `Real64` the same types as `Int`, `Word` and `Real` by
arithmetic and not by laziness. Keeping them apart would cost conversions on
every operation and buy nothing but a stricter type checker. `types.md`
flagging them is the right outcome: it warns a reader without costing a
program anything.

### J. The slices that follow: 10 names — keep

`Int64ArraySlice.slice` = `IntArraySlice.slice`, `Int64VectorSlice.slice`,
`Real64ArraySlice.slice`, `LargeRealArraySlice.slice`,
`Real64VectorSlice.slice`, `LargeRealVectorSlice.slice`,
`Word64ArraySlice.slice`, `LargeWordArraySlice.slice`,
`Word64VectorSlice.slice`, `LargeWordVectorSlice.slice`.

These are consequences of C–I: if `Int64.int` is `int`, then the monomorphic
family of `Int64` is that of `Int`, and `lib/basis/mono_int64.sml` says so in
one line each. Splitting them means five whole duplicate families.

**Recommendation:** keep.

### What section 2 comes to

Taking A and B moves 19 of the 37 names to "required by the signature", which
is where they belong, and leaves 18 that are genuinely this implementation's
choice and are worth a reader's attention. No library code changes.

## 3. `Word8Vector.vector` = `string`, and the monomorphic families

Two lists are at issue:

* the **2 remaining leaks**: `Word8Vector.vector` is `string` and
  `Word8VectorSlice.slice` is `substring`;
* the **56 types that show what they are made of**, of which 54 are the
  monomorphic vectors and arrays (`IntVector.vector` is `int vector`,
  `IntArray.array` is `int array`, and so on for every element type).

What the hosts do:

| | MLton | SML/NJ | Poly/ML |
| --- | --- | --- | --- |
| `Word8Vector.vector` = `string` | no | no | no |
| `Word8VectorSlice.slice` = `substring` | no | no | no |
| `IntVector.vector` = `int vector` | no | no | same |
| `IntArray.array` = `int array` | no | no | same |
| `CharArray.array` = `char array` | no | no | no |

On the byte vector Rune is alone; on the monomorphic families Poly/ML keeps
Rune company.

### The measurements

Three programs, each run against four libraries. Every one printed the same
answer on every library.

* `bytes_ops` — the worst case for the byte boundary: 2,000 rounds of
  `Byte.stringToBytes`/`bytesToString`, slices taken and turned back into
  vectors, `Word8Array.copyVec`, `PackWord32Big`.
* `binio_bench` — realistic binary I/O: 200 KB written and read back through
  `BinIO` in 1 KB chunks.
* `mono_ops` — the monomorphic families: `tabulate`, `sub`, `modify`, `foldl`
  and the slices over `IntVector`, `IntArray`, `RealVector`, `RealArray`,
  `CharArray` and `Word8Array`, 20,000 elements each.

The libraries:

* **v0** the tree as it is;
* **v1** `Word8Vector` and `Word8VectorSlice` sealed where they are declared,
  each to an internal signature that adds `toString`/`fromString`, with a
  `seal` file that hides those two again from a program. `Byte`, `BinIO`,
  `Posix.IO`, `Socket` and `Unix` convert at their boundary;
* **v2** the 48 monomorphic vector, array and slice structures sealed
  opaquely, the 20 alias structures (`Int64Vector = IntVector` and the like)
  left transparent;
* **v4** v1, but the vector and its slice declared inside **one** sealed
  group, so that the slice's body still works on the representation.

| | instructions | Δ | bytes | objects |
| --- | ---: | ---: | ---: | ---: |
| **bytes_ops** v0 | 19,078,995 | — | 40,058,792 | 889,593 |
| v1 | 19,231,043 | **+0.80 %** | 40,282,960 | 893,600 |
| v2 | 19,078,995 | **0** | 40,058,792 | 889,593 |
| v4 | 19,079,021 | **+0.00014 %** | 40,058,840 | 889,595 |
| **binio_bench** v0 | 19,303,509 | — | 37,188,360 | 833,287 |
| v1 | 19,313,835 | **+0.054 %** | 37,199,728 | 833,494 |
| v4 | 19,306,235 | **+0.014 %** | 37,188,408 | 833,289 |
| **mono_ops** v0 | 15,721,293 | — | 41,033,784 | 961,627 |
| v2 | 15,721,293 | **0** | 41,033,784 | 961,627 |

Compile time, measured as the instructions `bin/rune.rbc` executes:

| | compiling `hello.sml` | compiling the whole library (`--basis all`) |
| --- | ---: | ---: |
| v0 | 7,650,092 | 1,011,046,862 |
| v1 | 7,669,115 (+0.25 %) | 1,013,599,690 (+0.25 %) |
| v2 | 7,650,092 (0) | 1,014,998,247 (+0.39 %) |
| v1+v2 | 7,669,115 (+0.25 %) | 1,017,550,791 (+0.64 %) |

### What the numbers mean

**The abstraction itself is free.** An opaque ascription is a compile-time
notion; the representation does not change and nothing is boxed or copied.
That is why v2 is identical to v0 down to the last instruction and the last
allocated object: sealing the monomorphic families introduces no conversion
anywhere, because no file of the library ever crosses between `IntVector` and
`Vector`.

**What v1 costs is one particular accident.** `Word8VectorSlice` is written as
a `Substring` by direct aliasing -- `val vector = Substring.string`,
`val full = Substring.full`. Sealing `Word8Vector` puts a conversion *on top
of* each of those, turning one call into two. That, and nothing else, is the
0.80 %. `Byte.bytesToString` was already `fun bytesToString v = v`, one call,
and becomes `val bytesToString = Word8Vector.toString`, still one call, which
costs nothing.

**The restructure removes it.** v4 declares the vector and its slice together
and seals them with one ascription:

```sml
local
  structure Byte0 :>
  sig
    structure V : MONO_VECTOR_BYTES where type elem = Word8.word
    structure S : MONO_VECTOR_SLICE_BYTES where type vector = V.vector where type elem = Word8.word
  end =
  struct
    structure Impl = RuneStringVectorFn (...)
    structure V = struct open Impl  fun toString v = v  fun fromString s = s end
    structure S = struct ... val vector = Substring.string ... end   (* sees the string *)
  end
in
  structure Word8Vector = Byte0.V
  structure Word8VectorSlice = Byte0.S
end
```

Inside the group the two share `vector = string` and convert nothing; the one
ascription makes the type abstract for everyone outside. 26 instructions on
19 million, and the two files become one.

The 0.014 % that v4 still pays on `binio_bench` is the conversion at the
`BinIO`, `Posix.IO` and `Socket` boundary, once per chunk of 1,024 bytes.
Removing that too would mean pulling `RuneFile`, `BinPrimIO` and `BinIO` into
the same sealed group, which would tangle the I/O stack to save a fifth of a
tenth of a percent. Not worth it.

### Recommendation

1. **Seal the monomorphic families (v2). It is free** -- identical instruction
   counts -- and it closes 48 of the 56 types that show what they are made of,
   including `Word8Array.array` and `CharArray.array`. Poly/ML shows them too,
   MLton and SML/NJ do not.
2. **Seal `Word8Vector` and its slice with the merged group (v4), not v1.**
   The cost is 26 instructions in the worst case I could write, the type stops
   being a `string`, and Rune stops being the only one of the four systems
   where `"abc"` is a vector of bytes. The `Deviation:
   Word8Vector.vector/is-string` note goes with it.
3. The remaining 8 of the 56 need `ARRAY2` and `MONO_ARRAY2` to be declared
   before `array2.sml` and the `mono_*.sml` files, as `sig_time.sml` was moved
   before `time.sml`. Same pattern, no cost; worth doing in the same change.

Everything above was checked: v4 passes the `byte`, `binio`, `io`, `pack`,
`word8`, `mono`, `socket`, `unix` and `posix` suites on the `rune`
configuration -- 82,352 checks, none failing -- and v0, v1, v2 and v4 print
identical answers for all three benchmark programs.
