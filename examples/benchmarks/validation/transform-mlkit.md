# Transform ML Kit compilation outcomes

The strict smoke and normal applications pass on managed ML Kit 4.7.23.
The lazy normal application's compilation fails with code 255 and
"Cannot allocate memory" under the normal 4 GiB address-space limit.
The lazy smoke application reports load 1, exit 0 with an empty compiler
log under its 1 GiB limit; retain compile-error without assigning a cause.

Both combined semantic-target compilations fail with allocation diagnostics
under 1 GiB, before executing assertions. An explicit 4 GiB repeat and a
smaller lazy-only application under 1 GiB fail similarly. Their raw sources,
commands, compiler logs and child exit records remain in the archive.

No compiler/runtime change, host-specific kernel, result relaxation or
increased canonical quota is introduced. Other engines and hosts validate
the original complete observations. Compilation failures remain separate
from incorrect results, runtime memory limits and accepted measurements.
