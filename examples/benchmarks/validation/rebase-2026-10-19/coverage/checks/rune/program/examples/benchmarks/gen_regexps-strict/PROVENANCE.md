# gen_regexps-strict provenance

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `imaginary/gen_regexps/Main.hs` and its NofibUtils hash.
The source identifies Wentworth's version and an RJE output adaptation; fuller
authorship and an individual licence are unspecified, recorded as gaps. Preserve
source, Makefile and fixtures with their notices and SHA256 identities.

This is an expansion workload for literals, [a-b] alphabetic ranges and <u-v>
zero-padded numeric ranges, not a general regexp matcher. Ascending/descending
ranges, inclusive endpoints, padding width and expansion order are unchanged.
Selected inputs are ASCII and well-formed; SML parsing explicitly rejects other
literal characters and malformed numeric ranges. Numeric endpoint parsing and
shared representation are ordinary SML97. Both variants recompute expand(rest)
inside each outer range choice, as in the source comprehension. A compiler may
hoist common suffixes; that is a performance hypothesis, not assumed sharing.

Preserve the nofib polynomial hash with explicit wrapping 64-bit arithmetic,
matching the reference GHC Int width. The driver also observes character count;
both hash and count must agree. Python Cartesian-product enumeration and an
original GHC observer agree on all selected profiles. Output is a consumed
character-count sum instead of 500 printed hashes. Normal retains the original
NORM expression with one repetition; large retains SLOW with 500. Smoke uses
[a-b]<09-10> to cover padding; original FAST remains in the retained Makefile.

The lazy port memoizes both expansion-list and character-list heads/spines;
concatenation and hashing consume prefixes without materializing all output.
The strict variant creates finite character lists and their concatenation
before hashing. Both share parsing, ranges and modular semantics. Allocation,
fusion, suffix recomputation and retention are source hypotheses until measured.
Large SML execution is not universally claimed. References: pinned original
source/history comments and the nofib literature survey.

Legacy SML/NJ 110.99.9 rejects the lazy normal profile: repeated read-only
observers return different hashes for the same 622080 characters. Modern 2026.2,
MLton, Poly/ML and Rune agree with the reference. Keep the failed result rejected;
no alternate fixture or host workaround is introduced. Its precise cause is
not isolated; the known legacy GC-root bug is a candidate explanation.
