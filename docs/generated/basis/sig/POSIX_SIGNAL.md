# signature POSIX_SIGNAL

[The Standard ML Basis Library](../README.md) &rsaquo; **POSIX_SIGNAL**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 0 of 23 entries documented |
| Tests | 34 checks of 22 entries |
| Source | [lib/basis/sig\_posix\_signal.sml](../../../../lib/basis/sig_posix_signal.sml) |

## Synopsis

```sml
signature POSIX_SIGNAL
structure Posix.Signal : POSIX_SIGNAL
```

| Implementation |  | Source |
| --- | --- | --- |
| `Posix.Signal` |  | [lib/basis/posix.sml](../../../../lib/basis/posix.sml) |

signature POSIX\_SIGNAL, transcribed from
<https://smlfamily.github.io/Basis/posix-signal.html>

## Interface

<pre>
signature POSIX_SIGNAL =
sig
  eqtype <a href="#type-signal">signal</a>

  val <a href="#val-toword">toWord</a> : signal -&gt; SysWord.word
  val <a href="#val-fromword">fromWord</a> : SysWord.word -&gt; signal

  val <a href="#val-abrt">abrt</a> : signal
  val <a href="#val-alrm">alrm</a> : signal
  val <a href="#val-bus">bus</a> : signal
  val <a href="#val-fpe">fpe</a> : signal
  val <a href="#val-hup">hup</a> : signal
  val <a href="#val-ill">ill</a> : signal
  val <a href="#val-int">int</a> : signal
  val <a href="#val-kill">kill</a> : signal
  val <a href="#val-pipe">pipe</a> : signal
  val <a href="#val-quit">quit</a> : signal
  val <a href="#val-segv">segv</a> : signal
  val <a href="#val-term">term</a> : signal
  val <a href="#val-usr1">usr1</a> : signal
  val <a href="#val-usr2">usr2</a> : signal
  val <a href="#val-chld">chld</a> : signal
  val <a href="#val-cont">cont</a> : signal
  val <a href="#val-stop">stop</a> : signal
  val <a href="#val-tstp">tstp</a> : signal
  val <a href="#val-ttin">ttin</a> : signal
  val <a href="#val-ttou">ttou</a> : signal
end
</pre>

### <a name="type-signal"></a>`signal`

```sml
eqtype signal
```

### <a name="val-toword"></a>`toWord`

```sml
val toWord : signal -> SysWord.word
```

<details><summary>Tests (1)</summary>

For `Posix.Signal`, in [tests/basis/posix\_signal.sml](../../../../tests/basis/posix_signal.sml): `distinct`

</details>

### <a name="val-fromword"></a>`fromWord`

```sml
val fromWord : SysWord.word -> signal
```

<details><summary>Tests (3)</summary>

For `Posix.Signal`, in [tests/basis/posix\_signal.sml](../../../../tests/basis/posix_signal.sml): `of-toWord-all` &middot; `no-check` &middot; `equal-words-equal-signals`

</details>

### <a name="val-abrt"></a>`abrt`

```sml
val abrt : signal
```

<details><summary>Tests (1)</summary>

For `Posix.Signal`, in [tests/basis/posix\_signal.sml](../../../../tests/basis/posix_signal.sml): `*`

</details>

### <a name="val-alrm"></a>`alrm`

```sml
val alrm : signal
```

<details><summary>Tests (2)</summary>

For `Posix.Signal`, in [tests/basis/posix\_signal.sml](../../../../tests/basis/posix_signal.sml): `*` &middot; `ends-shell`

</details>

### <a name="val-bus"></a>`bus`

```sml
val bus : signal
```

<details><summary>Tests (1)</summary>

For `Posix.Signal`, in [tests/basis/posix\_signal.sml](../../../../tests/basis/posix_signal.sml): `*`

</details>

### <a name="val-fpe"></a>`fpe`

```sml
val fpe : signal
```

<details><summary>Tests (1)</summary>

For `Posix.Signal`, in [tests/basis/posix\_signal.sml](../../../../tests/basis/posix_signal.sml): `*`

</details>

### <a name="val-hup"></a>`hup`

```sml
val hup : signal
```

<details><summary>Tests (2)</summary>

For `Posix.Signal`, in [tests/basis/posix\_signal.sml](../../../../tests/basis/posix_signal.sml): `*` &middot; `ends-shell`

</details>

### <a name="val-ill"></a>`ill`

```sml
val ill : signal
```

<details><summary>Tests (1)</summary>

For `Posix.Signal`, in [tests/basis/posix\_signal.sml](../../../../tests/basis/posix_signal.sml): `*`

</details>

### <a name="val-int"></a>`int`

```sml
val int : signal
```

<details><summary>Tests (1)</summary>

For `Posix.Signal`, in [tests/basis/posix\_signal.sml](../../../../tests/basis/posix_signal.sml): `*`

</details>

### <a name="val-kill"></a>`kill`

```sml
val kill : signal
```

<details><summary>Tests (2)</summary>

For `Posix.Signal`, in [tests/basis/posix\_signal.sml](../../../../tests/basis/posix_signal.sml): `*` &middot; `ends-shell`

</details>

### <a name="val-pipe"></a>`pipe`

```sml
val pipe : signal
```

<details><summary>Tests (2)</summary>

For `Posix.Signal`, in [tests/basis/posix\_signal.sml](../../../../tests/basis/posix_signal.sml): `*` &middot; `ends-shell`

</details>

### <a name="val-quit"></a>`quit`

```sml
val quit : signal
```

<details><summary>Tests (1)</summary>

For `Posix.Signal`, in [tests/basis/posix\_signal.sml](../../../../tests/basis/posix_signal.sml): `*`

</details>

### <a name="val-segv"></a>`segv`

```sml
val segv : signal
```

<details><summary>Tests (1)</summary>

For `Posix.Signal`, in [tests/basis/posix\_signal.sml](../../../../tests/basis/posix_signal.sml): `*`

</details>

### <a name="val-term"></a>`term`

```sml
val term : signal
```

<details><summary>Tests (2)</summary>

For `Posix.Signal`, in [tests/basis/posix\_signal.sml](../../../../tests/basis/posix_signal.sml): `*` &middot; `ends-shell`

</details>

### <a name="val-usr1"></a>`usr1`

```sml
val usr1 : signal
```

<details><summary>Tests (2)</summary>

For `Posix.Signal`, in [tests/basis/posix\_signal.sml](../../../../tests/basis/posix_signal.sml): `*` &middot; `ends-shell`

</details>

### <a name="val-usr2"></a>`usr2`

```sml
val usr2 : signal
```

<details><summary>Tests (2)</summary>

For `Posix.Signal`, in [tests/basis/posix\_signal.sml](../../../../tests/basis/posix_signal.sml): `*` &middot; `ends-shell`

</details>

### <a name="val-chld"></a>`chld`

```sml
val chld : signal
```

<details><summary>Tests (2)</summary>

For `Posix.Signal`, in [tests/basis/posix\_signal.sml](../../../../tests/basis/posix_signal.sml): `*` &middot; `ignored-by-default`

</details>

### <a name="val-cont"></a>`cont`

```sml
val cont : signal
```

<details><summary>Tests (2)</summary>

For `Posix.Signal`, in [tests/basis/posix\_signal.sml](../../../../tests/basis/posix_signal.sml): `*` &middot; `continues`

</details>

### <a name="val-stop"></a>`stop`

```sml
val stop : signal
```

<details><summary>Tests (2)</summary>

For `Posix.Signal`, in [tests/basis/posix\_signal.sml](../../../../tests/basis/posix_signal.sml): `*` &middot; `stops-shell`

</details>

### <a name="val-tstp"></a>`tstp`

```sml
val tstp : signal
```

<details><summary>Tests (1)</summary>

For `Posix.Signal`, in [tests/basis/posix\_signal.sml](../../../../tests/basis/posix_signal.sml): `*`

</details>

### <a name="val-ttin"></a>`ttin`

```sml
val ttin : signal
```

<details><summary>Tests (1)</summary>

For `Posix.Signal`, in [tests/basis/posix\_signal.sml](../../../../tests/basis/posix_signal.sml): `*`

</details>

### <a name="val-ttou"></a>`ttou`

```sml
val ttou : signal
```

<details><summary>Tests (1)</summary>

For `Posix.Signal`, in [tests/basis/posix\_signal.sml](../../../../tests/basis/posix_signal.sml): `*`

</details>

---

<sub>Generated by runedoc from lib/basis/sig\_posix\_signal.sml; do not edit.</sub>
