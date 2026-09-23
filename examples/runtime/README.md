# Runtime

`Runtime` is Rune's own: what a program can ask about the machine it is
running on, and what it can tell that machine to do. It is not in the Standard
ML Basis Library, so nothing here ports
([docs/generated/basis/sig/RUNTIME.md](../../docs/generated/basis/sig/RUNTIME.md)).

| Program | What it shows |
| --- | --- |
| `stats.sml` | the counters the VM keeps: instructions, bytes, objects, collections, and what a list cell costs |
| `profile.sml` | `profile`, and how to take the cost of measuring out of what it reports |
| `trace.sml` | the call stack, from a handler and from an exception nothing handles |
| `checkpoint.sml` | `save`, and `runevm --restore` taking the program up again |
| `become.sml` | `restore`, which makes a running program become the world in an image |

```sh
bin/rune --lib lib examples/runtime/stats.sml -o stats.rbc && bin/runevm stats.rbc
bin/runevm --count stats.rbc          # the same instruction count, from outside

bin/rune --lib lib examples/runtime/checkpoint.sml -o checkpoint.rbc
bin/runevm checkpoint.rbc             # writes checkpoint.img and stops
bin/runevm --restore checkpoint.img   # carries on, as often as you like

bin/rune --lib lib examples/runtime/become.sml -o become.rbc
bin/runevm become.rbc                 # becomes checkpoint.img from inside
```
