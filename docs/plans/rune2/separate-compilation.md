# Rune 2: modules, the build system, separate compilation and units

**Rune 1 is Standard ML '97, and stays so.** The roadmap beside this one, [build-system-v2.md](../build-system/build-system-v2.md), gets as far as that allows: it makes a build fast, sound and modular without changing what a program means. This document asks what changes once Rune no longer aims to be SML '97: what a unit is, how it says what it needs, what a module system with namespaces looks like, and what one intermediate language could do for a build.

It rests on that roadmap's experiments and adds none of its own. Each number names its experiment there. It is a plan for a language change, and it commits nothing. Sections that leave a choice end in it.

**What the evidence says, in short:**
- **The top level already fits (E8).** Headers, one module per file and opaque ascription do not: see the table.
- **The prize is not a firewall.** Over 85 replayed edits only 0.8% of rebuilt units are ones a firewall alone could avoid, and none came from the compiler's real commits (E13). What Rune 2 buys is different: units compiled before their dependencies exist, interfaces a reader can read, and names that are not global.
- **Mid can stay where it is.** Of three captures tried, ToMid's and after expand cost the same; after simplify costs 1.41 times on HaMLet and 1.50 on MLton (E14).

## What stays, and what changes

**Stays:** the Core language, type inference, the value restriction, pattern matching and exceptions; structures, signatures and generative functors; the Basis Library's interface; the REPL as a way of working.

**Changes**, each with its reason and what it breaks. "Fits" counts units already in the shape, by the parser, as shared units (E8).

| Change | Why | What it breaks |
|---|---|---|
| **A unit says what it needs,** in a header naming its imports (HOL4's `Ancestors`/`Libs` is a working precedent) | Cardelli's `E |- a : A`: a fragment states its assumptions. It ends a build file's order, and every prefix | Every file gains a header. `Deps`' graph gives most of it once it knows a prelude's fixity, since it stops on HOL4 today; an edge on another unit's effect is not derivable (E6) |
| **A shared unit is one module named after the file.** No top-level `val`, `fun`, `exception`, `datatype` or `open` | Top-level names readable from syntax. Blume's restrictions, made the language | Top-level `val`/`open` rules, by the parser: Rune 84 of 84 and 318 of 318, MLton 599 of 599, HaMLet 212 of 213, HOL4's closure 741 of 743. One module per file is not met: MLton 228 of 599 shared units declare more than one, the Basis 58 of 259 |
| **Entry units stay free,** with all of today's top level | A program is a sequence of effects; a script is an entry unit | Nothing but the header. HOL4's 1,248 scripts are these |
| **A prelude becomes a named import** of a language extension: fixity and opens that a unit asks for | `Overlay.sml` is an unstated prelude that 142 of HOL4's closure's units need in order to parse | HOL4's `src` (263 units depend on fixity), its scripts (234 + 803), HaMLet (27). A header line each |
| **Fixity is exported,** and activated by import | The Definition's §2.6 keeps it out of the basis: it "affect[s] only parsing". That is why `Deps` can be wrong. It belongs in the static layer | As above |
| **Signatures and functors may live in structures** | Without this no library can have a namespace (SMLSC, Elsman). It is what bounds D9 in Rune 1 | Nothing existing: an extension |
| **Hierarchical names,** by import path, not by convention | Clash by construction, not prefix | The `Rune*` convention, by choice |
| **A signature on every structure in a shared unit's interface** | An interface a reader can read, which is the only reason in the default mode: D17 finds signatures needed by firewalls alone, and a compile against an interface alone is the separate mode's. SMLSC's footnote: `local datatype t = A in val x = A end` has no source signature | Rune's bare structures 247 of 532, MLton's 25 of 102, HaMLet's 28 of 120, HOL4's closure 48 of 390. The compiler can print them; an inferred one has no source form in some cases, which then need naming |
| **Manifest types everywhere** (Leroy), with transparent ascription gone | "Signatures become complete module specifications" | Rune's 124 `:` bindings, MLton's 66. `where type` covers them; `structure X : S` becomes `:> S where type ...`. On paper, not run. With the bare ones, 371 of Rune's 532 bindings, 84 of HaMLet's 120, 91 of MLton's 102 change |
| **Order is derived for shared units** | Written order stops being a semantics, since nothing depends on it. E6: unit bytes did not depend on legal order, on the 2-3 orders tried, once names are unique | HOL4's hidden dependence: `Theory.ancestry` and `srw_ss` order, in two lines of output. A unit that relies on another's effect names it |
| **Initialisers** run in dependency order, named on the unit that needs one | The Definition has no answer, since it has one file | As above |
| **Overloading, flexible records and free type variables end at a unit,** as they do by default now | Nothing crosses in default modes (E5) | Almost nothing: 13 of 1,514 regression programs need `--free-tyvars=later-monotype`, mostly tests of the mode |

**What Rune 2 does not change, though the Definition allows it:** top-level effects in an entry; the REPL's Chapter 8 behaviour; generative functors as the default.

## Units

**A unit declares what it expects.** Its header says what it imports, by logical name, and its body, what it exports. A unit compiles against the static layer, and by default the ABI layer, of what it names, and only those: it depends on nothing else, not on another unit's name, position or order.

**Compiling before a dependency exists.** Structures have this already (`_virtual`, `_dynamic`), and Rune 1 gives it to functors: `functor F = _virtual (X : A) : B` (D22, M21). Rune 2 makes it the normal case: a unit against an interface file, or an interface a unit carries. A functor's ABI fingerprint holds record shape, slot order, descriptors and the calling convention.

**Incremental against separate.** Rune 1 is incremental, by incremental's D2: a unit is compiled against the actual bases before it. Rune 2 offers both:
- **Separate:** against interfaces alone. A client's compile needs no implementation, and a change behind an unchanged interface recompiles nothing.
- **Incremental:** against the implementation's ABI layer, so known calls and layouts cross. This is Rune 1 today, and the default.

**The firewall question stays open.** Separate compilation across an opaque type means a client cannot know its layout. The ways out are all known and all cost:
- uniform representation at the boundary (OCaml's way, deduced from reading: a client needs nothing from `.cmx` to lay out a value);
- descriptors, as a functor already passes for its argument's datatypes (functors-units' D4);
- layout in the interface, which is what Rune 1's ABI layer holds. It leaks a representation change as an interface change, and that is the honest cost of unboxed layout;
- abstract Mid resolved at concatenation (Rune 1's D18 C), which gives up S42 or needs a budget gate.

E13 prices lost inlining, not representation: at least 2.4 times at run time on `checksum`, the worst of six, with layouts behind opaque types not measured and no firewall prototyped. It sets the ceiling on what is gained: 31 of 4,048 units. **So the default stays see-through,** with a separate mode for a library that wants a stable ABI, which is a plugin's case, not a build's. Dune's firewall is a development profile, which argues for a profile: open.

**To decide:** whether a stable-ABI mode is wanted at all before a plugin needs one.

## The build system

With imports in source, a build file says much less. What remains is what a program cannot say about itself:
- the workspace, and where libraries are (Rune 1's D4);
- a library's exports, friends and views;
- which implementation a virtual module has;
- generated sources and preprocessors;
- options.

Order and dependencies are gone from it: they are in the sources. Rune 1's plan stays the contract, and is now computed from a scan of headers: a syntax-only pass, not measured. This is what would close the editor's planning cost: at 100k files stock Rune 1 reads every build to find a file's context, Rune 1 after its M20 reads the changed set, and in Rune 2 a file's context is its own header.

**Libraries and namespaces.** A library is a directory, as in Rune 1, and its logical name is an import path. A top-level name is a path, not a global: `import json/Parser`. Renaming is at import. A view is an import of a named subset. Two libraries cannot clash: a clash needs a scope that imports both under one name.

**A package manager** then needs a version in a logical name, which Rune 1's D3 keeps room for, and a resolver.

A program may still be a list of files, as entry units: a one-file program must stay one file.

## One intermediate language in a unit

The brief asks for one IR that can go into a unit, efficiently combinable, with three levels: fast incremental, well-optimised incremental, and near-whole from units, cheaper than a whole compile. E14 measured where such an IR can sit. Today Mid goes into a unit as ToMid made it, so per-unit optimisation is never reused. Only Mid's capture was tried: Lambda and Low were not.

| Capture, then whole passes | Compile | Code | Run | HaMLet, run | MLton, run |
|---|---:|---:|---:|---:|---:|
| ToMid's (today) | 1 | 1 | 1 | 1 | 1 |
| After expand | 0.996 | 1.000 | 1.000 | 1.000 | 1.001 |
| After simplify | 1.001 | 1.011 | 1.072 | 1.407 | 1.502 |

Geometric means over 14 programs, against a whole compile from ToMid's Mid. Single-file programs hide the cost.

**After simplify fails** because functor copies come late. `functor_marker` is removable, Simplify deletes it, and `expand` leaves a call; with markers kept, `workers` has split the functor's function and only a wrapper is copied (deduced, E14). MLton's functions fall from 22,751 to 17,643. So **an IR optimised before linking cannot be optimised well after it while functors are expanded late.** Mixed levels also break, which puts the capture level in the config.

**The three levels:**

| Level | How | What it costs | Evidence |
|---|---|---|---|
| Fast incremental | Units, as Rune 1 | Run 1.09-1.59 times whole, in the programs measured | E13, E14 |
| Well-optimised incremental | Units, plus a summary of small functions and bodies fetched on demand | `checksum` 1.27 to 1.09, `mlyacc` 1.22 to 1.14; compile +21-54%, basis 3.3 times. `hamlet`, the benchmark, gets worse at tier 2, and blind import fails, so a heuristic is needed | E14, one case |
| Near-whole from units | Mid as captured today; whole passes over the concatenation, from cache | MLton: 129.1G against a 356.4G whole compile, bytes equal to whole | E14 |

**A summary,** on paper only: MLton in units has 34,565 functions; at about 20 bytes each that is 0.7 MB, 3% of its bases. An import is an implementation dependency, so it belongs in a client's key, and it worsens cut-off. That is the trade this level makes: ThinLTO's, with the same remedy, importing only what pays.

**What replaces S42.** S42 says units then whole equals whole, byte for byte, and it has been the test of the cached path. At the capture after expand, bytes equal whole's on 3 of 14 programs, and the rest differ in function order and numbering alone, on the four programs checked. A canonical function order could keep S42 there, or nearly: multi-file programs add a few functions, the compiler 41 of 6,453, MLton 51. **So S42 stays only at today's capture.** If Mid after optimisation is ever wanted, expansion must move before capture, S42 ends by construction, and its replacement can only be a semantic differential: same output, exit and traces, as `make check-levels` runs, plus MidLint.

**The IR.** The proposal is today's capture, ToMid's, with a summary. After expand gains nothing measured and loses byte equality on 11 of 14 programs; adopt it only if a pass that needs it appears. One traversal writes and hashes it (Rune 1's D21). A second IR is not needed for this: three module IR stages (ideation3:2672) have no evidence behind them.

**To decide:** whether a level-two build is worth a heuristic. It needs a study across more programs, and the question of tier 2 against bytecode that `hamlet` raises.

## What Rune 1's roadmap carries over

- **Carried as is:** logical names (D3), the workspace (D4), the plan as contract (D5), one store with layers (D24), layers of an interface with per-export hashes (D1), the footing's obligations (D20), friends (D11).
- **Promoted to the language:** the three classes of unit (D17) and the well-formed rules; fixity as an export (D8); views (D8, D12).
- **Must not be foreclosed by Rune 1:**
  - a version in a logical name;
  - a static layer with no spans and no imports' identities, since it is what an interface file becomes;
  - the canonical plan's format, which gains a scan of headers;
  - no feature of Rune 1's build language that imports in source would have to emulate. This is one more reason not to add a term layer (D29).

**A sequence, as a sketch.** The language decision is the owner's, so this orders the work and commits to nothing. Each step waits for a decision:
1. Rune 1's M3, M4 and M9 first: logical names, layers and the plan.
2. A scan of headers, and D17's checker made an error for shared units.
3. Interfaces: signatures on shared units, and a compile against them.
4. Namespaces: signatures and functors in structures, and hierarchical names.

## The migration, and the REPL

**From SML '97.** A tool, working on the parser and `Deps`, prints a header for each file, adds signatures from what was inferred, and rewrites `:` to `:>` with `where type`. E8 gives its size: small on libraries. HOL4's scripts in `src` have a header already, 334 of 334; those in `examples` mostly do not, 17 of 918. What it cannot do alone is the units E8 flags: preludes, and bare structures with no source signature.

**Rune 2 reads SML '97.** A mode, by build, for a library or a unit. SML '97 stays what Rune is built on and what hosts compile: a Rune 2 compiler is written in the part of Rune 2 that is SML '97, until the hosts are given up. How a header survives the hosts is open: it must be something a host's parser skips.

**The REPL** keeps the Definition's model, in which every declaration extends a basis. E7 finds the REPL already holds nearly all of it: 325 of 330 `tests/lang` programs through `use`. In Rune 2 a session is an entry unit growing a line at a time, with imports added as it goes.

## Open questions

- **Higher-order modules and applicative functors.** Not needed by anything in the build (D23). A separate roadmap, on their own merits. ideation3's generativity as an effect on the functor arrow (:1390-1404, :2254) and application as a path (:1615-1695) are where it starts.
- **Recursive units.** MixML solves recursive separate compilation, and unifies structures and signatures. It is the one source pointing that way, read only in part.
- **Intermodule information.** Elsman's framework allows arbitrary compile-time information across units, open terms, with proofs. Shao's `binfo` is the type-directed form. They are the ground for level two.
- **Representation.** `freshtype` and coercions (ideation3:2740-3892), with roles as the known hard part, and implementation families (:5300-6595): other Rune 2 plans.
- **Effects.** A unit's top-level effects as a declared property. E6 found no cheap proxy.
- **What not to do.** The fully functorised style: "very cumbersome" (Appel & MacQueen), "does not scale well" (*The history of Standard ML*). Rune 2's parameterisation stays with functors where they earn it.
