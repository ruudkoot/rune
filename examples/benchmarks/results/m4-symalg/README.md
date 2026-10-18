# Symalg validation

Both policies pass all 56 canonical smoke/normal cases on Rune O0/O2 across
stack, register, JIT and native engines and all six managed native hosts.
All twenty semantic invocations complete 332 assertions: 6640 pass, none
failed or unreached. Native O0/O2 labels repeat host-default settings.

Original direct arithmetic observers supply 161 cases, checked in both
policies. Full original command transcripts exercise parsing, precedence,
assignment, environments, rationals, comparisons, unknown functions, help
and invalid syntax. Full smoke numeric values and hashed transcripts agree.
Memoized-tree and zero-product demand controls pass; deliberately perturbed
complete values and transcripts are rejected.

Unmodified Haskell executables match all source FAST/NORM/SLOW hashed fixtures.
A separate output-only observer records complete numeric values. Independent
integer square roots agree with every supplied positive sqrt value at 20,
3000, 15000 and 40000 digits; the recorded source/floor gaps are zero.
Selected 300-digit normal and 3000-digit large references also pass that
independent check. Runtime validation requires exact source strings.

Smoke uses one nine-command cycle at twenty digits; normal uses that cycle
at 300 digits; selected large uses 3000 digits. Original scripts use 261
sqrt commands at 3000/15000/40000 digits. These reductions are explicit.
The selected normal pilot passes both policies without guard interruption.
Separate development pilots time out at 600 seconds for a 3000-digit cycle
and 1500 seconds for the full FAST script. Neither hits a memory guard;
neither is a failure of the selected normal profile or a completed large run.
Those pilots use Rune's default O1 and are not headline comparative timings.

All eight full selected-normal Rune count samples agree; both count guards
exit zero without interruption. No fresh-process timing samples are recorded
for this import wave. Existing measurement baselines remain separate.

The source zero-times-nonzero real operation enters a nonterminating
magnitude search. A reduced original and both translations time out under
the same three-second/1 GiB bounds. The zero-times-zero guard succeeds.
The unrepaired source behavior remains outside successful profile fixtures;
no compiler/runtime feature or arithmetic workaround is introduced.

An initial broad observer timed out on that source behavior before its final
observations. A generated test helper initially used the wrong string operator;
its compile/setup logs remain separate from the passing final target.
The final public shell adapter passes Rune O0/O2. Full repository acceptance
and selected large SML runs are recorded separately, not inferred here.

Full make JOBS=4 check exits zero with 1355 catalogue profiles, including
all compiler, runedoc and runeopt cross-build comparisons. This completes the
recorded acceptance gate for this import wave; outstanding large/timing
checks above remain outstanding.
