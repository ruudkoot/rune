# structure Gen

[Property testing](../README.md) &rsaquo; Property testing &rsaquo; [Structures](../structures.md) &rsaquo; **Gen**

|  |  |
| --- | --- |
| Signature | [`GEN`](../sig/GEN.md) |
| Status | required |
| Members | 43 |
| Tests | not listed |
| Source | [lib/test/property/gen.sml](../../../../../lib/test/property/gen.sml) |

## Synopsis

```sml
structure Gen :> GEN
```

## Members

What each means is on [`GEN`](../sig/GEN.md); the types are this structure's own.

|  | Member | Is |
| --- | --- | --- |
| type | [`gen`](../sig/GEN.md#type-gen) | *a type of its own* |
| exception | [`Discarded`](../sig/GEN.md#exn-discarded) |  |
| exception | [`Generated`](../sig/GEN.md#exn-generated) |  |
| val | [`array`](../sig/GEN.md#val-array) | `'a gen -> 'a array gen` |
| val | [`bind`](../sig/GEN.md#val-bind) | `'a gen -> ('a -> 'b gen) -> 'b gen` |
| val | [`bool`](../sig/GEN.md#val-bool) | `bool gen` |
| val | [`char`](../sig/GEN.md#val-char) | `char gen` |
| val | [`code`](../sig/GEN.md#val-code) | `int -> int gen` |
| val | [`draw`](../sig/GEN.md#val-draw) | `'a gen -> {calls : ({address : Word64.word, path : Word64.word list} * string) list ref, cleanups : (unit -> unit) list ref, effects : string list ref, over : bool ref, seed : Word64.word, sequences : {length : Word64.word, marks : Word64.word list option, parts : Word64.word list} list ref, set : {address : Word64.word, bound : Word64.word, kind : PropertySource.kind, path : Word64.word list, word : Word64.word} list, size : int, trail : {address : Word64.word, bound : Word64.word, kind : PropertySource.kind, path : Word64.word list, word : Word64.word} list ref, work : int ref, zeros : Word64.word list list} * {address : Word64.word, path : Word64.word list} -> 'a` |
| val | [`elements`](../sig/GEN.md#val-elements) | `'a vector -> 'a gen` |
| val | [`filter`](../sig/GEN.md#val-filter) | `('a -> bool) -> 'a gen -> 'a gen` |
| val | [`fix`](../sig/GEN.md#val-fix) | `('a gen -> 'a gen) -> 'a gen` |
| val | [`frequency`](../sig/GEN.md#val-frequency) | `(int * 'a gen) list -> 'a gen` |
| val | [`function`](../sig/GEN.md#val-function) | `('a -> Word64.word) * 'b gen -> ('a -> 'b) gen` |
| val | [`functionOf`](../sig/GEN.md#val-functionof) | `('a -> Word64.word) * ('a -> string) * ('b -> string) * 'b gen -> ('a -> 'b) gen` |
| val | [`int`](../sig/GEN.md#val-int) | `int gen` |
| val | [`intInf`](../sig/GEN.md#val-intinf) | `IntInf.int gen` |
| val | [`intInfRange`](../sig/GEN.md#val-intinfrange) | `IntInf.int * IntInf.int -> IntInf.int gen` |
| val | [`intRange`](../sig/GEN.md#val-intrange) | `int * int -> int gen` |
| val | [`largeRange`](../sig/GEN.md#val-largerange) | `IntInf.int * IntInf.int -> IntInf.int gen` |
| val | [`list`](../sig/GEN.md#val-list) | `'a gen -> 'a list gen` |
| val | [`listOf`](../sig/GEN.md#val-listof) | `int gen -> 'a gen -> 'a list gen` |
| val | [`map`](../sig/GEN.md#val-map) | `('a -> 'b) -> 'a gen -> 'b gen` |
| val | [`map2`](../sig/GEN.md#val-map2) | `('a * 'b -> 'c) -> 'a gen * 'b gen -> 'c gen` |
| val | [`oneOf`](../sig/GEN.md#val-oneof) | `'a gen list -> 'a gen` |
| val | [`option`](../sig/GEN.md#val-option) | `'a gen -> 'a option gen` |
| val | [`order`](../sig/GEN.md#val-order) | `order gen` |
| val | [`pair`](../sig/GEN.md#val-pair) | `'a gen * 'b gen -> ('a * 'b) gen` |
| val | [`primitive`](../sig/GEN.md#val-primitive) | `({calls : ({address : Word64.word, path : Word64.word list} * string) list ref, cleanups : (unit -> unit) list ref, effects : string list ref, over : bool ref, seed : Word64.word, sequences : {length : Word64.word, marks : Word64.word list option, parts : Word64.word list} list ref, set : {address : Word64.word, bound : Word64.word, kind : PropertySource.kind, path : Word64.word list, word : Word64.word} list, size : int, trail : {address : Word64.word, bound : Word64.word, kind : PropertySource.kind, path : Word64.word list, word : Word64.word} list ref, work : int ref, zeros : Word64.word list list} * {address : Word64.word, path : Word64.word list} -> 'a) -> 'a gen` |
| val | [`pureOf`](../sig/GEN.md#val-pureof) | `('a -> Word64.word) * ('a -> string) * ('b -> string) * 'b gen -> ('a -> 'b) gen` |
| val | [`real`](../sig/GEN.md#val-real) | `real gen` |
| val | [`resize`](../sig/GEN.md#val-resize) | `int -> 'a gen -> 'a gen` |
| val | [`resource`](../sig/GEN.md#val-resource) | `'a gen * ('a -> unit) -> 'a gen` |
| val | [`return`](../sig/GEN.md#val-return) | `'a -> 'a gen` |
| val | [`sample`](../sig/GEN.md#val-sample) | `'a gen -> Word64.word -> int -> 'a` |
| val | [`sized`](../sig/GEN.md#val-sized) | `(int -> 'a gen) -> 'a gen` |
| val | [`string`](../sig/GEN.md#val-string) | `string gen` |
| val | [`triple`](../sig/GEN.md#val-triple) | `'a gen * 'b gen * 'c gen -> ('a * 'b * 'c) gen` |
| val | [`unit`](../sig/GEN.md#val-unit) | `unit gen` |
| val | [`vector`](../sig/GEN.md#val-vector) | `'a gen -> 'a vector gen` |
| val | [`word`](../sig/GEN.md#val-word) | `word gen` |
| val | [`word64`](../sig/GEN.md#val-word64) | `Word64.word gen` |
| val | [`wordBits`](../sig/GEN.md#val-wordbits) | `int -> Word64.word gen` |

---

<sub>Generated by runedoc from lib/test/property/gen.sml; do not edit.</sub>
