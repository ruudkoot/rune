# Standard ML generators

`make bin/rune-generate bin/rune-inventory` builds the post-bootstrap tools.
The generated launchers pass arguments to the SML worker. Pre-host build-file,
version, host provisioning and installation adapters remain independent.

| Mode | Contract |
|---|---|
| `annotations [--check \| --out FILE]` | Host deviations to committed documentation annotations; atomic output |
| `basis-signatures [--check] [LIBDIR]` | Specification skeletons, stable dependency order and token comparisons; existing signatures are preserved |
| `host-basis OUTDIR` | Primitive signature, host source rewrites, prelude and ordered file table |
| `xc2-mlton OUTDIR [MLTON_LIB]` | Patched MLton library, constants, generated primitive families and shims |
| `xc2-mlkit OUTDIR MLKIT_LIB` | Patched MLKit sources, typed primitive rewrites and stubs |
| `xc2-polyml OUTDIR POLYML` | Poly/ML source order, runtime dispatch rewrites and shims |
| `xc2-smlnj-legacy OUTDIR SMLNJ` / `xc2-smlnj-dev OUTDIR SMLNJ` | Private CM observation, patched init/Basis sources and runtime stubs |
| `structures [--out DIR] [--configs LIST] [-j N]` | Complete host availability probes and compatibility table |
| `mlb-flatten [--vars 'NAME=VALUE ...'] FILE.mlb` | Ordered source/scoping events, with one expansion per MLB |
| `top-structures FILE...` | Top-level structure names, ignoring comments and strings |
| `flatten FLAT OUTDIR BASIS [HOST SETTINGS...]` | Scoped save/restore files and rewritten sources; HOST is mlton, mlkit, polyml or smlnj |
| `trim-lib OUTDIR FILE...` | The Rune library dependencies of a host shim |
| `rewrite-HOST [SETTINGS] FILE` | Standalone source rewriting; settings: --table, --typed, --consts, --ctypes, --ambiguous |
| `mlton-prims [SETTINGS] TABLE` / `polyml-order BUILD.sml` | Primitive families / Poly/ML library source order |
| `perf KIND PARAMS...` | Module-language performance inputs, including signatures, sharing and nested functors |
| `fxp` | The fixed XML input, preserving the original binary64 LCG and recursive length output |
| `entities` / `digest-vectors` | Named HTML references / independently established cryptographic vectors |
| `unicode [UCD_DIR] [--out-root DIR]` | Five Unicode tables and nine conformance datasets from pinned sources |
| `inventory [OPTIONS]` | Pinned benchmark discovery, classification, provenance and TSV publication |

Run `bin/rune-inventory` for the inventory mode directly. Its `--query` interface
retains the JSON operations used by the independent handwritten regressions.
`--source ID=DIR` requires all five clean pinned trees; `--check` compares their
complete discovery and metadata against the committed inventory. `--write`
validates before publishing. The model reads upstream descriptions and source
headers without executing benchmark programs or evaluating upstream Make/shell
expressions. SHA256 source identities include ordered relative filenames and
raw bytes. Paths sort by components, matching the previous producer.

All parsing, rewriting, ordering, classification, comparison and formatting is
SML. External host compilers supply library-order and availability observations;
patch applies the reviewed patches, curl transports pinned source bytes, and Git
supplies repository identity. Host preparation includes generator payload and
data identities in its cache key.

Unicode source SHA256 checks precede parsing. An independent normalizer built
from the raw UCD checks all 20,171 normalization records; generated runtime
tables do not act as their own oracle. Frozen identifier exclusions and security
invariants are checked before any table is published. `--out-root` supports
repeat/concurrent generation in isolated trees. Atomic writes reserve unique
names across process namespaces.

`data/` contains reviewed configuration, frozen inputs and independent oracles.
HTML references retain the Python 3.12.3 WHATWG dataset. The digest vectors retain
the original Python hashlib/HMAC answers; regeneration never derives expected
answers from the implementation being tested. Existing generated comment headers
retain their historical producer names for byte agreement and source lineage.

The inventory retains the previous FEM key `data.3` and the reviewed family-text
choices for linear/para. They are observable effects of the former producer's
variables and are preserved explicitly during this migration. MLton's intermediate
C-type map now uses canonical name order; entries and all final generated sources
agree. The retirement ledger records the original producer blob identities.
