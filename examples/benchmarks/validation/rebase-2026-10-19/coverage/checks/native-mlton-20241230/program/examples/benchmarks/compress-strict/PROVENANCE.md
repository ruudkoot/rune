# compress-strict provenance

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `real/compress/Main.hs` and its required modules.

## History and notices

Paul Sanders, Systems Research Division, British Telecom Laboratories,1992,
is named in Main/Encode/BinConv and the retained correspondence. The program
cites Terry A. Welch's1984 compression paper. Original modules, build settings,
input/output files, README and MAIL have retained notices and SHA256 identities.
No individual program/dataset redistribution notice is supplied in the pinned
files; this remains an explicit provenance gap. README identifies John van
Groningen's separate Lzw/C/Clean alternatives, which the default driver does
not run; they remain separately inventoried rather than treated as duplicates.

## Algorithm and known variants

Preserve fixed 12-bit LZW with the persistent prefix tree,256 initial byte codes,
next code 256, dictionary freeze at 4096, and code_string's exact recursive update
and EOF rules. The initial alphabet uses the original foldr insertion order over
all 256 listed keys: despite the source's balanced-list description, the resulting
root is 255. This source-derived shape is checked against original GHC.
Packing pairs emits x div16, (x rem16)*16+y div256, y rem256. A final single code
emits n div16,n rem16: its trailing nibble is unshifted. Keep this source format;
no standard-header/variable-width compressor or mutable dictionary replaces it.

## SML translation and runtime questions

Both variants instantiate one SML97 algorithm with suspension adapters. The
lazy adapter memoizes code heads/spines, key/value/extension fields, shared
code_string results, path updates and next-code arithmetic. EOF can leave the
unused updated table/counter unforced. The strict adapter materializes these
updates and finite code/output streams eagerly, changing allocation and retention.
All encoder/counter/packing values fit 31 bits for the selected files. Source
hashing retains wrapping signed 64-bit GHC Int semantics through Word64; the
added repetition sum is IntInf. No host-specific arithmetic workaround is used.

BinIO reads exact bytes and fixtures. Full SML byte strings plus cursor indices
replace Haskell's lazy input character lists; compressed output is materialized
before hash/checking. This changes representation, demand of file contents,
copying and retention. Initial prefix tables remain shared across repetitions.
All31 expected cut outputs are preloaded once per run; every compressed byte is
checked before hashing. Added fixture I/O, full-byte comparison and accumulated
hashes replace 200 printed hashes and are explicitly included in measurements.
Prefix sharing, delayed copies, branch/search depth, dictionary saturation and
forcing remain source-derived performance questions until measured.

## Inputs, validation and references

Smoke takes the first 64 bytes of the original FAST input and one repetition.
Normal retains FAST 1944 bytes with 200 repetitions; large retains NORM 10755 bytes
with 200 repetitions. Original SLOW 39864 bytes and fixtures remain available in
upstream provenance. Every iteration preserves truncation by i mod31. The
Makefile identifies enwik8 as input origin; original byte identities are pinned,
not reconstructed from a newer Wikipedia dump. UTF-8 dataset bytes are compressed
as bytes, matching the original binary input mode, rather than decoded/reencoded.
[Mahoney's corpus description](https://mattmahoney.net/dc/textdata.html) identifies
enwik8's parent as a 2006 Wikipedia dump; it does not resolve the individual notice
gap in these copied subsets.

Original GHC and an independent dictionary-map LZW plus the exact packing rule
agree on all 31 cut byte fixtures per profile. Normal/large all 200 hash samples
also agree with unchanged GHC. Boundary tests cover empty/odd/full-byte inputs,
initial table order, unneeded EOF counter demand and dictionary freeze using
fixed Word32 counter-generator data. Primary hosts/Rune validate selected smoke
and normal profiles. The combined two-functor semantic test crashes ML Kit 4.7.23
with StatObject.instance_with_types.wrong number of types; standalone benchmark
smoke programs compile/pass there. That test compile failure is recorded, not
worked around or accepted as a result. Large SML execution is not universally
claimed.

References: [Welch, A Technique for High-Performance Data Compression](https://doi.org/10.1109/MC.1984.1659158),
Computer 17(6),8-19(1984); retained Sanders correspondence/implementation and
[nofib literature survey](../literature.md). Paper ancestry, inspected source
behavior, and measured count findings remain distinct.
