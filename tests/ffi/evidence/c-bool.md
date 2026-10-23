# C Boolean conversion acceptance

Date: 2026-10-23. C11 6.3.1.2 requires conversion to `_Bool` to distinguish
zero from nonzero, rather than reduce the value modulo two. The rule is in
[WG14 N1570, section 6.3.1.2](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n1570.pdf#page=69).
The model's unsigned width-one type is uniquely `_Bool`; ordinary target
integer widths start at eight bits.

`CInteger.convert` now implements that rule. `CExpression` casts delegate to
the same conversion instead of maintaining a separate Boolean special case.
Direct conversion and parsed-expression fixtures cover zero, positive and
negative values, including even values and magnitudes above one byte.

Focused validation used the immutable M5 compiler with this checkout's
library and its native register VM:

```text
rune --library language/c --library test/unit tests/lib/language/c/target.sml
runevm /tmp/runeffi-bool-target.rbc
  92/92 PASS
cc -std=c17 -O2 -Wall -Wextra -Werror tests/ffi/oracle.c
   tests/ffi/fixture.c tests/ffi/ownership.c -o /tmp/runeffi-bool-oracle
/tmp/runeffi-bool-oracle
  30 native C oracle checks PASS, including six Boolean conversions
runedoc --library language/c --check
  50 files current; comment lint PASS
```
