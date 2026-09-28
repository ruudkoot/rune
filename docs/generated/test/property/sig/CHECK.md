# signature CHECK

[Property testing](../README.md) &rsaquo; Property testing &rsaquo; **CHECK**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 8 of 8 entries documented |
| Tests | not listed |
| Source | [lib/test/property/check\_sig.sml](../../../../../lib/test/property/check_sig.sml) |

## Synopsis

```sml
signature CHECK
structure Check :> CHECK
```

| Implementation |  | Source |
| --- | --- | --- |
| [`Check`](../str/Check.md) |  | [lib/test/property/check.sml](../../../../../lib/test/property/check.sml) |

Running properties: many cases, each from its own seed at a size that
grows over the run, and a report.

The seed of a run is a hash of the property's name unless a seed is
given, so that a run is the same on every machine, and a failure is
reported with a token that runs its case again.

## Interface

<pre>
signature CHECK =
sig
  type <a href="#type-config">config</a> = {<a href="#fld-config.seed">seed</a> : Word64.word option, <a href="#fld-config.tests">tests</a> : int, <a href="#fld-config.maxsize">maxSize</a> : int, <a href="#fld-config.maxdiscards">maxDiscards</a> : int}
  val <a href="#val-default">default</a> : config
  datatype <a href="#type-result">result</a> =
      <a href="#con-passed">Passed</a> of {<a href="#fld-passed.tests">tests</a> : int, <a href="#fld-passed.discarded">discarded</a> : int, <a href="#fld-passed.labels">labels</a> : (string * int) list, <a href="#fld-passed.short">short</a> : (string * real * real) list}
    | <a href="#con-failed">Failed</a> of {<a href="#fld-failed.test">test</a> : int, <a href="#fld-failed.size">size</a> : int, <a href="#fld-failed.class">class</a> : string, <a href="#fld-failed.message">message</a> : string, <a href="#fld-failed.counterexample">counterexample</a> : string list,
                 <a href="#fld-failed.replay">replay</a> : string}
    | <a href="#con-gaveup">GaveUp</a> of {<a href="#fld-gaveup.tests">tests</a> : int, <a href="#fld-gaveup.discarded">discarded</a> : int}
  val <a href="#val-check">check</a> : config -&gt; string -&gt; Prop.prop -&gt; result
  val <a href="#val-replay">replay</a> : string -&gt; Prop.prop -&gt; Prop.result option
  val <a href="#val-report">report</a> : string -&gt; result -&gt; string
  val <a href="#val-passed">passed</a> : result -&gt; bool
  val <a href="#val-main">main</a> : (string * Prop.prop) list -&gt; unit
end
</pre>

### <a name="type-config"></a>`config`

```sml
type config = {seed : Word64.word option, tests : int, maxSize : int, maxDiscards : int}
```

How a property is run.

`seed` is the seed of the run (`NONE`: a hash of the name), `tests` the
number of cases that must pass, `maxSize` the largest size, and
`maxDiscards` the number of discarded cases after which the run gives
up.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-config.seed"></a>`seed` | `Word64.word option` |  |
| <a name="fld-config.tests"></a>`tests` | `int` |  |
| <a name="fld-config.maxsize"></a>`maxSize` | `int` |  |
| <a name="fld-config.maxdiscards"></a>`maxDiscards` | `int` |  |

### <a name="val-default"></a>`default`

```sml
val default : config
```

100 cases, sizes up to 100, a seed from the name, giving up after 1000
discarded cases.

### <a name="type-result"></a>`result`

```sml
datatype result =
    Passed of {tests : int, discarded : int, labels : (string * int) list, short : (string * real * real) list}
  | Failed of {test : int, size : int, class : string, message : string, counterexample : string list,
               replay : string}
  | GaveUp of {tests : int, discarded : int}
```

What a run found. [`Failed`](#con-failed)'s [`replay`](#val-replay) is the token of its case.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-passed"></a>`Passed` | `{tests : int, discarded : int, labels : (string * int) list, short : (string * real * real) list}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-passed.tests"></a>`tests` | `int` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-passed.discarded"></a>`discarded` | `int` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-passed.labels"></a>`labels` | `(string * int) list` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-passed.short"></a>`short` | `(string * real * real) list` |  |
| <a name="con-failed"></a>`Failed` | `{test : int, size : int, class : string, message : string, counterexample : string list, replay : string}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-failed.test"></a>`test` | `int` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-failed.size"></a>`size` | `int` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-failed.class"></a>`class` | `string` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-failed.message"></a>`message` | `string` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-failed.counterexample"></a>`counterexample` | `string list` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-failed.replay"></a>`replay` | `string` |  |
| <a name="con-gaveup"></a>`GaveUp` | `{tests : int, discarded : int}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-gaveup.tests"></a>`tests` | `int` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-gaveup.discarded"></a>`discarded` | `int` |  |

### <a name="val-check"></a>`check`

```sml
val check : config -> string -> Prop.prop -> result
```

`check c name p` runs `p` as `c` says.

### <a name="val-replay"></a>`replay`

```sml
val replay : string -> Prop.prop -> Prop.result option
```

`replay token p` runs the case of a [`Failed`](#con-failed) result's [`replay`](#val-replay) token
again: its verdict and what it drew, or `NONE` when the token is not
one.

### <a name="val-report"></a>`report`

```sml
val report : string -> result -> string
```

`report name r` is the report of a run: a first line `PASS name` or
`FAIL name`, and what the run found.

### <a name="val-passed"></a>`passed`

```sml
val passed : result -> bool
```

`passed r` is `true` for a run that passed and had the coverage it asked
for.

### <a name="val-main"></a>`main`

```sml
val main : (string * Prop.prop) list -> unit
```

`main ps` runs each named property with [`default`](#val-default), prints its report,
and ends the program with failure if one did not pass.

---

<sub>Generated by runedoc from lib/test/property/check\_sig.sml; do not edit.</sub>
