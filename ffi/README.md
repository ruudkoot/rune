# Runeffi source contracts

This directory separates original foreign inputs, target facts, and binding
policy. `docs/plans/runeffi.md` defines the delivery and milestone gates.
`contracts/` fixes the public SML surface before generated implementations
exist. It is not installed as a library yet.

* `sdl/upstream/` contains the 86 unmodified SDL 3.4.18 release headers and
  their original licence. `sdl/source.json` records every byte hash.
* `win32/source.json` identifies original Microsoft SDK 10.0.22621.0 inputs.
  The headers remain external; follow `win32/README.md` to acquire them.
* `libffi/source.json` pins the optional ABI engine. System libffi may be
  used when its version and target ABI are recorded in acceptance evidence.
* `targets/` contains initial ABI profiles, verified by native C probes.
  These facts do not depend on the width of the SML generator process.
* Each `inventory.json` maps every roadmap function to a public member,
  exact source declaration and implementation/test gate. `unresolved`
  annotations explicitly block safe binding generation until M2 reviews
  them; an inventory entry is not an implemented binding.

Fetch the source URLs in the manifests into `build/deps/downloads/`, verify
SHA-256 before extraction, and preserve original include relationships.
SDL headers can be reproduced by copying `include/SDL3/*.h` and `LICENSE.txt`
from that release archive. Do not patch the headers to accommodate a parser.
Generated SML is committed under `lib/ffi/sdl/generated` and
`lib/ffi/win32/generated`; `ffi` retains original inputs and binding policy.
Native binaries stay in target-specific build directories. `.build` files
never execute generation.
