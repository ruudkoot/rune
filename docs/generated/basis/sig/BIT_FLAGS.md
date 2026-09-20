# signature BIT_FLAGS

[The Standard ML Basis Library](../README.md) &rsaquo; The operating system &rsaquo; **BIT_FLAGS**

|  |  |
| --- | --- |
| Status | optional |
| Implementations | 9 |
| Documentation | 9 of 9 entries documented |
| Tests | 70 checks of 9 entries |
| Source | [lib/basis/sig\_bit\_flags.sml](../../../../lib/basis/sig_bit_flags.sml) |

## Synopsis

```sml
signature BIT_FLAGS
structure Posix.FileSys.O : BIT_FLAGS  (* optional *)
structure Posix.FileSys.S : BIT_FLAGS  (* optional *)
structure Posix.IO.FD : BIT_FLAGS  (* optional *)
structure Posix.IO.O : BIT_FLAGS  (* optional *)
structure Posix.Process.W : BIT_FLAGS  (* optional *)
structure Posix.TTY.C : BIT_FLAGS  (* optional *)
structure Posix.TTY.I : BIT_FLAGS  (* optional *)
structure Posix.TTY.L : BIT_FLAGS  (* optional *)
structure Posix.TTY.O : BIT_FLAGS  (* optional *)
```

| Implementation |  | Source |
| --- | --- | --- |
| `Posix.FileSys.O` | The flags of open and the bits of a mode, as words. "all represents the union of all flags", also those of the system that O does not name (O\_CLOEXEC, and O\_LARGEFILE, which getfl reports): the bits of a C int. fromWord keeps the bits of all, so that "toWord o fromWord" is "fn w =\> SysWord.andb (w, toWord all)". | [lib/basis/posix\_filesys.sml](../../../../lib/basis/posix_filesys.sml) |
| `Posix.FileSys.S` |  | [lib/basis/posix\_filesys.sml](../../../../lib/basis/posix_filesys.sml) |
| `Posix.IO.FD` | The flags of a descriptor, as words; like the flags of open, all of them are the bits of a C int (Posix.FileSys.O). | [lib/basis/posix\_io.sml](../../../../lib/basis/posix_io.sml) |
| `Posix.IO.O` |  | [lib/basis/posix\_io.sml](../../../../lib/basis/posix_io.sml) |
| `Posix.Process.W` | The flags of waitpid. WNOHANG is not one of them: waitpid\_nh adds it. | [lib/basis/posix\_process.sml](../../../../lib/basis/posix_process.sml) |
| `Posix.TTY.C` |  | [lib/basis/posix\_tty.sml](../../../../lib/basis/posix_tty.sml) |
| `Posix.TTY.I` |  | [lib/basis/posix\_tty.sml](../../../../lib/basis/posix_tty.sml) |
| `Posix.TTY.L` |  | [lib/basis/posix\_tty.sml](../../../../lib/basis/posix_tty.sml) |
| `Posix.TTY.O` |  | [lib/basis/posix\_tty.sml](../../../../lib/basis/posix_tty.sml) |

A set of flags held as the bits of a word: what every collection of system
flags in [`POSIX`](../sig/POSIX.md) has in common.

A [`flags`](#val-flags) value is a set. [`flags`](#val-flags) unites sets, [`intersect`](#val-intersect) cuts them down,
[`clear`](#val-clear) takes one away from another, and [`allSet`](#val-allset) and [`anySet`](#val-anyset) ask whether
a set contains another. The named flags of a structure are the one-element
sets, and [`all`](#val-all) is every bit the system uses there -- which may be more
than the named flags, since a system knows bits that the specification
does not name.

[`toWord`](#val-toword) and [`fromWord`](#val-fromword) reach the word underneath, for a program that has
to speak to something that is not SML.

<details><summary>Other implementations (1)</summary>

- **SML/NJ** &mdash; getfl returns no status flags and O\_RDONLY whatever the descriptor

</details>

## Interface

<pre>
signature BIT_FLAGS =
sig
  eqtype <a href="#type-flags">flags</a>

  val <a href="#val-toword">toWord</a> : flags -&gt; SysWord.word

  val <a href="#val-fromword">fromWord</a> : SysWord.word -&gt; flags

  val <a href="#val-all">all</a> : flags

  val <a href="#val-flags">flags</a> : flags list -&gt; flags

  val <a href="#val-intersect">intersect</a> : flags list -&gt; flags

  val <a href="#val-clear">clear</a> : flags * flags -&gt; flags

  val <a href="#val-allset">allSet</a> : flags * flags -&gt; bool

  val <a href="#val-anyset">anySet</a> : flags * flags -&gt; bool
end
</pre>

### <a name="type-flags"></a>`flags`

```sml
eqtype flags
```

The type of a set of flags.

Two are equal when they hold the same flags.

<details><summary>Tests (10)</summary>

For `Posix.Process.W`, in [tests/basis/posix\_process.sml](../../../../tests/basis/posix_process.sml): `empty` &middot; `one` &middot; `union`

For `Posix.FileSys.O`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `append-and-sync`

In [tests/basis/fn/bit\_flags\_fn.sml](../../../../tests/basis/fn/bit_flags_fn.sml), applied to `Posix.Process.W`, `Posix.FileSys.O`, `Posix.FileSys.S`, `Posix.IO.FD`, `Posix.IO.O`, `Posix.TTY.I`, `Posix.TTY.O`, `Posix.TTY.C`, `Posix.TTY.L`: `empty-list` &middot; `singleton` &middot; `idempotent` &middot; `commutative` &middot; `three` &middot; `of-all-named`

</details>

### <a name="val-toword"></a>`toWord`

```sml
val toWord : flags -> SysWord.word
```

`toWord fl` is the word whose bits are the flags of `fl`.

<details><summary>Other implementations (1)</summary>

- **Poly/ML** &mdash; W.fromWord keeps the bits that are not in W.all

</details>

<details><summary>Tests (6)</summary>

For `Posix.Process.W`, in [tests/basis/posix\_process.sml](../../../../tests/basis/posix_process.sml): `of-fromWord`

For `Posix.FileSys.S`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `values-of-the-C-binding`

In [tests/basis/fn/bit\_flags\_fn.sml](../../../../tests/basis/fn/bit_flags_fn.sml), applied to `Posix.Process.W`, `Posix.FileSys.O`, `Posix.FileSys.S`, `Posix.IO.FD`, `Posix.IO.O`, `Posix.TTY.I`, `Posix.TTY.O`, `Posix.TTY.C`, `Posix.TTY.L`: `empty-set-is-zero` &middot; `union-is-orb` &middot; `fromWord-of-named` &middot; `union-is-orb-random`

</details>

### <a name="val-fromword"></a>`fromWord`

```sml
val fromWord : SysWord.word -> flags
```

`fromWord w` is the set of the flags that the bits of `w` name.

> **Reading** `BIT_FLAGS.fromWord/masks-the-rest`. The law `toWord o fromWord = (fn w => andb (w, toWord all))` is required for every word, those with
> bits that no flag of this structure has included: such bits are dropped
> rather than kept or refused.

<details><summary>Other implementations (2)</summary>

- **MLton** &mdash; all of FileSys.O, IO.FD, IO.O and Process.W has every bit of the 64-bit SysWord.word, but fromWord keeps only the 32 of a C int, so that toWord o fromWord is not fn w =\> SysWord.andb (w, toWord all)
- **Poly/ML** &mdash; fromWord keeps every bit of its argument, also those not in all, so that toWord o fromWord is not fn w =\> SysWord.andb (w, toWord all) and fromWord makes flags outside all

</details>

<details><summary>Tests (9)</summary>

For `Posix.Process.W`, in [tests/basis/posix\_process.sml](../../../../tests/basis/posix_process.sml): `of-toWord`

In [tests/basis/fn/bit\_flags\_fn.sml](../../../../tests/basis/fn/bit_flags_fn.sml), applied to `Posix.Process.W`, `Posix.FileSys.O`, `Posix.FileSys.S`, `Posix.IO.FD`, `Posix.IO.O`, `Posix.TTY.I`, `Posix.TTY.O`, `Posix.TTY.C`, `Posix.TTY.L`: `inverts-toWord-on-named` &middot; `inverts-toWord-on-all-and-empty` &middot; `inverts-toWord-random` &middot; `zero-is-empty` &middot; `word-of-all` &middot; `bits-beyond-all` &middot; `random-words-beyond-all` &middot; `result-within-all`

</details>

### <a name="val-all"></a>`all`

```sml
val all : flags
```

Every flag the system uses here.

> **Implementation** `BIT_FLAGS.all/every-bit-the-system-has`. It is every
> bit of the underlying C value, so it may include flags the
> specification does not name (`O_CLOEXEC`, `O_LARGEFILE`); that is what
> lets those survive a trip through [`fromWord`](#val-fromword) or a call that reads the
> flags back from the system.

<details><summary>Tests (4)</summary>

For `Posix.Process.W`, in [tests/basis/posix\_process.sml](../../../../tests/basis/posix_process.sml): `union-of-all`

In [tests/basis/fn/bit\_flags\_fn.sml](../../../../tests/basis/fn/bit_flags_fn.sml), applied to `Posix.Process.W`, `Posix.FileSys.O`, `Posix.FileSys.S`, `Posix.IO.FD`, `Posix.IO.O`, `Posix.TTY.I`, `Posix.TTY.O`, `Posix.TTY.C`, `Posix.TTY.L`: `contains-named` &middot; `union-with-named` &middot; `not-empty`

</details>

### <a name="val-flags"></a>`flags`

```sml
val flags : flags list -> flags
```

`flags l` is the union of the sets of `l`: a flag is in it when it is in one of them.

<details><summary>Tests (10)</summary>

For `Posix.Process.W`, in [tests/basis/posix\_process.sml](../../../../tests/basis/posix_process.sml): `empty` &middot; `one` &middot; `union`

For `Posix.FileSys.O`, in [tests/basis/posix\_filesys.sml](../../../../tests/basis/posix_filesys.sml): `append-and-sync`

In [tests/basis/fn/bit\_flags\_fn.sml](../../../../tests/basis/fn/bit_flags_fn.sml), applied to `Posix.Process.W`, `Posix.FileSys.O`, `Posix.FileSys.S`, `Posix.IO.FD`, `Posix.IO.O`, `Posix.TTY.I`, `Posix.TTY.O`, `Posix.TTY.C`, `Posix.TTY.L`: `empty-list` &middot; `singleton` &middot; `idempotent` &middot; `commutative` &middot; `three` &middot; `of-all-named`

</details>

### <a name="val-intersect"></a>`intersect`

```sml
val intersect : flags list -> flags
```

`intersect l` is the intersection of the sets of `l`: a flag is in it when it is in all of them.

The intersection of no sets at all is [`all`](#val-all).

<details><summary>Tests (9)</summary>

For `Posix.Process.W`, in [tests/basis/posix\_process.sml](../../../../tests/basis/posix_process.sml): `empty-is-all` &middot; `two`

In [tests/basis/fn/bit\_flags\_fn.sml](../../../../tests/basis/fn/bit_flags_fn.sml), applied to `Posix.Process.W`, `Posix.FileSys.O`, `Posix.FileSys.S`, `Posix.IO.FD`, `Posix.IO.O`, `Posix.TTY.I`, `Posix.TTY.O`, `Posix.TTY.C`, `Posix.TTY.L`: `empty-list-is-all` &middot; `singleton` &middot; `with-empty` &middot; `with-all` &middot; `is-andb` &middot; `is-andb-random` &middot; `three`

</details>

### <a name="val-clear"></a>`clear`

```sml
val clear : flags * flags -> flags
```

`clear (fl, gl)` is `gl` without the flags of `fl`.

<details><summary>Tests (9)</summary>

For `Posix.Process.W`, in [tests/basis/posix\_process.sml](../../../../tests/basis/posix_process.sml): `difference` &middot; `formula`

In [tests/basis/fn/bit\_flags\_fn.sml](../../../../tests/basis/fn/bit_flags_fn.sml), applied to `Posix.Process.W`, `Posix.FileSys.O`, `Posix.FileSys.S`, `Posix.IO.FD`, `Posix.IO.O`, `Posix.TTY.I`, `Posix.TTY.O`, `Posix.TTY.C`, `Posix.TTY.L`: `definition` &middot; `definition-random` &middot; `self-is-empty` &middot; `empty-clears-nothing` &middot; `all-clears-everything` &middot; `is-set-difference` &middot; `order-of-arguments`

</details>

### <a name="val-allset"></a>`allSet`

```sml
val allSet : flags * flags -> bool
```

`allSet (fl, gl)` is `true` when every flag of `fl` is in `gl`.

<details><summary>Other implementations (2)</summary>

- **MLton** &mdash; W.allSet (fl1, fl2) tests whether fl2 is in fl1: the arguments are swapped
- **MLton** &mdash; allSet (fl1, fl2) tests whether fl2 is included in fl1, the other way round from "returns true if all of the flags in fl1 are also in fl2"

</details>

<details><summary>Tests (7)</summary>

For `Posix.Process.W`, in [tests/basis/posix\_process.sml](../../../../tests/basis/posix_process.sml): `inclusion`

In [tests/basis/fn/bit\_flags\_fn.sml](../../../../tests/basis/fn/bit_flags_fn.sml), applied to `Posix.Process.W`, `Posix.FileSys.O`, `Posix.FileSys.S`, `Posix.IO.FD`, `Posix.IO.O`, `Posix.TTY.I`, `Posix.TTY.O`, `Posix.TTY.C`, `Posix.TTY.L`: `empty-in-anything` &middot; `reflexive` &middot; `in-union` &middot; `is-inclusion` &middot; `is-inclusion-random` &middot; `order-of-arguments`

</details>

### <a name="val-anyset"></a>`anySet`

```sml
val anySet : flags * flags -> bool
```

`anySet (fl, gl)` is `true` when some flag of `fl` is in `gl`.

<details><summary>Tests (6)</summary>

For `Posix.Process.W`, in [tests/basis/posix\_process.sml](../../../../tests/basis/posix_process.sml): `intersection`

In [tests/basis/fn/bit\_flags\_fn.sml](../../../../tests/basis/fn/bit_flags_fn.sml), applied to `Posix.Process.W`, `Posix.FileSys.O`, `Posix.FileSys.S`, `Posix.IO.FD`, `Posix.IO.O`, `Posix.TTY.I`, `Posix.TTY.O`, `Posix.TTY.C`, `Posix.TTY.L`: `empty-meets-nothing` &middot; `nonempty-meets-itself` &middot; `is-nonempty-intersection` &middot; `is-nonempty-intersection-random` &middot; `symmetric-random`

</details>

## See also

[`POSIX_FILE_SYS`](../sig/POSIX_FILE_SYS.md), [`POSIX_IO`](../sig/POSIX_IO.md), [`POSIX_PROCESS`](../sig/POSIX_PROCESS.md), [`POSIX_TTY`](../sig/POSIX_TTY.md),
[`WORD`](../sig/WORD.md)

---

<sub>Generated by runedoc from lib/basis/sig\_bit\_flags.sml; do not edit.</sub>
