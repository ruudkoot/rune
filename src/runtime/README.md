# Runtime source layout

The current VM files are intentionally small bootstrap boundaries. As runtime
behavior grows, keep format validation, VM execution, memory management,
platform adapters, and CLI behavior in separate modules. The VM must be
executable against byte arrays without a host filesystem or process.
