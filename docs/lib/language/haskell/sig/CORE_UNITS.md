# signature CORE_UNITS

[Haskell 98 front end](../README.md) &rsaquo; Languages &rsaquo; **CORE_UNITS**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 10 of 10 entries documented |
| Tests | not listed |
| Source | [lib/language/haskell/coreunits\_sig.sml](../../../../../lib/language/haskell/coreunits_sig.sml) |

## Synopsis

```sml
signature CORE_UNITS
structure CoreUnits :> CORE_UNITS
```

| Implementation |  | Source |
| --- | --- | --- |
| [`CoreUnits`](../str/CoreUnits.md) | Core in units (the haskell98 roadmap's M21): units joined into one program. A type is the same in two units where its declaration prints the same, and an import is at its definition's type where the types print the same, since an interface gives a client the exporter's declaration and type as they are (HsIface). | [lib/language/haskell/coreunits.sml](../../../../../lib/language/haskell/coreunits.sml) |

Core in units (the haskell98 roadmap's M21): a program of several units,
each a Core program that names what it takes of the others, a value by
an import (`(import x TYPE)`) and a type by a copy of its declaration,
joined into one program, which Core's interpreter runs and a compile
whole takes.

## Interface

<pre>
signature CORE_UNITS =
sig
  exception <a href="#exn-error">Error</a> of string
  val <a href="#val-join">join</a> : Core.program list -&gt; Core.program
  val <a href="#val-unresolved">unresolved</a> : Core.program -&gt; string list
  val <a href="#val-uses">uses</a> : Core.decl -&gt; {<a href="#fld-uses.values">values</a> : string list, <a href="#fld-uses.types">types</a> : string list, <a href="#fld-uses.cons">cons</a> : string list}
  val <a href="#val-reach">reach</a> : Core.program * string list -&gt; Core.program
  val <a href="#val-index">index</a> : Core.program -&gt; string * string list
  datatype <a href="#type-unitcore">unitCore</a> = <a href="#con-indexed">Indexed</a> of string * (int -&gt; string) | <a href="#con-inhand">InHand</a> of Core.program
  val <a href="#val-reachindexed">reachIndexed</a> : unitCore list * string list -&gt; Core.program
  val <a href="#val-interface">interface</a> : Core.program * string list -&gt; Core.program
  val <a href="#val-fingerprints">fingerprints</a> : (string -&gt; string) -&gt; Core.program -&gt; (string * string) list
end
</pre>

### <a name="exn-error"></a>`Error`

```sml
exception Error of string
```

what makes units that do not join: a type two units declare apart, or
an import at another type than its definition's

### <a name="val-join"></a>`join`

```sml
val join : Core.program list -> Core.program
```

`join units` is the program of the units, in order, each type
declared once and each import given its definition.

A data type or newtype is kept where it is first declared, every unit
that declares it declaring the same; an import is dropped where a unit
defines its value, at the type the import gives it, and kept where
none does.

### <a name="val-unresolved"></a>`unresolved`

```sml
val unresolved : Core.program -> string list
```

`unresolved p` is the imports of p that no declaration of p defines,
in order

### <a name="val-uses"></a>`uses`

```sml
val uses : Core.decl -> {values : string list, types : string list, cons : string list}
```

`uses d` is what the declaration `d` names of the top level, each once.

Its values are the variables it names that no binder of it binds; its
types the type constructors it names; its constructors those it makes
or takes apart. A name may be in more than one, as `:` is a value of
the runtime and a constructor of the list.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-uses.values"></a>`values` | `string list` |  |
| <a name="fld-uses.types"></a>`types` | `string list` |  |
| <a name="fld-uses.cons"></a>`cons` | `string list` |  |

### <a name="val-reach"></a>`reach`

```sml
val reach : Core.program * string list -> Core.program
```

`reach (p, roots)` is what the values `roots` reach of p, in p's order.

A value reaches the values, types and constructors it names, a
constructor its type, and a type the types of its fields; an import
reached is kept, as a whole program has none (the haskell98 roadmap's
M21: units joined and compiled whole, what main reaches).

### <a name="val-index"></a>`index`

```sml
val index : Core.program -> string * string list
```

`index p` is the unit `p` as an index and its declarations' texts.

The index says of each declaration, by its number, what it is, its
name, what it makes and what it names, so that [`reachIndexed`](#val-reachindexed) reads
only the texts of the declarations a program reaches.

### <a name="type-unitcore"></a>`unitCore`

```sml
datatype unitCore = Indexed of string * (int -> string) | InHand of Core.program
```

A unit's Core as the reach is given it: by its index and a function
from a declaration's number to its text, or in hand.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-indexed"></a>`Indexed` | `string * (int -> string)` |  |
| <a name="con-inhand"></a>`InHand` | `Core.program` |  |

### <a name="val-reachindexed"></a>`reachIndexed`

```sml
val reachIndexed : unitCore list * string list -> Core.program
```

`reachIndexed (units, roots)` is `reach (join ps, roots)` where `ps` is
the units' programs, a declaration read only where it is reached.

A type is the first unit's that declares it, as [`join`](#val-join) keeps it.
Raises [`Error`](#exn-error) where an index is no index.

### <a name="val-interface"></a>`interface`

```sml
val interface : Core.program * string list -> Core.program
```

`interface (p, exports)` is what a client of the unit p needs of the
names it exports, as Core: each type it mentions declared, and each
value imported.

Each exported value is an import at its type, and each exported type
and every type the exports' types mention, through the types' own
fields, is declared as p declares it, in p's order; a name p does not
declare is a built-in type's, or another unit's the client has.

### <a name="val-fingerprints"></a>`fingerprints`

```sml
val fingerprints : (string -> string) -> Core.program -> (string * string) list
```

`fingerprints hash iface` is each declaration of the interface by its
name with its fingerprint, which moves where what a client reads of it
moves.

A type's is its recursive group's: the hash of the group's
declarations and of the fingerprints of the types outside it that they
mention, so that a group hashes as one. A value's is the hash of its
type and of the fingerprints of the types it mentions. A type no
declaration of the interface gives is its name.

---

<sub>Generated by runedoc from lib/language/haskell/coreunits\_sig.sml; do not edit.</sub>
