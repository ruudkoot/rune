# nofib Veritas provenance

## Algorithm and workload

Execute the original scripted proof-editor session for the Veritas design
logic. Tokenize and parse a functional concrete syntax, manipulate terms,
declarations and signatures, build proof trees, apply tactics, track completion,
render the original X-interface requests and compute their modular hash.
The maintained nofib driver repeats the same session 400/4000/20000 times.

## History, authorship, revision and aliases

Use nofib b7391df4540ac8b11b35e1b2e2c15819b5171798, real/veritas.
The README is a letter to Kevin signed Gareth about running this program
on GRIP. Retain that stated role without assigning an unverified individual
copyright or inferring a redistribution grant. Individual original source,
comments, input files and notices are archived with exact identities.
Canonical common/NofibUtils.hs and the directory symlink target are separate.

Hanna, Daeche and Howells, Implementation of the Veritas Design Logic (1992),
is related implementation literature, identified by the authors' institution.
That bibliography is not a source identity for this precise historical
snapshot, nor does the README alone identify every author or porting role.
The name identifies this historical nofib program.

## Known variants

veritas-lazy memoizes finite syntax, term fields, attributes, proof trees and
request characters. veritas-strict evaluates those finite attributes eagerly.
Both preserve memoized state/output control, suspended action results, unused
pair components, finite token control and infinite response/identifier
streams. Both match the complete original session and all supplemental
protocol/editor-outcome controls.

The interface is a pure byte protocol over supplied scripted input. It does
not require a running X server or a network connection. Edlib's error
handlers are ordinary result/state combinators; no runtime effect-handler
feature is required.

## Translation and adaptations

Retain the original scanner, precedence algorithm, binders, source attributes,
signature lookup, de Bruijn-style indices, shifting, substitution,
term/type construction, proof rules, tree navigation, persistent history,
tactic validation and output request order. Keep the live command table and
original argument forms. Keep source optional database restore stubs and
the original commented inactive code as historical source; do not introduce
filesystem/database behavior that the selected driver does not execute.

Use explicit SML97 algebraic data, persistent lists, memoized delays and pure
state/output functions. Action results and paired return components remain
suspended even in the strict-data variant: the original finish result and
some error values must stay unforced when only the request stream is needed.
Reset identifiers to one and responses to zero for each fresh session,
sharing the raw input characters across repetitions. Global protocol escapes
and delayed derived-logic schemas preserve their separate sharing.

Kernel indices and counters use native signed Int. All selected input
numerals, signature depths, goal identifiers and repetition counts fit signed
31-bit Int; review that bound before adding larger or different inputs.
This is the selected benchmark's explicit width assumption, not a claim about
unrestricted 64-bit user programs. Hash arithmetic is explicitly modular
Word64, matching the pinned 64-bit GHC result. IntInf is used only for signed
hash formatting. No numerical tolerance or arithmetic widening is introduced.
Input and request characters are bytes, matching original binary-mode input.

Preserve observed source quirks and stubs, including duplicate Share-index
comparison, the retained declaration tail in map_data, the first conditional
branch reused in propositional evaluation, the constructor-type and eta
stubs, self-signature comparison in subterm rewriting and the shadowed third
disjunction parameter. The suite checks this program's behavior; it does not
certify the historical proof kernel's logical soundness.

## Compiler and runtime questions

Higher-order state/output combinators, closures, immutable terms and trees,
sharing, unused result fields, recursive parser construction, byte rendering,
partial applications and object lifetimes are source-based diagnostic
questions. Their performance effects remain hypotheses until measurements
establish them. Strict data may force proof objects that lazy request
generation leaves suspended; policies are separately named.

SML/NJ image export evaluates declarations during compilation. Record that
phase separately from fresh execution and interpret them together. Repeated
execution retains global sharing and does not imply a steady state.

## Inputs, validation and references

All profiles use the original 196-byte veritas.stdin, identical to grip-in.
The original main computes a 1391-byte request stream with SHA-256
91ae6ea6fb1188a5f90e69bdaeb0f7c3d3b5d5d6f1bf6141db14f1883bbe5865.
Its Word64 digest is CD1FC6B0A4675CFB, signed -3665993109681513221.
All 400/4000/20000 lines of the pinned stdout fixtures agree with that value.
Each portable repetition validates the complete request-stream hash before
printing it; the shared suite driver also validates the repetition count.

The upstream Makefile explicitly questions how much of the prover this
single input exercises. Keep that diagnostic limitation. Supplemental
semantic controls independently compare tokenization, parsed rendering,
protocol primitives, ignored return values, request streams and final editor
outcomes against the original GHC functions. They include failures and invalid
proof outcomes produced by the original, recorded as such. Timed profiles
retain the original forcing of requests; extra proof inspection belongs to
the semantic target.

Raw request streams contain NUL bytes. Store the independent request
references as reviewed ASCII hexadecimal, with byte identities and decoding
in the SML tests. Original inputs and notices retain their exact bytes.
The [pinned suite sources](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/real/veritas)
establish exact workload ancestry. The [University of Kent publication record](https://www.cs.kent.ac.uk/pubs/1992/427/index.html)
identifies Implementation of the Veritas Design Logic (1992) as related
literature. [Public validation](../results/m4-veritas/README.md) records all 32
Rune smoke/normal combinations passing, thirteen complete 218-check semantic
groups, agreeing normal allocation counts and full repository acceptance.
Host deadlines and incomplete attempts remain explicit; broader large-host
sweeps are unrecorded.
