# signature TEST

[Unit testing](../README.md) &rsaquo; Unit testing &rsaquo; **TEST**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 15 of 15 entries documented |
| Tests | not listed |
| Source | [lib/test/unit/test\_sig.sml](../../../../../lib/test/unit/test_sig.sml) |

## Synopsis

```sml
signature TEST
structure Test :> TEST
```

| Implementation |  | Source |
| --- | --- | --- |
| [`Test`](../str/Test.md) | Tests as values: the tree, its metadata, and the tests made of properties and golden files. | [lib/test/unit/test.sml](../../../../../lib/test/unit/test.sml) |

Tests as values (docs/plans/unit-testing.md, D2): a tree of named tests
that can be listed, filtered and asked what it needs before any of it
runs.

A leaf is a test and a group names a subtree. The path of a test is the
names from the root down to it joined by `/`, as `lib/basis/word64`, and
is how filters, exclusions and resumption name it. The tree is
polymorphic in its leaves: the tests that run in this process have
functions as leaves, and a runner can put descriptions of jobs there and
keep the listing, the filters and the metadata.

## Interface

<pre>
signature TEST =
sig
  type 'a <a href="#type-tree">tree</a>
  type <a href="#type-meta">meta</a> = {<a href="#fld-meta.tags">tags</a> : string list, <a href="#fld-meta.timeout">timeout</a> : Time.time option, <a href="#fld-meta.requires">requires</a> : string list,
               <a href="#fld-meta.cpus">cpus</a> : int option, <a href="#fld-meta.memory">memory</a> : int option, <a href="#fld-meta.pending">pending</a> : string option}
  type <a href="#type-test">test</a> = (unit -&gt; unit) tree
  val <a href="#val-it">it</a> : string -&gt; 'a -&gt; 'a tree
  val <a href="#val-describe">describe</a> : string -&gt; 'a tree list -&gt; 'a tree
  val <a href="#val-tag">tag</a> : string -&gt; 'a tree -&gt; 'a tree
  val <a href="#val-timeout">timeout</a> : Time.time -&gt; 'a tree -&gt; 'a tree
  val <a href="#val-requires">requires</a> : string list -&gt; 'a tree -&gt; 'a tree
  val <a href="#val-resources">resources</a> : {<a href="#fld-resources.cpus">cpus</a> : int, <a href="#fld-resources.memory">memory</a> : int} -&gt; 'a tree -&gt; 'a tree
  val <a href="#val-pending">pending</a> : string -&gt; 'a tree -&gt; 'a tree
  val <a href="#val-ways">ways</a> : (string * 'w) list -&gt; ('w -&gt; 'a) tree -&gt; 'a tree
  val <a href="#val-map">map</a> : ('a -&gt; 'b) -&gt; 'a tree -&gt; 'b tree
  val <a href="#val-leaves">leaves</a> : 'a tree -&gt; {<a href="#fld-leaves.path">path</a> : string, <a href="#fld-leaves.meta">meta</a> : meta, <a href="#fld-leaves.leaf">leaf</a> : 'a} list
  val <a href="#val-property">property</a> : string -&gt; (unit -&gt; Prop.prop) -&gt; test
  val <a href="#val-golden">golden</a> : string -&gt; {<a href="#fld-golden.expected">expected</a> : string, <a href="#fld-golden.actual">actual</a> : unit -&gt; string} -&gt; test
end
</pre>

### <a name="type-tree"></a>`tree`

```sml
type 'a tree
```

A tree of tests whose leaves are of type `'a`.

### <a name="type-meta"></a>`meta`

```sml
type meta = {tags : string list, timeout : Time.time option, requires : string list,
             cpus : int option, memory : int option, pending : string option}
```

What a test says about itself, inherited from the groups above it.

Its tags; the time it may take; the capabilities it needs (programs
and systems outside Rune, which a doctor can look for); the CPUs and the
megabytes of memory it takes; and, for a test that is not run, why. A
group's tags add to its tests', and for the rest the nearest says.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-meta.tags"></a>`tags` | `string list` |  |
| <a name="fld-meta.timeout"></a>`timeout` | `Time.time option` |  |
| <a name="fld-meta.requires"></a>`requires` | `string list` |  |
| <a name="fld-meta.cpus"></a>`cpus` | `int option` |  |
| <a name="fld-meta.memory"></a>`memory` | `int option` |  |
| <a name="fld-meta.pending"></a>`pending` | `string option` |  |

### <a name="type-test"></a>`test`

```sml
type test = (unit -> unit) tree
```

Tests that run in this process: each is a function that fails by
raising, or by failing a check of [`Expect`](../str/Expect.md).

### <a name="val-it"></a>`it`

```sml
val it : string -> 'a -> 'a tree
```

`it name x` is a test named `name` whose leaf is `x`.

**Example** `List.map #path (leaves (it "one" ())) = ["one"]`

### <a name="val-describe"></a>`describe`

```sml
val describe : string -> 'a tree list -> 'a tree
```

`describe name ts` is the group of the tests `ts`, its name before
each of their paths.

**Example** `List.map #path (leaves (describe "lib" [it "json" (), it "digest" ()])) = ["lib/json", "lib/digest"]`

### <a name="val-tag"></a>`tag`

```sml
val tag : string -> 'a tree -> 'a tree
```

`tag t tree` gives every test of `tree` the tag `t`.

**Example** `List.map (#tags o #meta) (leaves (tag "slow" (it "big" ()))) = [["slow"]]`

### <a name="val-timeout"></a>`timeout`

```sml
val timeout : Time.time -> 'a tree -> 'a tree
```

`timeout t tree` says that a test of `tree` may take `t`. A runner
ends a test that takes longer; a suite run in one process cannot, and
only lists it.

### <a name="val-requires"></a>`requires`

```sml
val requires : string list -> 'a tree -> 'a tree
```

`requires cs tree` says that the tests of `tree` need the capabilities
`cs`, as `"tmux"` or `"mlton"`.

### <a name="val-resources"></a>`resources`

```sml
val resources : {cpus : int, memory : int} -> 'a tree -> 'a tree
```

`resources {cpus, memory} tree` says that a test of `tree` takes
`cpus` processors and `memory` megabytes, for a runner's scheduler.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-resources.cpus"></a>`cpus` | `int` |  |
| <a name="fld-resources.memory"></a>`memory` | `int` |  |

### <a name="val-pending"></a>`pending`

```sml
val pending : string -> 'a tree -> 'a tree
```

`pending reason tree` keeps the tests of `tree` listed but not run,
and says why.

**Example** `List.map (#pending o #meta) (leaves (pending "a bug" (it "x" ()))) = [SOME "a bug"]`

### <a name="val-ways"></a>`ways`

```sml
val ways : (string * 'w) list -> ('w -> 'a) tree -> 'a tree
```

`ways ws tree` makes every test of `tree` once for each way of `ws`,
a name and a value (D7).

The test of the way `(n, w)` has the name `name[n]`, the tag `way:n`,
and the leaf `f w`.

**Example** `List.map #path (leaves (ways [("a", 1), ("b", 2)] (it "t" (fn w => w)))) = ["t[a]", "t[b]"]`

### <a name="val-map"></a>`map`

```sml
val map : ('a -> 'b) -> 'a tree -> 'b tree
```

`map f tree` is `tree` with `f` applied to every leaf.

### <a name="val-leaves"></a>`leaves`

```sml
val leaves : 'a tree -> {path : string, meta : meta, leaf : 'a} list
```

`leaves tree` is every test of `tree` with its path and its metadata,
in the order they were written.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-leaves.path"></a>`path` | `string` |  |
| <a name="fld-leaves.meta"></a>`meta` | `meta` |  |
| <a name="fld-leaves.leaf"></a>`leaf` | `'a` |  |

### <a name="val-property"></a>`property`

```sml
val property : string -> (unit -> Prop.prop) -> test
```

`property name p` is a test that checks the property `p ()` with
[`Check.default`](../../property/sig/CHECK.md#val-default) (D5).

When the property does not hold, the test fails with its report: the
shrunk counterexample and the replay token.

### <a name="val-golden"></a>`golden`

```sml
val golden : string -> {expected : string, actual : unit -> string} -> test
```

`golden name {expected, actual}` is a test that checks that the file
`expected` holds the text `actual ()` ([`Golden.check`](../sig/GOLDEN.md#val-check)).

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-golden.expected"></a>`expected` | `string` |  |
| <a name="fld-golden.actual"></a>`actual` | `unit -> string` |  |

---

<sub>Generated by runedoc from lib/test/unit/test\_sig.sml; do not edit.</sub>
