# signature EXPECTATIONS

[Running tests](../README.md) &rsaquo; Running tests &rsaquo; **EXPECTATIONS**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 14 of 14 entries documented |
| Tests | not listed |
| Source | [lib/test/runner/expectations\_sig.sml](../../../../../lib/test/runner/expectations_sig.sml) |

## Synopsis

```sml
signature EXPECTATIONS
structure Expectations :> EXPECTATIONS
```

| Implementation |  | Source |
| --- | --- | --- |
| [`Expectations`](../str/Expectations.md) | Expectations: the one format of deviations and skips, and what each category means. | [lib/test/runner/expectations.sml](../../../../../lib/test/runner/expectations.sml) |

What a suite expects of its tests in some ways (docs/plans/unit-testing.md,
D16; docs/testing.md, Expectations): one format, and one meaning for
each category, for every list of deviations and skips.

A file has a line for each expectation, and `#` begins a comment:

```sml
WAY-GLOB | PATH-GLOB[::LABEL-GLOB] | CATEGORY | reason
```

The globs have `*` (any run of characters), `?` (one character) and
`[...]` (one of the characters, or ranges such as `0-9`, that it holds;
`[!...]` one that it does not), as the shell has them, and must match the
whole way, path or label. A line of three fields,
`PATH-GLOB | CATEGORY | reason`, is of every way. A category's meaning is one of
four:

- strict: the test must fail where the line says (`RUNE-DEV`, `HOST-BUG`,
  `WIDTH`, `SPEC-AMBIGUOUS`, [`WINDOWS`](../../../basis/sig/WINDOWS.md), `EMULATED`, `FAILS`). A test that
  passes there fails, and a line that matches no failure in a way that
  ran is stale;
- lenient: the test may pass or fail (`HOST-FLAKY`, `FLAKY`);
- skip: the test is not run, for the reason given (`HOST-ABSENT`,
  `XC1-NA`, `XC2-NA`, `UNTESTED`, `UNSUPPORTED`). A line that names no
  test is stale;
- quarantine: the test runs and is reported, and its failure fails
  nothing until the date the reason begins with (`QUARANTINE`, with
  `until YYYY-MM-DD:`); after it the line is stale.

## Interface

<pre>
signature EXPECTATIONS =
sig
  datatype <a href="#type-meaning">meaning</a> = <a href="#con-strict">Strict</a> | <a href="#con-lenient">Lenient</a> | <a href="#con-skip">Skip</a> | <a href="#con-quarantine">Quarantine</a>
  type <a href="#type-line">line</a> = {<a href="#fld-line.file">file</a> : string, <a href="#fld-line.number">number</a> : int, <a href="#fld-line.way">way</a> : string, <a href="#fld-line.path">path</a> : string, <a href="#fld-line.label">label</a> : string option,
               <a href="#fld-line.category">category</a> : string, <a href="#fld-line.reason">reason</a> : string}
  exception <a href="#exn-parse">Parse</a> of string
  val <a href="#val-meaning">meaning</a> : string -&gt; meaning option
  val <a href="#val-parse">parse</a> : string * string -&gt; line list
  val <a href="#val-read">read</a> : string -&gt; line list
  val <a href="#val-glob">glob</a> : string * string -&gt; bool
  val <a href="#val-find">find</a> : line list * {<a href="#fld-find.way">way</a> : string, <a href="#fld-find.path">path</a> : string, <a href="#fld-find.label">label</a> : string option} -&gt; line option
  val <a href="#val-skipped">skipped</a> : line list * {<a href="#fld-skipped.way">way</a> : string, <a href="#fld-skipped.path">path</a> : string} -&gt; line option
  datatype <a href="#type-outcome">outcome</a> = <a href="#con-pass">Pass</a> | <a href="#con-fail">Fail</a> | <a href="#con-expected">Expected</a> of line | <a href="#con-unexpected">Unexpected</a> of line | <a href="#con-flaky">Flaky</a> of line
                   | <a href="#con-quarantined">Quarantined</a> of line | <a href="#con-expired">Expired</a> of line
  val <a href="#val-judge">judge</a> : line list * {<a href="#fld-judge.way">way</a> : string, <a href="#fld-judge.path">path</a> : string, <a href="#fld-judge.label">label</a> : string option, <a href="#fld-judge.passed">passed</a> : bool, <a href="#fld-judge.today">today</a> : string}
              -&gt; outcome
  val <a href="#val-failing">failing</a> : outcome -&gt; bool
  val <a href="#val-stale">stale</a> : line list * {<a href="#fld-stale.ways">ways</a> : string list, <a href="#fld-stale.paths">paths</a> : string list, <a href="#fld-stale.used">used</a> : line list, <a href="#fld-stale.today">today</a> : string} -&gt; line list
  val <a href="#val-describe">describe</a> : line -&gt; string
end
</pre>

### <a name="type-meaning"></a>`meaning`

```sml
datatype meaning = Strict | Lenient | Skip | Quarantine
```

What a category means.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-strict"></a>`Strict` |  |  |
| <a name="con-lenient"></a>`Lenient` |  |  |
| <a name="con-skip"></a>`Skip` |  |  |
| <a name="con-quarantine"></a>`Quarantine` |  |  |

### <a name="type-line"></a>`line`

```sml
type line = {file : string, number : int, way : string, path : string, label : string option,
             category : string, reason : string}
```

A line: where it is, its globs, its category and its reason.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-line.file"></a>`file` | `string` |  |
| <a name="fld-line.number"></a>`number` | `int` |  |
| <a name="fld-line.way"></a>`way` | `string` |  |
| <a name="fld-line.path"></a>`path` | `string` |  |
| <a name="fld-line.label"></a>`label` | `string option` |  |
| <a name="fld-line.category"></a>`category` | `string` |  |
| <a name="fld-line.reason"></a>`reason` | `string` |  |

### <a name="exn-parse"></a>`Parse`

```sml
exception Parse of string
```

Raised by [`parse`](#val-parse) for a line that is not an expectation, with its file
and number.

### <a name="val-meaning"></a>`meaning`

```sml
val meaning : string -> meaning option
```

`meaning c` is what the category `c` means, or `NONE` for no category.

**Example** `meaning "HOST-BUG" = SOME Strict`

### <a name="val-parse"></a>`parse`

```sml
val parse : string * string -> line list
```

`parse (file, text)` is the lines of `text`, the contents of `file`.

**Raises** [`Parse`](#exn-parse) for a line with too few fields or a category that is
not one, or a quarantine without its date.

**Example** `length (parse ("f", "# a comment\n* | a/* | FLAKY | why\n")) = 1`

### <a name="val-read"></a>`read`

```sml
val read : string -> line list
```

`read file` is the lines of `file`, or none when there is no file.

### <a name="val-glob"></a>`glob`

```sml
val glob : string * string -> bool
```

`glob (g, s)` says whether the glob `g` matches the whole of `s`.

**Example** `glob ("lang/*/rt.?", "lang/native/rt.a")`

**Example** `glob ("*.scan/DEC-[avfr]*", "Int.scan/DEC-v1") andalso not (glob ("[!o]x", "ox"))`

### <a name="val-find"></a>`find`

```sml
val find : line list * {way : string, path : string, label : string option} -> line option
```

`find (ls, {way, path, label})` is the first line of `ls` that matches
the test, if any.

A line with a label matches only that test's label; one without
matches the test, whatever its label.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-find.way"></a>`way` | `string` |  |
| <a name="fld-find.path"></a>`path` | `string` |  |
| <a name="fld-find.label"></a>`label` | `string option` |  |

### <a name="val-skipped"></a>`skipped`

```sml
val skipped : line list * {way : string, path : string} -> line option
```

`skipped (ls, {way, path})` is the line that skips the test of `path`
in `way`, if one does.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-skipped.way"></a>`way` | `string` |  |
| <a name="fld-skipped.path"></a>`path` | `string` |  |

### <a name="type-outcome"></a>`outcome`

```sml
datatype outcome = Pass | Fail | Expected of line | Unexpected of line | Flaky of line
                 | Quarantined of line | Expired of line
```

What a test that ran comes to, given the lines.

[`Pass`](#con-pass) and [`Fail`](#con-fail) where no line speaks; [`Expected`](#con-expected) for a strict line's
failure, and [`Unexpected`](#con-unexpected) for its pass; [`Flaky`](#con-flaky) for a lenient line;
[`Quarantined`](#con-quarantined) for a quarantined failure before its date, and [`Expired`](#con-expired)
for one after it.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-pass"></a>`Pass` |  |  |
| <a name="con-fail"></a>`Fail` |  |  |
| <a name="con-expected"></a>`Expected` | `line` |  |
| <a name="con-unexpected"></a>`Unexpected` | `line` |  |
| <a name="con-flaky"></a>`Flaky` | `line` |  |
| <a name="con-quarantined"></a>`Quarantined` | `line` |  |
| <a name="con-expired"></a>`Expired` | `line` |  |

### <a name="val-judge"></a>`judge`

```sml
val judge : line list * {way : string, path : string, label : string option, passed : bool, today : string}
            -> outcome
```

`judge (ls, {way, path, label, passed, today})` is what the test comes
to; `today` is the date as `YYYY-MM-DD`.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-judge.way"></a>`way` | `string` |  |
| <a name="fld-judge.path"></a>`path` | `string` |  |
| <a name="fld-judge.label"></a>`label` | `string option` |  |
| <a name="fld-judge.passed"></a>`passed` | `bool` |  |
| <a name="fld-judge.today"></a>`today` | `string` |  |

### <a name="val-failing"></a>`failing`

```sml
val failing : outcome -> bool
```

`failing oc` says whether `oc` fails the run.

**Example** `failing Fail andalso not (failing Pass)`

### <a name="val-stale"></a>`stale`

```sml
val stale : line list * {ways : string list, paths : string list, used : line list, today : string} -> line list
```

`stale (ls, {ways, paths, used, today})` is the lines of `ls` that are
stale after a run.

Those are a strict line that names a way in `ways` and is not in
`used` (the lines of the failures it expected), a skip line whose path
matches none of `paths`, and a quarantine past its date.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-stale.ways"></a>`ways` | `string list` |  |
| <a name="fld-stale.paths"></a>`paths` | `string list` |  |
| <a name="fld-stale.used"></a>`used` | `line list` |  |
| <a name="fld-stale.today"></a>`today` | `string` |  |

### <a name="val-describe"></a>`describe`

```sml
val describe : line -> string
```

`describe l` is `l` as its file and number say it, for a report.

---

<sub>Generated by runedoc from lib/test/runner/expectations\_sig.sml; do not edit.</sub>
