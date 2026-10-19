# tyan-mlkit provenance

mlkit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/tyan.sml`.
All source modules/notices and adaptation patch are retained.

Thomas Yan; TIL adaptation by Allyn Dimock, hardwired input/driver
by Stephen Weeks in 2001. Retain this older array/polynomial helper
organization and original two-call normal profile, distinct from weeks4
and the modern modular SML/NJ variant. Keep F17, cyclic-u6 strings and
actual leading-term/term-count output. Suppress only progress prints;
large selects twenty calls. Source explicitly records benchmark permission
from Thomas Yan; the original notice is retained.

Complete computed traces influence a Word32 checksum; empty output fails.
No measured causal attribution is claimed. See the rewriting/Geobucket
references in [the literature](../literature.md).
