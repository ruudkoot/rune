# Roadmap: Unicode source, and wide text made symmetric

Rune reads source as bytes. Comments may hold any byte. A string literal
keeps the bytes 128 to 255 as they stand. An identifier is ASCII, and
anything else outside a literal or comment is "unexpected character".
Nothing checks that a file is UTF-8, and nothing says what it is.

Rune's wide text has its own gaps. The Basis specification's signatures for
it cannot be matched (`WideTextIO`), or match only by a signature of Rune's
own (`MONO_VECTOR_EQ`). The operators every program uses (`^`, `size`,
`concat`) exist for 8-bit strings only.

This roadmap plans three things:
- **Source modes.** an ASCII default, `--unicode` for UTF-8 and
  `--unicode=latin1`, with a table
  of what each admits, raw, in code, comments and literals.
- **Unicode identifiers.** Normalised or checked to NFC, and kept safe from
  the lookalikes and invisible characters that Unicode brings.
- **Wide text made symmetric.** The Basis's wide structures as a second
  implementation of the same signatures as the 8-bit ones. The fix to the
  specification is written out as a change request.

It was written on 2026-10-17 against `9b327248`, the merge of pull request
#60 into master. It lives in a worktree, on branch `utf8`.

What it rests on:
* **The code.** A reading of the lexer, `Source`, the diagnostics, the
  driver's options and unit cache, the REPL, runedoc and the Basis's wide
  family, with every consumer of a position or an identifier listed
  (*Where we are*).
* **A census** of 17,801 SML files on this machine. It covers Rune, MLton,
  HOL4 (as Holmake feeds it to the compiler, after its quotation filter),
  SML/NJ, Poly/ML, MLKit, Moscow ML, HaMLet, Manticore and the SML '97
  corpus, and counts what each source mode would refuse (*The experiments*,
  E1).
* **Probes of seven Standard ML systems** in eight configurations, on 33
  small programs (E2), and a comparison of 27 other languages against their
  primary sources (E3).
* **Three prototypes, thrown away:**
  - a lexer with the source modes and Unicode identifiers, measured on
    1.1 MB of the compiler, 104 MB of HOL4 and MLton's sources (E9);
  - Unicode normalisation in Standard ML, run on all of
    `NormalizationTest.txt` (E4);
  - the symmetric signatures, type-checked on Rune and HaMLet and run
    through the Basis suite's configurations (E6).
* **The specifications.** The Definition of Standard ML (Revised), the Basis
  Library specification, and Unicode's UAX #15, #31, UTS #39 and #55
  (*What the specifications say*, *What the literature says*).

## Status

| Milestone | What | State |
|---|---|---|
| M0 | This roadmap | done |
| M1 | Fixes that follow the Definition or fix bugs | done 2026-10-18: the Basis part and the source part |
| M2 | Source modes: the plumbing | done 2026-10-18 |
| M3 | What a source may hold raw | |
| M4 | Literals by type and mode | |
| M5 | `lib/unicode`: normalisation and identifier tables | done 2026-10-18; G2 passed 2026-10-18 |
| M6 | Unicode identifiers | |
| M7 | Showing source and names | |
| M8 | The wide family in the 8-bit order, and its costs | done 2026-10-18 |
| M9 | The symmetric text signatures, and the change request | done 2026-10-18 |
| M10 | String operations at both widths | |
| M11 | The corpora and the comparison | |

The owner decided D1 to D20 on 2026-10-18, every one as recommended
(*Decisions*). D1's flag names and D7's `\U` are the owner's own (*The
request*).

The milestones form two tracks. Neither waits for the other:
- **The source track** is M2 to M7. It cannot use `WideChar`, because the
  hosts that build the compiler lack it (*Constraints*).
- **The Basis track** is M8 to M10.

M1 can go first; two of its items carry out D5's DEL row and D8. M5 can
start on the first day. M11 closes both tracks.

## The request

The owner's brief, as written:

> - this is a draft roadmap to allow rune to process source code in unicode/utf8
> - a prerequisite is fixing the widechar/widetext structures and signatures in the basis library
>   - the basis specification is broken in this respect (see docs/unicode.md) we need to make some fixes here
>   - Char/WideChar and String/WideString should become fully symmetric. two implementations of the same signatures. this likely requires fixing the various text signatures. we want rune to be fully compatible with the basis library spec, but as it is broken here we have no choice but to deviate
>   - make the most elegant fix possible. record it properly in docs/unicode.md as we want to raise a specification change request based on our changes. record any deviations from the spec as usual and pin but test
>   - also take the deviation around real vectors (something to do with a eqtype) into account.
>   - if this breaks the xc1 and/or xc2 test suites then fix by adding the required shims or something
> - also ensure both char and widechar, and string and widestring allow for string literals and the usual string operations (e.g. ^) symmetrically via overloading and the signatures.
>   - within string literals restrict codepoints whether literally or via escape code are withing the range allowed by either char or widechar
> - change rune to read source code using widechar/widestring instead of char/string
>   - by default we should only accept source code characters in the 32 to 126 range and well-understood control code (\r \n \t ?). any other code points must encoded using escape codes
>   - inside string literals we do not accept literal control characters (0 to 31 and 127). they must always be encoded using escape sequences
>   - rune source code must adhere to this restriction
>   - if this is stricter than the sml97 spec then record it as a deviation and pin by tests
>   - check if the large sml codes bases (mlton and hol4) can still be compiled with this restriction and report if not. i suspect they can still be made to compile with --latin1 and/or --utf8 flag below.
>   - add --ascii (the default for now), --latin1 and --utf8 command line options in the compiler loosen this restriction.
>     - --ascii refers to the restriction above
>     - --latin1 allows full 8-bit code points (0 to 255) in source code and within string literals to the extend also allowed by the sml97 specification. the compiler will remap them from latin1 code page to the utf8 encoding used internally.
>     - --utf8 allows full unicode codepoints in source code and string literals. we keep restriction on control codes: only well-known codes in source code and not allowed in string literals (unless via escape code: i.e. we allow tabs in source code but not inside string literals unless encodes as \t or \x09).
> - i am assuming rune reads source code as streams and does not need random access. this means we can keep strings as compact utf8 encoded data internally. positions in a stream count codepoints not bytes. you must flag if this assumption does not hold as we would need more complicated data structures to process unicode strings efficiently if random access is required.
> - add tests to ensure we can process source code with unicode and test rune under --ascii, --latin1 and --utf8 settings
>   - and the associated reject tests
> - produce a comparision of rune, the sml language and basis library specs and update docs/unicode.md. for rune consider all three modes (--ascii, --latin1, --utf8) and cosider the additional restrictions on source code and string literals and compare against spec and other sml implemenations.
> - please flag if the sml spec is neither of --ascii, --latin1, --utf8
> - use lib/unicode and extend/improve as needed (e.g. normalization algorithms)
>   - test this throughouly against existing unicode test suites
> - unicode identifiers are allowed
> - rune converts idnetifiers into nfc normal form when reading the source code so identifiers can be compared for equivalance efficiently
>   - i will leave it up to you if the whole source code (including string literals) should be put into normal form. conider safety, perforamnce, what other languages do
>   - if a string is supposed to be not in nfc normal form then the codepoints can be encoded using escape codes as they are not transformed by the nfc normalization
>   - benchmark if this does not slow down lexing and parsing
>   - rune is intended to be a safe language so we should reject funky code points in identifiers (nul, newlines etc.). they can caude issues when printed in e.g. the debugger
> - consider other unicode questions not considered above yet:
>   - https://github.com/jamesgober/unicode-lang
>   - https://chatgpt.com/share/6ad3a78c-ee28-83eb-8042-fe50b6a51c2a
>   - let me know if you cannot access these
> - the sml97 non-wide char and string datatype remain "extended" ascii / bytes.
>   - an \xff escape means a single char or byte of 0xff
>   - a char is an extended ascii
>   - the source code is still in utf-8. for safety any codepoint outside 32-126 should be rejected rather than converted in a string literal (unless an escape code between 0-255).
> - in a widechar/widestring the \xff escpare refers to unicode codepoint 255 and at runtime is the utf-8 encoded byte sequence c3 bf
> - be very clear if anything in this draft is ambiguous, contradictorry, wrong or dangerous so i can decide on it in the full roadmap

**The owner's answers while this was written (2026-10-17):**
- **Where:** in the worktree `.worktrees/utf8`, on a new branch `utf8` from
  master `9b327248`. Committed as M0 and not pushed.
- **What it rests on:** measurements and prototypes that are thrown away.
  Only this document lands.
- **Form:** that of `docs/plans/quickcheck.md`.
- **The second link of the brief:** the conversation it points to cannot be
  read without a login. The owner supplied its text, a comparison of 27
  languages, which *What the implementations do* folds in. The first link,
  `jamesgober/unicode-lang`, is a Rust crate for identifiers (UAX #31),
  normalisation (UAX #15) and display width (UAX #11), and is cited where
  those come up.

**The owner's decision after M0 (2026-10-18):** the brief's three flags
become one.
- **No `--ascii`:** the ASCII mode is the default, so it needs no flag.
- **`--unicode=ENC`,** with `ENC` either `utf8` or `latin1`, in place of
  `--utf8` and `--latin1`. A bare `--unicode` means `--unicode=utf8`.

The rest of this document uses those names. The modes are still three:
- the default, ASCII outside comments;
- `--unicode`, for UTF-8;
- `--unicode=latin1`.

Two plans changed with them:
- **The default.** With no `--ascii`, today's rules cannot stay the default
  while ASCII is asked for by flag. So the ASCII mode becomes the default as
  its rules land, in M3 and M4, and not in M11 (D16).
- **How the mode is set.** The name `ascii` stays in the mode's vocabulary,
  for build files and `Compiler.compile`, which must be able to say it when
  the command line says `--unicode` (D1).

**And (2026-10-18):** `\U`, Rune's extension from Successor ML, is allowed only
under `--unicode` (D7). The default then adds nothing to the Definition's
escapes.

**The decisions (2026-10-18):** the owner took every recommendation, D1 to
D20.

**And, for G2's question (2026-10-18):** the identifier characters that look
like digits join the frozen lookalikes list, except the 13 that UTS #39
recommends for identifiers. Those are everyday letters and native digits,
such as Cyrillic б and З. That makes 116 of the 129 (D10, *The
architecture*). That includes the departures from the brief listed in *Where this
roadmap recommends otherwise than the brief*.

**At G2 (2026-10-18):** the owner took the recommendations of M5's report,
so that the lookalikes list leaves to the warnings whatever UTS #39
recommends for identifiers, as it does for the digits:
- the 9 Recommended characters among the 85 lookalikes of punctuation stay
  allowed: Hebrew yod U+05D9, Katakana no U+30CE, Armenian feh U+0586, the
  Arabic-Indic zeros U+0660 and U+06F0, the visargas U+0903 and U+0A83, and
  CJK U+4E36 and U+4E3F. The other 76 are refused, `ʼ` and `ʻ` among them;
- the 21 decimal digits that look like 0 and 1 and that UTS #39 does not
  recommend are refused;
- all the lookalikes of `|` that M5 found are refused, its 19 and the 7 it
  left open;
- `UnicodeSecurity`'s data goes into the compiler in M6, for D13's
  warnings.

The list holds 239 code points (D10, *The architecture*): U+1FBF1, a
segmented digit one that is also among the lookalikes of `|`, counts once.

| The brief asks | Answered in |
|---|---|
| a roadmap for Unicode and UTF-8 source | this document |
| first, fix the wide structures and signatures of the Basis | *What the brief gets wrong* (W1), D18, M8, M9 |
| Char/WideChar and String/WideString fully symmetric, by the most elegant fix | *The architecture* (*The symmetric text signatures*), D18, M9 |
| record the fix in `docs/unicode.md` as a specification change request | M9, *Appendix C* |
| record and pin deviations | M9; each milestone's *Done when* |
| the deviation about real vectors and equality | D18; *Where we are* (*The wide family*) |
| shims if xc1 or xc2 break | E6, M8, M9 (gate G3) |
| literals and `^` at both widths, through overloading and the signatures | partly: literals already, and `^ size concat substring` (D20, M10); `str implode explode` later, `chr print` never (*Where this roadmap recommends otherwise*) |
| code points in literals limited to what the type holds | D8, M4 |
| read source as `WideChar`/`WideString` | *What the brief gets wrong* (W2), *The architecture* |
| `--ascii`: 32 to 126 and the usual control characters; escapes for the rest | D4, D5, M3 |
| no raw control characters in literals | D5, M3 |
| Rune's own source keeps to it | A3, E9, M11 |
| a deviation where this is stricter than SML '97 | *What the specifications say*, D4 |
| check MLton and HOL4 | C4, D4, E1, E9: both pass the ASCII default if comments may hold UTF-8 |
| `--ascii`, `--latin1` and `--utf8` | the owner's names: the default, `--unicode`, `--unicode=latin1` (*The request*); D1, D3, D6, M2 to M4 |
| `--latin1` and the Latin-1 code page | C1 to C3, D2, D3 |
| `--utf8`, with the control characters still restricted | D5, D6 |
| source read as a stream, with positions counted in code points | *What the brief gets wrong* (W4, W5), *The architecture*, D15 |
| tests in every mode, and reject tests | *Testing the modes*, each milestone |
| a comparison of Rune, SML '97, the Basis and other systems | *What the specifications say*, *What the implementations do*, M11, *Appendix B* |
| whether SML '97 is one of the three modes | *What the specifications say* |
| use and extend `lib/unicode`, normalisation, test it thoroughly | E4, M5 |
| Unicode identifiers | D10, D11, M6 |
| identifiers in NFC as source is read | D12 (checked, not converted: *Where this roadmap recommends otherwise*), M6 |
| NFC for all source or only identifiers | D12: identifiers only |
| escapes as the way to keep a string out of NFC | D12 |
| benchmark lexing | E9; the real lexer's NFC fallback and lints in M6 |
| no odd code points in identifiers | D10, D13, D14 |
| other Unicode questions, and the two links | *What the literature says*, *What the implementations do*, *What the brief gets wrong* |
| 8-bit `char` and `string` stay bytes; `\xff` is a byte | A4, D6, D7 |
| reject raw non-ASCII in an 8-bit literal | A4, D6 |
| at `WideString`, `\xff` is U+00FF, UTF-8 `c3 bf` at run time | D7, D19, *What the brief gets wrong* (W3) |
| say what is ambiguous, contradictory, wrong or dangerous | *What the brief gets wrong, leaves open, or makes dangerous* |

## What the brief gets wrong, leaves open, or makes dangerous

The brief asks to be told plainly (line 42). The items are grouped under its
four words. Each points to the decision that settles it, and line numbers
refer to the brief as quoted in *The request*.

### Wrong

**W1. The Basis work is no prerequisite (line 2).**
- The compiler's sources are built by MLton, SML/NJ, Poly/ML and MLKit as
  well as by Rune, and all builds must give the same bytecode
  (`docs/building.md`, "Portability rules for compiler sources").
- Three of those hosts have no `WideChar`, and the fourth, MLton, has its own
  (*Constraints*). So nothing the lexer does can rest on the Basis's wide
  structures, whatever their signatures.
- The two pieces of work are independent tracks: M2 to M7 for source, M8 to
  M10 for the Basis.

**W2. The compiler cannot read source as `WideChar`/`WideString` (line 10).**
- The hosts are one reason (W1).
- The other is cost. A `WideString` holds a 64-bit word per character
  (*Where we are*), so the compiler's 1.1 MB of source would take about 9 MB,
  and HOL4's 104 MB about 830 MB.
- The text stays a UTF-8 `string`, read as bytes. Where the lexer needs a
  code point (in an identifier, a literal, or a comment it checks), it
  decodes one with `lib/unicode`'s `Utf8`, which the compiler already
  contains (`rune.build:12-19`). Code points are `int`, as the lexer's
  `CHAR of int` and `WIDESTRING of int list` already are.

**W3. `WideString` is not UTF-8 at run time (line 41).**
- The brief takes `"\xff"` at `WideString` to be the bytes `c3 bf` at run
  time. It is one 64-bit word holding 255 (*Where we are*).
- UTF-8 would make `WideString.sub` and `size` cost time proportional to the
  string, unless an index is kept beside it as Swift does. It would also make
  `WideCharArray` a different representation from `WideCharVector`, and turn
  the MLton library's algorithms that xc2 runs on Rune's `WideString` from
  linear to quadratic.
- UTF-8 is what a `WideTextIO` file holds, and that is where the conversion
  happens (*Where we are*). D19 asks whether the representation should change
  at all.
- The costs of wide text are in the library, not in the representation (E8):
  - 1,000 calls of `WideString.^` take 170 million instructions, against
    15,555 for `String.^`;
  - reading 10 MB with `WideTextIO.inputAll` takes 206 instructions a byte
    and 13 seconds.

**W4. The lexer is not a stream, but it needs no more than one (line 20).**
- It reads the whole file as one `string` by byte index
  (`src/frontend/lexer.sml:69-75`). It never goes back before the start of the
  token it is reading, and it looks at most 10 bytes ahead (`_overload`).
- Every lexical decision is made on an ASCII byte, and in UTF-8 an ASCII byte
  is never part of another character. So a byte-indexed lexer stays correct
  over UTF-8 text, and stays as fast where the text is ASCII.
- The assumption the brief asks to be flagged holds in what matters. No
  random access by code point is needed, and no new data structure (E9).

**W5. Positions should stay byte offsets (line 20).**
- Sixteen consumers index the source by byte span (*Appendix A*), among
  them:
  - the unit basis, which lexes a unit's source again to rebuild its
    functors;
  - runedoc, the debugger, and the REPL's highlighter and completion;
  - `--serve`, the engine protocol and the Jupyter kernel;
  - the bytecode line table and DWARF.
- Two protocols, `--serve` and the engine's, promise bytes (*Where we
  are*, *Appendix A*). `Compiler.compile`, through which HOL-rune compiles,
  prints its errors as `file:line:col` with a byte column.
- Counting positions in code points would break all of them for no gain. A
  column shown to a person is another matter: computing it in code points
  when it is shown costs nothing where it is not shown (D15).

**W6. `\x` is not Standard ML (lines 19, 38, 41).**
- The Definition's escapes are `\a \b \t \n \v \f \r \^c \ddd \uxxxx \" \\`
  and the gap `\f...f\`. `\U` is Rune's extension, from Successor ML, and
  by the owner's decision only allowed under `--unicode` (D7).
- Adding `\xHH` is a second extension (D7). The brief's `"\xff"` can be
  written today as `"\255"` or `"\u00FF"`, and its `\x09` as `\t` or
  `\009`.

### Contradictory

**C1. `--latin1`: an encoding, or a repertoire? (lines 18, 40).**
- Line 18 says the compiler "will remap them from latin1 code page to the
  utf8 encoding used internally". That makes `--latin1` say how the file's
  bytes are to be read.
- Line 40 says "the source code is still in utf-8". That makes the modes say
  which characters are allowed in a file that is always UTF-8.
- Both cannot hold. Besides Rune's own test of a bad byte, the census found 17
  SML sources on this machine in Latin-1 (E1):
  - 16 of MLKit's, three of which hold `"(æ|ø|å)"` in literals;
  - one of Moscow ML's.
  
  D3 makes it an encoding, `--unicode=latin1` in the owner's names, and keeps
  their bytes.

**C2. "To the extend also allowed by the sml97 specification" (line 18).**
- SML '97 allows no character above 126 in a string constant
  (*What the specifications say*). Read literally, `--latin1` would add
  nothing to literals.

**C3. A mode that remaps changes what a program means.**
- Rune keeps today the bytes of a literal's characters. Under a `--latin1`
  that remaps to UTF-8, the same file's `"é"` (byte E9) would become two bytes
  at `string`, or U+00E9 at `WideString`.
- More generally, unless the modes are nested sets of programs that mean the
  same wherever two modes accept them, a flag changes behaviour silently.
  D2 asks for that rule.

**C4. HOL4 and MLton (line 15) do not need `--latin1` or `--utf8`; they need
comments.**
- Measured (E1, E9), neither has a non-ASCII character in a literal or in
  code as the compiler sees it.
  - HOL4's quotation filter, which Holmake runs on every source, escapes the
    bytes of `"α"` as `"\206\177"` and turns quotations into ASCII strings.
  - In MLton, non-ASCII is found only in two comments.
- So both pass the ASCII default exactly when comments may hold UTF-8 (D4),
  and need `--unicode` otherwise. They need it for their comments, not their code.
- For HOL4 as HOL-rune compiles it, the comment rule decides 425 files:
  - 258 of HOL4's 3,742 sources, after the filter;
  - 165 theory files that HOL generates (`⊢ ∀ ∧ ⇒` in their comments), which
    nobody can edit;
  - 2 tools that Rune compiles unfiltered.

### Ambiguous

**A1. Comments (line 11).** "Any other code points must encoded using escape
codes" cannot apply to comments, which have no escapes.
- The Definition lets a comment hold any character.
- Refusing non-ASCII in comments rejects:
  - 425 of HOL4's files as HOL-rune compiles it (C4);
  - 2 of MLton's;
  - 13 of SML/NJ's;
  - 3 of Rune's own, one of them part of the compiler
    (`lib/unicode/grapheme.sml:8`).
- See D4.

**A2. Which control characters (line 11): "\r \n \t ?".**
- The Definition requires formfeed among the formatting characters.
- Two SML/NJ files use formfeed (E1). The brief does not say what becomes of
  these:
  - vertical tab, which Rune takes as white space today and SML/NJ, MLKit
    and Moscow ML refuse (E2);
  - a bare CR, which every system takes and Rune counts wrongly;
  - NUL;
  - the Unicode line ends NEL, LS and PS;
  - a byte-order mark;
  - the bidirectional controls.
- See D5.

**A3. "Rune source code must adhere" (line 13).** Rune's own tree, or every
program Rune compiles?
- E9 lists the five files of Rune's tree that the ASCII mode refuses: four
  diagnostics tests, which exist to hold odd characters, and an upstream copy
  of a benchmark.
- Under D5 and D6 no mode takes four of them as they are. They are
  rewritten:
  - the diagnostics tests keep their odd characters in comments or wide
    literals, or become reject tests;
  - the benchmark copy takes escapes.
  
  `bidi.sml` and `badbyte.sml` become reject tests of the rules that refuse
  them. See M3 and M4.

**A4. "Extended ascii" (lines 37, 39).** Rune's `char` is a byte with ASCII's
classes. `Char.isAlpha #"\233"` is `false` and `toUpper` leaves it alone, so
there is no Latin-1 meaning. The roadmap reads "extended ascii" as "a byte",
which is what Rune does.

**A5. "Real vectors (something to do with a eqtype)" (line 6).** This is
`MONO_VECTOR_EQ`.
- The specification writes `type vector` in `MONO_VECTOR`, so that
  `RealVector` can exist, and forgot that `WideCharVector` must still admit
  equality.
- Rune works around this with a signature of its own
  (`lib/basis/mono_sigs.sml:15-42,479-490`). D18 removes it.

**A6. Tabs in literals (line 19).** Already refused today: the lexer refuses
every byte below 32 inside a literal, outside a gap (`lexer.sml:156`). The brief's rule for
`--utf8` changes nothing here.

### Dangerous

**X1. A raw character and its escape would mean different things.**
- If `--unicode` lets `"é"` stand at `string` as its UTF-8 bytes, as SML/NJ,
  MLKit and Moscow ML do (E2), then `"é"` is two bytes and `"\u00E9"` one.
  `"€"` compiles while `"\u20AC"` is an error.
- `#"é"` would have to stay an error, or `String.sub ("é", 0) <> #"é"`.
- The brief's line 40 avoids all this by refusing the raw character. D6
  weighs the two.

**X2. A cached unit can skip the mode.**
- The unit cache keys a unit by its name, the hash of its text, whether it
  may use `_prim`, and its settings (`src/driver/unitcache.sml:140-142`),
  under a directory named by the compiler's configuration. A hit skips the
  lexer.
- If the mode is not among the settings, a unit compiled under `--unicode` is
  loaded in the default mode without a word.
- Loading a unit's basis lexes its source again (`unitbasis.sml:1339-1342`),
  and that needs the unit's own mode.
- See D1.

**X3. Unicode symbols as identifiers.**
- Standard ML takes the longest run of symbol characters as one identifier,
  so Unicode symbols would merge with ASCII ones.
- Several look like the language's own punctuation: `∼` U+223C for `~`, `∗`
  U+2217 for `*`, `−` U+2212, `∣` U+2223, `∶` U+2236, and `＝` U+FF1D. With
  them, `(∗ ... ∗)` looks like a comment and is code, and `∼1` looks like a
  negative number and is an application.
- The obvious class, Pattern_Syntax, also takes the quotation marks
  `‘ ’ “ ”`. See D11.

**X4. Unicode letters that look like SML punctuation.**
- Among the characters UAX #31 allows in identifiers (E5):
  - `ǃ` U+01C3, a letter, looks like `!`;
  - `ʼ` U+02BC and `ʹ` U+02B9 make `ʼa` look like a type variable;
  - `ꓸ` U+A4F8 makes `Aꓸx` look like a long identifier;
  - `ǀ` U+01C0, a letter, makes `aǀb` look like `a|b`;
  - `·` U+00B7 makes `a·b` one identifier.
- There are 214 such identifier characters among the 397 lookalikes of SML
  tokens in UTS #39's skeletons. Those skeletons miss `·` and `ǀ`, which have
  to be found by hand.
- No script-mixing check catches these, because each is in the script of the
  letters around it. UTS #39 even counts `ʼ` as Allowed. See D10.

**X5. Invisible identifiers.**
- `U+3164` HANGUL FILLER, `U+115F`, `U+1160` and `U+FFA0` are identifier
  characters and also default-ignorable: they draw as nothing. One of them
  alone is a valid identifier in a language that takes UAX #31 as it is. This
  is the "invisible variable" trick shown in JavaScript.
- Zero-width joiners (since Unicode 15.1) and variation selectors are
  identifier characters too (E3, E5). See D10.

**X6. NFC of the whole source (line 29) changes literals.**
- NFC is not only a reordering. It replaces almost all of the CJK
  compatibility ideographs (U+F900 to U+FAFF, and U+2F800 to U+2FA1D) by
  unified ones, the OHM SIGN U+2126 by U+03A9, the KELVIN SIGN U+212A by
  U+004B, and the ANGSTROM SIGN U+212B by U+00C5.
- A literal would silently hold other characters than the file. No language
  we know of normalises its literals (E3).
- The brief's line 30 (escape what must not be normalised) is the cure for a
  problem that normalising only identifiers does not have. See D12.

**X7. Rules that change with the Unicode version.**
- XID_Start, XID_Continue and NFC are covered by Unicode's stability
  policies: a valid identifier stays valid, and its NFC stays the same.
- Default_Ignorable_Code_Point is not covered (UAX #31 §2.3), nor are UTS
  #39's identifier status and confusables. They change between versions
  (E3, E5): the joiners went from Allowed to Restricted in UTS #39 15.0, and
  into XID_Continue in 15.1.
- If unstable data gave errors, a program would stop compiling when Rune's
  tables are updated.
- See D13 and D17.

**X8. Trojan Source.**
- Bidirectional controls can make a line read otherwise than it runs:
  CVE-2021-42574 (Boucher and Anderson, USENIX Security 2023).
- Rune's diagnostics already escape them when they show a line
  (`src/util/diagnostic.sml:26-29`). Nothing stops them in a comment or a
  literal. See D5.

**X9. Printing what the REPL shows.**
- A C1 control printed raw, such as U+009B, is CSI on some terminals: a
  string value can move the cursor or rewrite the screen.
- Once identifiers and literals hold more than ASCII, how the REPL, the
  debugger and runedoc print them is a safety question. See D14.

**X10. An ASCII default refuses programs Rune takes today.**
- HOL-rune would compile only if comments may hold UTF-8 (C4). Even then,
  the sat example and four diagnostics tests are refused (A3), and so is any
  program with UTF-8 in an 8-bit literal.
- Such programs compile today. A flag helps only those whose UTF-8 is in
  comments, in wide literals or in Latin-1 files. The others need escapes
  (D6). The default changes as M3 and M4 bring its rules, after G1 (D16).

**X11. An ASCII unit cannot name what a `--unicode` unit exports.** Standard
ML has no escape for identifiers. If `lib/` exported `Foo.λ`, a program in
the default mode could not use it. Libraries keep their exports ASCII (D10).

### Where this roadmap recommends otherwise than the brief

Each recommendation departs from what the brief asks. The owner took them all
on 2026-10-18, with the rest of D1 to D20:

- **Identifiers are checked to be in NFC, not converted (line 28; D12).** The
  brief's aim, names compared by their bytes, holds either way. A name
  stays the bytes of its span, and sixteen places that read names from spans
  need no change.
- **`--unicode=latin1` keeps raw bytes in 8-bit literals (lines 18 and 40; D3, D6).**
  Line 40 refuses every raw character outside 32-126 in a literal. Under
  `--unicode=latin1` a raw `æ` is its own byte, as its escape `\230` is, and
  MLKit's Latin-1 tests mean what they mean today.
- **Comments may hold UTF-8 in the ASCII mode (line 11; D4).** Without this,
  HOL4 and MLton would need `--unicode` for their comments alone.
- **Only four string operations are overloaded (line 8; D20).** `^`, `size`,
  `concat` and `substring` are. `str`, `implode` and `explode` need a new
  mechanism in the elaborator, and `chr` and `print` should never be
  overloaded.
- **`WideString` stays a word per code point (line 41; D19).**
- **There is no `\x` (lines 19, 38 and 41; D7).** The brief's `"\xff"` is
  `"\255"`.

## Where we are

### Reading source

`Source.readFile` reads a whole file into one `string` with `TextIO.inputAll`
(`src/util/source.sml:44-54`). An editor's buffer, held in `Source.overlays`
by `--serve`, comes first. Every compile, `use`, `:reload`, runedoc page and
unit-cache check goes through it or through `Source.fromString`
(*Appendix A*).

The REPL's basic mode reads lines from standard input. Its editor mode reads
from the terminal through `lib/terminal`, which handles UTF-8
(`src/repl/front.sml:305`). `Compiler.compile`, through which HOL-rune
compiles, pulls one `char` at a time (`lib/basis/compiler.sml:13`).

Nothing looks at what the bytes are:
- A UTF-8 byte-order mark at the start is "unexpected character" at 1:1.
- Lines are split at LF only (`source.sml:26`). A file with bare CR line ends
  is one line to the diagnostics.

### The lexer

`src/frontend/lexer.sml` is hand-written, 404 lines. It reads the text by
byte index:

```sml
fun lexerOf (name : string, text : string) : {next : int -> token * Source.span * int, skipComment : int -> int} =
  let
    val n = String.size text
    ...
    fun ch i = if i < n then String.sub (text, i) else #"\000"
```

It cuts each lexeme out with `String.substring`, looks at most 10 bytes ahead
(`_overload`, lines 268-277), and never looks back before the token it is
reading. The parser backtracks over the vector of tokens, not over the text
(`src/frontend/parser.sml:43-48`).

What it does with each kind of byte today:

| Where | Bytes 0-31 | 127 (DEL) | 128-255 |
|---|---|---|---|
| between tokens | white space if `Char.isSpace` (space, TAB, LF, CR, VT, FF); otherwise "unexpected character" | "unexpected character" | "unexpected character '\195'" (one byte, not the character) |
| in a comment | taken | taken | taken; any byte at all, valid UTF-8 or not |
| in a string or character literal | refused, outside a gap: "control character in string literal" (line 156); LF ends it as "unterminated" | **taken** | **taken**, one code point per byte (Latin-1) |

So today, from a UTF-8 file:
- `"é"` at `string` is two bytes. This is what SML/NJ, MLKit and Moscow ML do,
  and what HOL-rune would rely on if HOL's filter did not escape them (E1).
- `"é"` at `WideString` is the two code points U+00C3 U+00A9, because the
  bytes are taken one by one (lines 157, 255-259). MLton with
  `allowExtendedTextConsts` does the same (E2).
- `#"é"` is "character literal must contain exactly one character".

Identifiers are ASCII:

```sml
fun isIdentStart c = Char.isAlpha c
fun isIdentChar c = Char.isAlphaNum c orelse c = #"'" orelse c = #"_"
```

(lines 14-15). `Char.isAlpha` is ASCII-only, in Rune's Basis
(`lib/basis/char.sml:197`) and on every host.

The escapes are those of the Definition plus `\U` (lines 158-200):

| Escape | Rule |
|---|---|
| `\a \b \t \n \v \f \r \\ \"` | as the Definition |
| `\^c` | `c` from 64 to 95 |
| `\ddd` | three decimal digits, **at most 255 at every type** (line 188) |
| `\uXXXX` | four hexadecimal digits; no check for surrogates |
| `\UXXXXXXXX` | eight, at most 0x10FFFF; Rune's extension, from Successor ML |
| `\` white space `\` | a gap; white space is `Char.isSpace`, so VT and FF too |

A string literal becomes the token `STRING` if every code point is at most
255 and `WIDESTRING of int list` otherwise (lines 255-259). Elaboration
decides the type (*Literals and overloading*).

### Positions

A position is a byte offset (`type pos = int (* byte offset into the file
*)`, `source.sml:4`). `Source.lineCol` turns it into a line and a **byte
column** (`source.sml:57-69`). `docs/diagnostics.md:18` says so: "`COL`
counts bytes from 1".

Sixteen consumers index the text by span. Two of them, `--serve` and the
engine protocol, promise byte offsets in their protocols. *Appendix A* lists
them all. The ones that matter here:
- **The unit basis** (`src/driver/unitbasis.sml:1333-1349`) keeps a
  functor's body by the byte offset at which it starts. When a unit is
  loaded, it lexes the unit's source again to find the body.
- **The bytecode's line table, the DAP and DWARF** carry byte columns
  (`src/backend/code.sml:124-126`, `src/dap/translate.sml:56`,
  `src/opt/x64.sml:318-324`).
- **`Diagnostic`** already decodes UTF-8 when it shows a line. A grapheme
  cluster is one cell as wide as a terminal draws it. A control, a bidi
  control or a byte that is not UTF-8 is shown escaped
  (`src/util/diagnostic.sml:26-67`; `tests/diagnostics/bidi`, `wide`,
  `emoji`, `badbyte`). For rune-ide it writes UTF-16 columns
  (`diagnostic.sml:170-182`).
- **Only the first line** of a diagnostic, `file:line:col`, counts bytes.
  `tests/diagnostics/wide.sml` reports `1:66` for a name at code point 46,
  and `bidi.sml` reports `1:58` for code point 50.

### Identifiers after the lexer

Names are `string`s, compared by their bytes in `StringMap`
(`src/util/ordmap.sml:201`) and in the environments (`src/elab/env.sml:20`).
Nothing interns them. The test for "is this an identifier character" is
written again in sixteen places besides `isIdentStart` and `isIdentChar`
(*Appendix A*):
- the REPL's printer, which decides where `op` goes (`src/repl/show.sml:337`);
- runedoc's anchors (`src/doc/docanchor.sml:27-31`), which would spell `λ`
  as `op-x206-x187`;
- the highlighter's classes (`Lexer.classOf`), completion, the REPL's line
  scanner, the debugger, the REPL's commands and the Jupyter kernel;
- eight places in runedoc.

The REPL tells "the input is not finished" from the text of the lexer's
error: "unterminated" without "string literal" (`src/repl/repl.sml:137`).

### Options

A language flag follows the pattern of `--or-patterns`:
1. a `ref` in `Options` (`src/driver/options.sml:11,179`);
2. copied into the front end in `Main.main'` (`src/driver/main.sml:1045`);
3. added to the unit cache's settings for the inputs
   (`main.sml:493-499`), or to `UnitCache.configuration` when it holds for
   every unit (`src/driver/unitcache.sml:98-104`).

A build file can set some flags per unit (`main.sml:772-776`: `allowPrim`,
`noWarnings`).

Nothing reaches the lexer: `lexerOf` takes a name and a text. There are about
25 calls of `Lexer.tokenize` and `Lexer.scan` (the driver, the unit basis,
the REPL, the debugger, runedoc).

### The wide family

| Type | What it is | Run-time object |
|---|---|---|
| `Char.char` | builtin | an immediate, 0-255 |
| `String.string` = `CharVector.vector` | builtin | `K_STRING`, a byte a character |
| `WideChar.char` | `int`, sealed (`lib/basis/widechar.sml:6-18`) | an immediate |
| `WideString.string` = `WideCharVector.vector` | `int Vector.vector`, sealed (`widechar.sml:29-30`, `mono_poly_vector_fn.sml:10`) | `K_TUPLE`: a 64-bit word a character |
| `WideSubstring.substring` = `WideCharVectorSlice.slice` | a vector and two ints | a constructor and three fields |
| `WideCharArray.array` | `int Array.array` | `K_ARRAY` |

`WideString.sub` is constant time. `WideString.^` concatenates through a list
(`widestring.sml:17`). UTF-8 appears only at `WideTextIO`'s file boundary
(`widetextio.sml:123-176`).

The two families are built in opposite orders:
- In the 8-bit family, `String` is the primary structure, and `CharVector`
  and `CharVectorSlice` are views of `String` and `Substring`.
- In the wide family, `WideCharVector` is the primary structure, and
  `WideString` and `WideSubstring` are built on it.

That is why Rune needs `MONO_VECTOR_EQ`:
- `MONO_VECTOR` declares `type vector`, not `eqtype`, so that `RealVector`
  can exist (`RealVector`'s elements admit no equality).
- The specification declares `WideCharVector` with `where type elem =
  WideChar.char` and nothing more. Yet `WideText` shares
  `WideCharVector.vector` with `WideString.string`, which admits equality.
- The specification's own way out is the constraint `where type vector =
  WideString.string`. Rune cannot write it, because its `WideString` comes
  after `WideCharVector`.
- So Rune seals `WideCharVector` with a signature of its own, `MONO_VECTOR`
  with `eqtype vector` (`lib/basis/mono_sigs.sml:15-42,479-490`,
  `docs/basis-compat.md`, "WideCharVector must admit equality"). This is the
  "deviation around real vectors" of the brief.

The text I/O signatures are written for 8-bit text only:
- `TEXT_STREAM_IO` fixes `vector = CharVector.vector` and `elem = Char.char`
  (`lib/basis/sig_text_stream_io.sml:13-15`).
- `TEXT_IO` fixes its readers and writers to `TextPrimIO`'s, and writes
  `string` and `substring` both for file names and for text
  (`sig_text_io.sml:40-43,206-277`).
- So `WideTextIO` cannot match `TEXT_IO`, as `docs/unicode.md` explains.
  Rune exports it unsealed (`Deviation: TEXT_IO/WideTextIO-not-matched`).
- `STRING_CVT`'s text functions (`padLeft`, `splitl`, `scanString` and the
  rest) take `char` and `string` (`sig_string_cvt.sml:72-140`).

`CHAR` and `STRING` are matched by both families, as the specification
intends. In both, `toString`, `fromString`, `toCString` and `fromCString`
convert to and from `String.string`, an ASCII rendering with escapes
(`sig_char.sml:261-342`, `sig_string.sml:256-319`). This is the
specification's choice, recorded as the errata `CHAR/string-types` and
`STRING/string-types` and kept.

### Literals and overloading

String and character literals are overloaded as the Definition allows
(Appendix E):
- A literal gets a type variable of the class `string` or `char`
  (`src/elab/elaborate.sml:243-261`).
- Any type registered for that class may take it, through `_overload`
  (`widechar.sml:222`, `widestring.sml:180`). An unresolved literal defaults
  to `char` or `string` (`elaborate.sml:159-175`).
- Above 255, a code point is an error at `char` and `string`
  (`elaborate.sml:117-141`).
- At `WideString`, the compiler emits a call of `fromLit` on the literal's
  text, re-escaped (`src/core/matchcomp.sml:52-73`). `WideString.fromString`
  then parses it **every time the literal is evaluated** (E8).

The operators are not symmetric:
- `^`, `size`, `str`, `implode`, `explode`, `concat` and `substring` are
  8-bit primitives at top level (`lib/basis/pervasive.sml:69-75`).
- Only `<`, `<=`, `>` and `>=` are overloaded for the char and string classes
  (`src/elab/overload.sml:49-54`).
- At `WideString`, a program writes `WideString.^`
  (`tests/lang/ty.overload.literal_wide.sml`).

### `lib/unicode`

`lib/unicode` holds `Utf8`, `DisplayWidth` and `Grapheme` (Unicode 18.0.0),
all over `int` code points and UTF-8 `string`s:
- `Utf8` is strict. It refuses overlong forms, surrogates, values past
  0x10FFFF and truncated sequences, and replaces each maximal ill-formed
  subpart by U+FFFD where it must not fail.
- `scripts/gen-unicode-tables.py` makes the tables from UCD files pinned by
  SHA-256. They are hexadecimal strings, decoded at their first use, because
  as integer literals they cost the bootstrap a seventh more
  (`docs/plans/repl.md`, M2).
- The tests run Unicode's `GraphemeBreakTest.txt` in full.
- There is no normalisation, no identifier property (XID), no General
  Category table and no confusables data.
- The compiler already contains the library: `rune.build:12-19` lists its
  files, for the diagnostics' excerpts. They are `host yes`, built by every
  host.
- The Basis cannot use it: no library may be used by `lib/basis`.

### The Basis suite's configurations

Wide text must keep working in four configurations (`tests/basis/xc2/README.md`):
- `rune`: Rune's compiler and Rune's library.
- `xc1:HOST`: a host's compiler and Rune's library.
  - It deletes every `_overload` line (`tests/basis/host/gen-host-basis.sh`),
    so no test in `tests/basis` may use a wide literal. The wide tests build
    their values from code points (`tests/basis/widestring.sml:16-24`).
- `xc2:HOST`: Rune's compiler and a host's library.
  - Only MLton's library has wide text. Its shim maps MLton's `String32` onto
    Rune's `WideString` and relies on three things:
    - `WideString.string` admitting equality;
    - `WideCharVector.tabulate`;
    - a constant-time `sub` (`tests/basis/xc2/mlton/shim.sml:22-50,115-123`).
- `native:HOST`: the host alone.

A deviation is written once, as a note in the member's doc comment
(`Deviation:` with `Pinned by:` the tests that show it). `make check-docs`
checks it against `tests/basis/deviations.txt` (`docs/doc-comments.md`;
`tests/basis/check-notes.sh`).

### What is wrong today

Found while writing this, all to be fixed in M1:

| What | Where | Effect |
|---|---|---|
| The UTF-8 decoder of `WideTextIO` takes overlong forms and surrogates; lead bytes F5 to F7, and any value past 0x10FFFF, raise `Chr`, not `IO.Io` | `lib/basis/widetextio.sml:145-167` | a file that is not UTF-8 is read as text |
| `Serve.parse` turns a JSON `\u` escape of a lone surrogate into three bytes that are not UTF-8 | `src/driver/serve.sml:40-67` | an editor can put text in a buffer that the compiler then holds |
| `Json.escape` raises `Domain` on a string that is not UTF-8 | `lib/json/json.sml:181-182` | `--diagnostics-json` dies on a Latin-1 file name or message |
| `\ddd` above 255 refused at the wide types | `lexer.sml:188` | the Definition allows the alphabet's whole range; MLton's own test uses `#"\999"` at `WideChar` (`regression/widechar.sml:202`) |
| DEL taken raw in a literal | `lexer.sml:156` | the Definition allows 33-126 and space |
| "unexpected character '\206'" names a byte | `lexer.sml:297` | should name U+03BB |
| `docs/unicode.md` says `WideChar` excludes surrogates; that `WideString.scan` reads `Char.char`; that MLton's `WideChar` is 16-bit | `docs/unicode.md:20-21,180-181,195-196` | the code takes surrogates (as the `CHAR` law requires, D9); `scan` reads `WideChar.char`; MLton's default is `Char32` |
| `docs/language.md` says both that `\u` above 255 is allowed at the wide types and that it is an error | `docs/language.md:24` against `:25,:49` | the first is right |
| Paths are opened with `CreateFileA`, and arguments come in the ANSI code page | `runtime/sys/sys_win.c:487,849,1380` | on Windows, `rune λ.sml` and non-ASCII `CommandLine.arguments` break |
| `tests/lib/unicode/utf8.sml` tests 7 of the 85 cases of Kuhn's test and chapter 3's tables exactly, 16 more through its round trip, and none of the other 62 ill-formed ones; its "Table 3-8" example is Unicode 6.0 to 10.0's | `tests/lib/unicode/utf8.sml` | `Utf8` passes all 85 (E4), but nothing would notice a regression |
| On MLKit, `unicode.utf8` runs out of memory at 7 GB | `make test-lib-hosts` | found by E4; not caused by this roadmap |
| `WideString.^` and `concat` go through lists | `lib/basis/widestring.sml:17`, `vector.sml:33` | 1,000 concatenations cost 170M instructions and 440 MB, against 15,555 instructions for `String.^` (E8) |
| `WideTextIO` decodes one byte at a time through `TextIO.input1` | `lib/basis/widetextio.sml:176` | 10 MB take 2.06G instructions, 13 s and 806 MB (E8) |
| Type names are printed without their structure | the elaborator's type printer | "type elem is char in the structure but char in the signature" (E6) |

## What the specifications say

### The Definition

The Definition of Standard ML (Revised) says nothing about encodings. What it
says about characters is this (Section 2, and Appendix E):

- **The alphabet.** "We assume an underlying alphabet of N characters (N ≥
  256), numbered 0 to N-1, which agrees with the ASCII character set on the
  characters numbered 0 to 127." A library may have several string types,
  each with its alphabet, and overloading decides which alphabet a constant
  uses.
- **String constants.** "A sequence, between quotes, of zero or more
  printable characters (i.e., numbered 33-126), spaces or escape sequences."
  Nothing below 32 or above 126 may stand raw in a literal: not a tab, and
  not DEL.
- **Escapes.** `\a \b \t \n \v \f \r`, `\^c` with `c` from 64 to 95,
  `\ddd` and `\uxxxx` as "the single character with number" given, "in the
  ordinal range of the alphabet", and `\"`, `\\` and the gap `\f..f\`.
  - There is no `\U` and no `\x`.
  - `\ddd` and `\u` mean a number, not an encoding. At a type whose
    alphabet is Unicode, `\999` is U+03E7.
  - Appendix E: "it is a compile-time error if the constant does not make
    sense or does not denote a value within the machine representation
    chosen for the type", for example `\u0100` at an 8-bit string.
- **Formatting characters** "are a subset of the non-printable characters
  including at least space, tab, newline, formfeed". They separate items.
  - Vertical tab and carriage return may be in that subset or not.
  - Formfeed must be.
- **Comments.** "Any character sequence within comment brackets (* *) in
  which comment brackets are properly nested." Any character of the
  alphabet.
- **Identifiers.** "Any sequence of letters, digits, primes (') and
  underbars (_) starting with a letter or prime." The Definition does not
  say what a letter is. Every implementation reads it as ASCII, but the text
  would allow Unicode letters. The symbols of symbolic identifiers are a
  fixed list of twenty ASCII characters.
- **Overloading** (Appendix E):
  - String and character constants are overloaded within their classes, with
    `string` and `char` as defaults.
  - The overloaded identifiers are a closed list: `abs ~ div mod * / + - <
    > <= >=`. "Programmers cannot define their own overloaded constants or
    operators."
  - **`^` is not on the list.**

### The Basis Library

The 2004 specification gives the wide structures as optional:
`WideChar :> CHAR`, `WideString :> STRING`, `WideSubstring :> SUBSTRING`,
`WideCharVector :> MONO_VECTOR`, `WideText :> TEXT`, `WideTextPrimIO :>
PRIM_IO` and `WideTextIO :> TEXT_IO`. Two of these declarations cannot be
met:

- **`WideTextIO :> TEXT_IO`.** `TEXT_STREAM_IO` fixes its element and vector
  types to `Char.char` and `CharVector.vector`. `TEXT_IO` fixes its stream's
  readers and writers to `TextPrimIO`'s (`docs/unicode.md`). No structure
  of wide characters can match them.
- **`WideCharVector :> MONO_VECTOR` with only `where type elem`.** `TEXT`
  makes `CharVector.vector` the same type as `String.string`, an equality
  type. `MONO_VECTOR` declares `type vector`, so that `RealVector` can
  exist. `CharVector` gets equality from `where type vector =
  String.string`; the declaration of `WideCharVector` forgot the same
  constraint.

`CHAR` and `STRING` are written so that both widths match them. Their
conversions (`toString`, `fromString`, the C-string ones) take or give
`String.string`, the 8-bit ASCII rendering of SML escapes, and `CHAR.scan`
reads `Char.char`. This is a choice, not a defect, and the wide structures
keep it.

`STRING_CVT`'s functions over text (`padLeft`, `splitl`, `takel`, `dropl`,
`skipWS`, `scanString`) take `char` and `string`. There is no wide
counterpart. That is an omission rather than a contradiction.

The Basis says nothing about the source encoding, nor about the encoding of
the files `WideTextIO` reads.

### Is SML '97 one of the three modes? (line 24)

No. The Definition fixes no encoding, so it cannot be `--unicode=latin1` or `--unicode`.
Its repertoire is narrower than either mode and wider than the brief's
`--ascii`:

| | The Definition | the brief's `--ascii` | the brief's `--latin1` | the brief's `--utf8` |
|---|---|---|---|---|
| encoding of the file | none given | ASCII | Latin-1 | UTF-8 |
| raw in a literal | 32-126 (space and printable) | 32-126 | 0-255 "to the extent allowed by sml97", which is 32-126 | any but controls |
| raw in a comment | any character | 32-126 and TAB, LF, CR | 0-255 | any |
| between tokens | space, TAB, LF, FF, and perhaps others | space, TAB, LF, CR | the same | the same |
| identifiers | "letters": ASCII by convention | ASCII | ASCII? (C1) | Unicode (line 27) |

It is narrower in literals, where DEL and bytes above 126 are already out;
Rune takes both today. It is wider in comments, which may hold anything, and
it requires formfeed.

With two changes, comments that may hold UTF-8 text (D4) and formfeed kept
as white space (D5), the ASCII default is SML '97 read from a UTF-8 file, with two
deviations, both pinned by tests:
- **Comments.** A comment may not hold a control character other than TAB,
  LF, CRLF and FF, a bidi control, a line separator, or bytes that are not
  UTF-8 (D5). The Definition allows any character there. No source of the
  census needs what this refuses (E1).
- **Surrogates.** A surrogate in a `\u` escape is refused at the wide types
  (D9), where the Definition allows any number of the alphabet.
It adds nothing to the Definition, because `\U`, Rune's extension, needs
`--unicode` (D7). It is stricter than Rune is today, and stricter than SML/NJ,
MLKit and Moscow ML, which take raw bytes in literals (E2).

`--unicode` would be a deviation in two places: raw non-ASCII text in literals
(D6) and Unicode identifiers (D10). It is recorded and pinned as one.

## What is different for SML, and for Rune

**Two widths of text, and overloaded literals.** Most languages that take
Unicode source have one text type and mark the other kind of literal by its
spelling:
- Rust writes `b"..."` for bytes and `"..."` for text.
- C writes `u8"..."`.
- Python writes `b"..."`.

The lexer then knows what a literal's raw characters become. In Standard ML,
one spelling serves `string` and `WideString`, and type inference decides
later which it is. So what a raw `é` becomes depends on a type the lexer
cannot see:
- At `WideString` it is one code point.
- At `string` it is two bytes, one byte, or an error. Every choice has a
  cost (D6).

The lexer must keep each literal's characters as code points and leave the
choice to elaboration. Rune's `WIDESTRING of int list` already does that for
code points above 255.

**Symbolic identifiers.** Standard ML has two kinds of identifier. The
symbolic kind is the longest run of twenty ASCII symbols, which is why `x+-y`
is `x +- y`. A language that adds Unicode operators (Haskell, Swift, Scala)
must say how they meet the ASCII ones, and in SML they would join them in one
token (X3).

**Primes and underscores.** An SML identifier may hold `'` and `_` anywhere
after its first character, and a type variable starts with `'`.
- UAX #31's default syntax allows `_` after the first character, but not
  `'`, which is Pattern_Syntax.
- A Unicode profile for SML adds `'` to XID_Continue, as the Definition's
  letters, digits, primes and underbars require.
- Numeric labels (`#1`) and digits in literals stay ASCII.

**No meaning in case.** In Haskell, OCaml and Erlang, an upper-case first
letter makes a constructor or a module, so a language that takes Unicode
letters must decide what case `λ` or `中` has; OCaml 5.3 limits its letters
to a Latin-9-compatible set for that reason. Standard ML gives case no meaning. Constructors and
structures may be spelled any way, so a Unicode identifier needs no case and
no case folding.

**Units and the cache.** Rune compiles a program as units. It keeps each in
a cache keyed by its text and settings, and compares names across units by
their bytes.
- A name normalised in one unit and not in another would not match.
- A unit cached under one mode could be loaded under another.
- Whatever the lexer does to names, every path that produces a name must do
  the same, and the mode must be part of what a unit is compiled with (D1).

**The hosts.** The compiler is built by MLton, SML/NJ, Poly/ML and MLKit as
well as by itself, and every build must make the same bytecode
(`docs/building.md`). So:
- The lexer works on `string` and `int`, never `WideChar`.
- Unicode tables in the compiler are portable SML, compiled by all four
  hosts. Bootstrap cost made `lib/unicode`'s tables strings decoded at first
  use, and the same pattern serves here (E5).
- No host takes Unicode identifiers or `\U` without a flag (E2), so the
  compiler's own sources stay ASCII outside comments, whatever the default
  is.

**The Basis suite runs Rune's library on other compilers (xc1), and other
libraries on Rune (xc2).**
- A host's overloading is closed, so xc1 removes `_overload`, and
  `tests/basis` cannot use a wide literal or an overloaded `^`.
- MLton's library is the only host library with wide text, and its shim
  depends on the shape of Rune's `WideString`.
- Any change to the wide family has to keep these configurations working,
  or say in `deviations.txt` why not (E6).

**HOL4 and the quotation filter.** HOL4, Rune's largest client, never gives
the compiler its raw files. Holmake first runs `unquote`, which turns HOL's
Unicode quotations into ASCII strings and escapes the bytes of every
non-ASCII literal (E1). Whatever Rune decides about literals, HOL4 sees only
the comment rule.

**A safe language.** The brief calls Rune "intended to be a safe language"
(line 32). Unicode gives source three new kinds of attack:
- text that reads otherwise than it runs (bidi controls);
- names that look alike and are not (homoglyphs);
- names that cannot be seen (default-ignorables).

Rune also has tools that print names and values: the REPL, the debugger and
runedoc. Unicode in a value they print can reach the terminal as control
sequences. Each of these is a decision below (D5, D10, D13, D14).

## What the literature says

The Unicode documents below were read in their 18.0 revisions, published
August and September 2026, and in earlier ones where the history matters
(E3).

### Identifiers: UAX #31

UAX #31 defines a **default identifier**, `Start Continue*`, with Start =
XID_Start and Continue = XID_Continue, and lets a language declare a
**profile** that adds or removes characters (UAX31-R1-2). A conforming
language says which version and which profile it follows.

- **The X- properties** are the NFKC-closed versions of ID_Start and
  ID_Continue, "recommended for most purposes, especially for security".
- **Apostrophe is Pattern_Syntax** (U+0027, and U+0060 too). An SML profile
  that keeps `'` in identifiers must declare it, as UAX #31 says Java and C++
  do for `$`.
- **Joiners, since Unicode 15.1.** ZWJ and ZWNJ (U+200D, U+200C) are in
  Other_ID_Continue, so they are in XID_Continue forever, by the stability
  policy. UAX #31 §2.3 now says:

  > the variation selectors and joining controls are included in
  > XID_Continue … A profile should be used to remove them from
  > general-purpose identifiers (along with other
  > Default_Ignorable_Code_Points), unless their use is required in a
  > particular domain.

  §7.3 gives that profile: the **Default-Ignorable Exclusion Profile**. Rust
  and Elixir both exclude ZWJ and ZWNJ.
- **Default_Ignorable_Code_Point is not stable** (§2.3): "The
  Default_Ignorable_Code_Point property values are not guaranteed to be
  stable." A language that excludes it should freeze the set it excludes.
- **Normalisation** (§5):
  > Generally if the programming language has case-sensitive identifiers,
  > then Normalization Form C is appropriate; whereas, if the programming
  > language has case-insensitive identifiers, then Normalization Form KC
  > is more appropriate.
  - R4 (normalise) and R6 (require the form) are both conforming.
  - Identifiers are closed under NFC: `isIdentifier(toNFC(S))` if and only if
    `isIdentifier(S)`. The same does not hold for NFKC.
  - The annex is explicit about literals: "such folding of distinctions
    should not be applied to string literals or to comments in program
    source text".
- **The Mathematical Compatibility Notation Profile** (§7.1, since 15.1)
  adds `∂ ∇ ∞`, their mathematical variants, and the sub- and superscript
  digits and signs. UTS #55 recommends it for general-purpose languages.
- **Pattern_Syntax and Pattern_White_Space** never change. UAX31-R3a counts
  LF, VT, FF, CR, NEL, LS and PS as line ends. It warns that "failing to
  interpret all characters listed … as line terminators would lead to
  spoofing issues".

### Normalisation: UAX #15 and the stability policy

The stability policy (`unicode.org/policies/stability_policy.html`)
guarantees:
- **Identifier stability:** "All strings that are valid default Unicode
  identifiers will continue to be valid default Unicode identifiers in all
  subsequent versions of Unicode."
- **XID_Start and XID_Continue:** once in, always in.
- **Normalisation:** for a string of characters assigned in both versions V
  and U, `toNFC_V(S) = toNFC_U(S)`. The same holds for the other forms. A
  string with characters unassigned in the implementation's version may not
  be normalised by a later version's rules.

UAX #15's conformance test is `NormalizationTest.txt`: about 20,000 lines in
six parts (Part 0 to Part 5), plus the rule that every code point not listed
in Part 1 is its own normal form. E4 runs it in full.

### Security: UTS #39

UTS #39 gives each character an **Identifier_Status**:
- **Allowed:** of type Recommended or Inclusion.
- **Restricted:** of type Not_Character, Deprecated, Default_Ignorable,
  Not_NFKC, Not_XID, Exclusion, Obsolete, Technical, Uncommon_Use or
  Limited_Use.

The General Security Profile allows only Allowed characters.

It defines a **skeleton**, by which two strings are confusable when their
skeletons are equal, and **mixed-script detection** through augmented script
sets, at six restriction levels from ASCII-Only to Unrestricted.

None of this is stable:

> Stability is never guaranteed between versions, although it is maintained
> where feasible. … The Identifier_Status does not have stability guarantees
> (such as "Once a character is Allowed, it will not become Restricted in
> future versions"), because the data is changing over time.

Joiners went from Allowed in 14.0 to Restricted in 15.0. Revision 34 (18.0)
changed the joining-control context rule A1 again.

### Source code: UTS #55

UTS #55, "Unicode Source Code Handling" (version 2, 2024), is the
consortium's guidance for languages and their tools:
- **Identifiers:** UAX #31's default with the mathematical profile. Mn and Mc
  are not to be excluded.
- **Normalisation:** case-sensitive languages use NFC, and
  > Programming languages should not silently normalize the contents of
  > string literals.
- **Line ends:** recognise all seven of R3a, or "forbid those of the
  specified line terminators which it does not recognize. Care must be taken
  to forbid the unrecognized ends of line even in line comments."
- **Bidi:** "The solution is not to forbid the directional formatting
  characters." UTS #55 puts the cure in display (editors applying UAX #9's
  HL4 by atoms) and in warnings "when the effect of the explicit directional
  formatting character extends across atoms".
- **Diagnostics:**
  - warn on identifiers confusable with each other or with keywords;
  - warn on characters outside the General Security Profile;
  - apply mixed-script checks to the parts of an identifier, not to the
    whole;
  - warn when the same entity is spelled in two ways that NFC makes equal.
- **Comments:** warn when a comment holds something whose skeleton contains
  the comment's closing delimiter. For SML that is a lookalike of `*)`.

UTS #55 says nothing about BOMs or encoding validity. The core
specification does (§23.8.1): "If consuming UTF-8, recognize and discard a
BOM."

### Trojan Source

Boucher and Anderson ("Trojan Source: Invisible Vulnerabilities", USENIX
Security 2023; CVE-2021-42574 and CVE-2021-42694) showed source that compiles
otherwise than it reads, with nine bidi controls (U+202A to U+202E, U+2066 to
U+2069):
- **Early returns:** a `return` disguised as a comment or a string.
- **Commenting out:** code that looks live, inside a comment.
- **Stretched strings:** part of a literal that looks like code.

To these the published version adds invisible characters (a ZWSP in a name,
or one splitting a comment delimiter) and homoglyphs.

Their defence is to "ban the use of text directionality control characters
both in language specifications and in compilers", or better, to ban
unterminated ones in literals and comments. They add that defences "must be
enabled by default".

This is the tension with UTS #55, which advises against prohibition. Rust
(lints that deny by default), Scala (forbidden) and Elixir (an error in
strings and comments) took the paper's side. D5 does too, for the nine
characters, and keeps the marks LRM, RLM and ALM.

### Successor ML

Two open issues ask for what this roadmap plans. The project's wiki has no
page on either.
- **Issue #29**, "Relax string literal rules" (2016-2017), asks for non-ASCII
  text in literals.
  - Reppy proposed requiring normalised UTF-8 in literals, with escapes for
    the rest.
  - Fluet wanted `char` and `string` to stay 8-bit.
  - Rossberg argued that normalisation ties the language to each Unicode
    update, that checking for valid UTF-8 is enough, and that the grammar be
    stated over code points with literals limited to their type's range.
  
  That last view is D6's and D12's.
- **Issue #33**, "Unicode in SML text" (2017), asks for letters and numbers
  in alphanumeric identifiers, symbols in symbolic ones, Unicode digits and
  Unicode line ends.

Neither is resolved.

## What the implementations do

### In Standard ML

E2 ran 33 small programs on seven systems in eight configurations
(*Appendix E*). E2 also read the lexers of MLton and SML/NJ. What they share:
- No system normalises text, takes a byte-order mark, or takes a non-ASCII
  identifier or symbol.
- Every system takes any byte in a comment, except Moscow ML, which ends the
  file at a NUL.
- Formfeed is white space everywhere. Vertical tab is not: SML/NJ, MLKit and
  Moscow ML refuse it.

Where they part:

| | Rune today | Poly/ML | MLKit | Moscow ML | HaMLet | SML/NJ | MLton | MLton+ext |
|---|---|---|---|---|---|---|---|---|
| raw `"é"` (UTF-8) at `string` | 2 bytes | error | 2 bytes | 2 bytes | error | 2 bytes | error | 2 bytes |
| raw `"é"` at `WideString` | 2 code points | - | - | - | - | - | error | 2 code points |
| raw TAB in a literal | error | error | **6 spaces** | error | error | error | error | error |
| raw DEL in a literal | kept | error | kept | error | error | kept | error | error |
| a Latin-1 byte in a literal | kept | error | kept | kept | **the literal cut short** | kept | error | error |
| `\U0001F600` at `WideString` | U+1F600 | - | - | - | - | - | needs ext | U+1F600 |
| `\999` at `WideString` | error | - | - | - | - | - | U+03E7 | U+03E7 |

"-" means the system has no `WideString`; only Rune and MLton do. Poly/ML
and MLton without the annotation take only ASCII in a literal, as the
Definition says. The others keep raw bytes, one character a byte.

Three systems change meaning silently:
- **HaMLet** takes the value of a literal from its host's
  `String.fromString`, which stops at the first character it cannot read: a
  Latin-1 `"café"` is `"caf"`, and `"e"` followed by U+0301 is `"e"`.
- **MLKit** expands tabs in every source line before lexing, a raw TAB in a
  literal included.
- **Moscow ML** treats NUL as the end of the input.

This is the strongest argument for the brief's "rejected rather than
converted" (line 40).

**MLton's `allowExtendedTextConsts`** (`mlton/front-end/ml.lex:212-218,
427-434`) accepts byte sequences shaped like UTF-8 in text constants. It
checks only their shape, so overlong forms, surrogates and lead bytes F5 to F7
pass. Each byte becomes one character at every width. Its `"é"` is two
characters even at `WideString`, as Rune's is today. The annotation is off by
default (`control/control-flags.sml:729-731`).

**SML/NJ's lexer** (`base/compiler/Parse/lex/ml.lex`):
- White space is space, TAB and FF (line 56); a line ends at CRLF, LF or CR
  (line 58).
- A byte above 127 outside a literal is "non-Ascii character" (lines
  138-145).
- In a literal it refuses only bytes 0 to 31 (line 227).
- `\u` above 255 is an error, and there is no `\U` (lines 203-222).

Rune today is closest to SML/NJ, with MLton's `\U` and wide types. After this
roadmap it is closest to Poly/ML and plain MLton in what its default refuses,
and to MLton+ext in what `--unicode` admits at the wide types, but with one
character per code point.

### Elsewhere

The owner supplied a comparison of 27 languages (*The request*). E3 checked
against primary sources the claims that the decisions rest on. Some rows were
incomplete or out of date:
- C23's NFC rule is undefined behaviour, not an error.
- Swift's identifiers take bidi controls.
- Java, C# and F# admit format characters in identifiers and strip them
  before comparing.
- Zig's current version bans TAB, CR and the BOM everywhere.
- OCaml's Unicode identifiers arrived in 5.3, not 5.4.

None was found false outright. The summary:

| Language | Source | Identifiers | Normalisation | Raw controls and bidi |
|---|---|---|---|---|
| Rust | UTF-8 required; leading BOM removed; CRLF → LF | XID_Start or `_`, XID_Continue; **ZWJ/ZWNJ refused** | **NFC, normalised** | bare CR only in literals and doc comments refused; nine bidi controls refused in comments and literals by lints that deny by default; `confusable_idents`, `mixed_script_confusables` and `uncommon_codepoints` warn |
| C23 | implementation-defined | XID | NFC, but a violation is undefined behaviour | - |
| C++23 | UTF-8 must be supported; leading BOM deleted | XID | **NFC required: a program that is not NFC is ill-formed** | - |
| C# | UTF-8 must be accepted | letters and Cf; **Cf removed before comparing** | NFC, implementation-defined if not | NUL implementation-defined |
| Python | UTF-8 by default, `coding:` | XID, NFKC-closed | **NFKC, normalised** | NUL refused anywhere |
| Zig | UTF-8 | ASCII; `@"..."` for others | none | 0.15: C0 but TAB/LF/CR, DEL, NEL, LS, PS refused everywhere, CR only before LF, BOM only at the start; 0.17: TAB, CR and BOM refused too |
| Elixir | UTF-8 | UAX #31 R1; **ZWJ/ZWNJ refused** | **NFC, normalised** (quoted atoms not) | bidi controls and VT, FF, bare CR, NEL, LS, PS refused in strings and comments; UTS #39: Restricted characters an error, mixed scripts an error, confusables a warning |
| Go | UTF-8, "not canonicalized" | letters (L) and `_`, digits Nd | none | NUL and non-leading BOM may be refused |
| Swift | UTF-8 | an explicit list that includes ZWSP, ZWJ, ZWNJ and **bidi controls** | none stated | unprintable ASCII refused in strings; NUL a warning |
| Java | any, by `-encoding` | `isJavaIdentifierStart`; C0 and C1 controls and Cf allowed and ignored | none | `\u000a` is a line end before lexing |
| OCaml 5.3+ | UTF-8 expected | ASCII plus Latin-9 letters, **NFC-equivalent spellings equal** | NFC | newlines in literals normalised to LF |
| Haskell 2010 | Unicode | any Unicode letter; operators of **any Unicode symbol or punctuation** | none | no raw TAB in strings |
| Julia | UTF-8 | broad, including So and Sc | NFC, plus U+025B ≡ U+03B5, U+00B5 ≡ U+03BC, U+00B7 and U+0387 ≡ U+22C5, U+2212 ≡ `-` | - |
| Scala 2.13 | Unicode | letters, `$`, `_`; Unicode operators | none | **nine bidi controls forbidden in source** |

The pattern:
- **Normalisation.** Languages whose names have no case meaning normalise or
  require NFC. Python, whose community wanted `ﬁ` to equal `fi`, uses NFKC.
  Nobody normalises literals.
- **Joiners.** The two languages that took UAX #31 most carefully, Rust and
  Elixir, refuse the joiners in identifiers.
- **Bidi controls.** Languages that thought about Trojan Source refuse
  them, by grammar or by lints that cannot be missed.
- **Byte strings.** Languages with byte strings keep them separate from text
  by spelling. Rust refuses `"\xFF"` in a text literal because it would be
  "ambiguous whether they mean Unicode code points or byte values". Standard
  ML has one spelling for both, hence D6.

### What Rune takes

- **From Rust:**
  - UTF-8 only, with a BOM dropped at the start;
  - XID less the joiners;
  - lints that warn for UTS #39, and that cannot be missed for bidi.
- **From C++23:** an identifier not in NFC is an error, not normalised (D12).
- **From Zig and Elixir:** the table of code points refused raw in every
  context, comments included (D5).
- **From UTS #55:**
  - no normalisation of literals;
  - line ends recognised, or refused;
  - the `*)` lookalike warning;
  - confusable and mixed-script warnings on the parts of names.
- **From the Definition:** the escapes keep their meaning (a number in the
  type's alphabet), and comments may hold any text.
- **Not taken:**
  - **Swift's and C#'s admission of format characters in names.** Two names
    that look the same would then differ only in invisible characters.
  - **Python's NFKC.** It folds `ℌ` into `H`.
  - **Haskell's Unicode operators.** They would merge with SML's ASCII
    symbols, among them lookalikes of SML's own punctuation (D11).

## The experiments

The numbers come from a snapshot of master at `9b327248`, built as `make`
builds it, and from copies of it with the prototypes in them. Counts of
instructions are `runevm --count`, the same at every run whatever the load.
Times are given only as indications: the machine was shared. The scripts, raw results and prototypes are kept outside
the tree, in the drafts directory of this roadmap.

### E1. What the sources hold

A census of 17,801 files: every SML source on this machine that a source
mode could meet (*Appendix D*). Among them are 3,742 files of HOL4, scanned
both raw and as its quotation filter gives them to the compiler, which makes
21,543 scans. The scanner follows
Rune's lexer, and agrees with `rune --dump-tokens` on the place and kind of
every literal in the 20,149 files Rune can lex.

**What it found:**
- **Comments are where the Unicode is.**
  - HOL4 after its filter has non-ASCII in the comments of 258 files.
  - HOL-rune also compiles 165 theory files that HOL generates, full of
    `⊢ ∀ ∧ ⇒` in comments, and 2 unfiltered tools with UTF-8 comments.
  - SML/NJ has 13 such files, Manticore 5, MLton 2, Rune 3.
- **Literals hold almost none.** HOL4's raw files have UTF-8 in the literals
  of 79 files, and its filter escapes every one (`"∩"` becomes
  `"\226\136\169"`). Elsewhere:
  - MLKit has 3 literals in Latin-1 (`"(æ|ø|å)"`);
  - Rune has 5 files, the sat benchmark's upstream copy and four
    diagnostics tests.
- **Nothing anywhere holds** NUL, VT, another C0 control, DEL, C1, NEL, LS,
  PS, a BOM, a bare CR or a raw TAB in a literal. FF appears between tokens
  in two SML/NJ files. CRLF appears in 12 files.
- **Bidi controls and joiners** appear only in Rune's own diagnostics tests.
- **Latin-1:**
  - 16 files of MLKit's, in Danish;
  - 1 of Moscow ML's;
  - one SML/NJ regression test whose two odd bytes are not Latin-1 either.
- **Escapes.** `\ddd` from 128 to 255 is common: 176,050 in HOL4's filtered
  files. `\ddd` above 255 appears only in MLton's `regression/widechar.sml`.
- **Text not in NFC:** a decomposed `é` in a Rune test, and in HOL4's raw
  quotations U+2329 and U+232A, which NFC turns into U+3008 and U+3009.

**The files each rule refuses** (the full table is in *Appendix D*):

| Rule | Rune | MLton | HOL4 as HOL-rune compiles it | SML/NJ (110, 2026, tests) | MLKit | Moscow ML |
|---|---|---|---|---|---|---|
| the brief's `--ascii` | 7 | 2 | 425 | 15, 16, 1 | 16 | 1 |
| the default: the brief's `--ascii` with UTF-8 comments (D4) and FF (D5) | 5 | 0 | **0** | 0, 0, 1 | 16 | 1 |
| `--unicode`, lexing only (D6 refuses more: *E9*) | 3 | 0 | 0 | 0, 0, 1 | 16 | 1 |
| `--unicode=latin1` (D3), E9's prototype on the 17 Latin-1 files | - | - | - | - | 1, as today (an unterminated comment) | 0 |

**HOL-rune** compiles in three ways:
- `rune -o` for its nine tools, with no flags (`tools-rune/configure.sh`);
- `use` in `rune-repl` for its start-up files;
- `Compiler.compile` for every theory, through `QUse.use` and HOL's
  in-process quotation filter (`tools-rune/buildheap.ML:270-272`,
  `rune-polyml.ML:40-44`).

A mode must reach all three (D1).

**What it predicts.**
- **D4 decides HOL4 and MLton.** With UTF-8 comments they need no flag;
  without them, 427 of their files need one.
- **D5's controls refuse nothing that any source uses**, and FF must stay.
  Its last rows refuse:
  - the 19 files that are not UTF-8 (MLKit's 16 and Moscow ML's one pass
    under `--unicode=latin1`);
  - Rune's `bidi.sml`.
- **D3 has a use:** MLKit's tests.
- **D6 refuses one real literal,** in an upstream copy inside Rune's tree.

### E2. What the other systems do

Thirty-three probes, run on Rune, Poly/ML, MLKit, Moscow ML, HaMLet, SML/NJ
and MLton (with and without `allowExtendedTextConsts`), and the lexers of
MLton and SML/NJ read: *What the implementations do* and *Appendix E*.

**What it predicts.**
- Every system already refuses a raw TAB, non-ASCII identifiers and
  symbols, and a BOM. Rune's default refuses the first three too, and
  drops a leading BOM as the Unicode standard advises. It also refuses DEL
  and non-ASCII bytes in literals, as Poly/ML and plain MLton do, and VT, as
  SML/NJ, MLKit and Moscow ML do. No source of E1 uses any of these.
- Taking `\ddd` above 255 at `WideChar` matches MLton, the only other system
  with wide characters (D8).
- A raw `"é"` at `WideString` being one code point departs from MLton, which
  makes it two. That is the departure D6 chooses.

### E3. What other languages do, checked

The owner's comparison of 27 languages was checked against their
specifications, references and compiler sources, and so were the Unicode
documents (*What the literature says*, *What the implementations do*). It
held up, with the corrections listed in *Elsewhere*.

**What it predicts.**
- NFC for identifiers (D12), with Rust and C++23.
- Joiners out of identifiers (D10), with Rust and Elixir.
- The nine bidi controls refused (D5), with Rust, Scala and Elixir, against
  UTS #55's advice.
- UTS #39 checks as warnings, never errors (D13).
- No normalisation of literals or of the whole source (D12), with every
  language and UTS #55.

### E4. Normalisation in Standard ML

**What was built**, in a copy of `lib/unicode`:
- **The generator**, extended to `UnicodeData.txt`,
  `CompositionExclusions.txt`, `DerivedNormalizationProps.txt` and
  `NormalizationTest.txt` 18.0.0, each pinned by SHA-256.
  - A reference normaliser in the generator checks all 20,171 lines of the
    test before anything is written.
  - The existing tables come out byte for byte the same.
- **`Normalize`** (264 lines, its signature 95):
  - `nfd`, `nfc`, `isNFC`, the quick check, and the canonical combining
    class, over UTF-8 strings and over lists of code points;
  - Hangul composed and decomposed by arithmetic;
  - an ASCII fast path;
  - `nfc` of a string returns the string itself when the quick check says
    Yes, and otherwise normalises only the segments that need it.
- **`NormalizeCompat`** (NFKD, NFKC) on top of `Normalize`, to know what NFKC
  would cost.

**Tests, on Rune:**
- **All of `NormalizationTest.txt`,** every part and every invariant, over
  lists and over UTF-8, plus Part 1's rule that every scalar value not listed
  is its own normal form in all four forms: pass. That is 5.51G
  instructions. Three planted mutants (the blocking rule, an unstable sort,
  Hangul's trailing consonant) each fail it.
- **Twelve properties** with `lib/test/property` pass at 20,000 cases each:
  - idempotence in four forms;
  - NFC∘NFD = NFC and NFD∘NFC = NFD;
  - `isNFC (nfc s)`;
  - the quick check never contradicts `isNFC`;
  - strings and lists agree;
  - the round trip with `Utf8`.
- **85 cases for `Utf8`**: Markus Kuhn's decoder test, and the ill-formed
  tables of the current Unicode chapter 3, Tables 3-8 to 3-11. All pass on
  today's `Utf8`, but 62 of the ill-formed ones were not tested before.
  - The "Table 3-8" example in `tests/lib/unicode/utf8.sml` comes from
    Unicode 6.0 to 10.0. It is no longer in chapter 3.

**On the hosts:**
- All five Unicode test programs pass on MLton, Poly/ML, SML/NJ 110.99.9
  (64 and 32 bits) and SML/NJ 2026.2.
- On MLKit the four new ones pass. The **existing** `unicode.utf8` runs out
  of memory at 7 GB, with or without the new files.
- One line, `#2 (fold step (0, Yes))`, was taken by Rune, MLton and Poly/ML
  and refused by SML/NJ and MLKit (a flexible record). A `host yes` file must
  be checked on all of them.

**Sizes and costs:**

| | Size or instructions |
|---|---|
| the NFC/NFD tables (`normalize_data.sml`) | 73 KB of source: decompositions 41 KB, compositions 19 KB, combining classes 8 KB, quick check 2.5 KB |
| the NFKC/NFKD tables | 118 KB more |
| first use: quick-check tables / all NFC tables / compatibility tables | 0.26M / 1.73M / 2.83M |
| an ASCII name of 10 characters: quick check / `nfc` | 163 / 156, no allocation |
| `Größe_λόγος` in NFC: quick check / `nfc` | 2,253 / 2,246 |
| the same name decomposed: `isNFC` / `nfc` | 8,430 / 8,422 |
| 1 MB of mixed text: `nfc` / `nfkc` | 197M / 433M |

**What it predicts.**
- **D12's choice is not decided by cost.** Requiring NFC and normalising both
  run the quick check on every non-ASCII name and the full algorithm on the
  rare one that needs it. It is decided by meaning: whether a name stays the
  bytes of its span.
- **The quick check alone is not enough.** A rule "the quick check must say
  Yes" would be cheaper (11 KB of tables), but it would refuse names already
  in NFC: characters marked Maybe occur in ordinary words. Examples are the
  Tamil and Malayalam vowel signs U+0BBE and U+0D3E, the Devanagari nukta
  U+093C, and the Hangul jamo vowels and trailing consonants. E9's
  prototype, which took Maybe as No, had this flaw. The real check calls
  `isNFC` on a Maybe.
- **NFKC** costs two and a half times NFC's tables and twice its time, for
  nothing the identifier profile needs.

### E5. The identifier sets, and what they cost the compiler

From Unicode 18.0.0's data and UTS #39 18.0.0 (results in the drafts,
`results/E5`):

| Set | Code points | Ranges |
|---|---|---|
| XID_Start | 158,716 | 702 |
| XID_Continue | 162,081 | 821 |
| Default_Ignorable_Code_Point | 4,174 | 17 |
| XID_Continue ∩ Default_Ignorable | 269 | 10 |
| non-ASCII characters whose UTS #39 skeleton is one ASCII token character or digit | 397 | 238 |
| Pattern_Syntax | 2,760 | |
| Sm and So | 8,566 | |
| UTS #39 Identifier_Status Allowed | 33,792 | |

**What is in XID that should not be:**
- **Default-ignorable** (269 code points):
  - ZWJ, ZWNJ, CGJ;
  - all 256 variation selectors;
  - the Mongolian free variation selectors;
  - the Khmer inherent vowels U+17B4 and U+17B5;
  - the Hangul fillers U+115F, U+1160, U+3164 and U+FFA0. These four are
    XID_Start, so one alone is an identifier.
- **Lookalikes of SML's punctuation** (397 by skeleton): 118 are XID_Start
  and 96 more XID_Continue. They include:
  - `ǃ` U+01C3 for `!`;
  - `ʼ` U+02BC and `ʹ` U+02B9 for `'`; `ʼ` is even Allowed by UTS #39;
  - `ꓸ` U+A4F8 for `.`;
  - 135 lookalikes of digits.
- **What the skeletons miss,** and the list must take by hand:
  - `·` U+00B7, which is XID_Continue and has no mapping, being itself the
    prototype of 21 others;
  - the lookalikes of `|`, `0`, `1`, `"`, `` ` `` and `%`, which UTS #39 maps
    to letters (`|` to `l`), among them `ǀ` U+01C0, a letter, and `∣` U+2223.
- `꞉` U+A789 is not XID. It is refused as an unexpected character, with no
  identifier to hide in.

**How unstable the UTS #39 data is:**
- From 16.0 to 17.0, 79,024 code points left Allowed (CJK moved to
  Uncommon_Use), and 37 joined.
- From 17.0 to 18.0, confusables gained 1,216 mappings, lost 1,069 and
  changed 241. The set of lookalikes of SML tokens grew from 257 (16.0) to
  269 (17.0) to 397 (18.0).
- XID only grew.

**Cost to the compiler.** Three files of normalisation and three of
identifiers were added to `rune.build`, with a live use in the lexer, and
the compiler was rebuilt and measured as `tests/perf/run-perf.sh` measures
the bootstrap:

| | Base | With the tables | Change |
|---|---|---|---|
| `bin/rune.rbc` | 2,138,770 bytes | 2,268,545 | +6.1% |
| bootstrap, register VM (budget 1,134.2M) | 1,030.6M instructions | 1,053.5M | +2.2% |
| bootstrap, stack VM (budget 1,688.7M) | 1,607.3M | 1,643.6M | +2.3% |
| allocation per compile of a small program | | +108 KB | |
| MLton build of the compiler, peak memory | 2.55 GB | 2.81 GB | +266 MB |
| Poly/ML build | 7.6 s, about 310 MB | 7.7 s, about 330 MB | none to speak of |

A non-ASCII name costs `Identifier.isAlphanumeric` 1,071 instructions
(Latin), 2,482 (Greek) or 2,798 (Han) for ten characters, plus `isNFC`
(1,531, 5,981, 7,300 in all), against 352 and 494 for ASCII. The profile
table (XID less the default-ignorables and lookalikes, one table for start
and continue) decodes in 0.58M at first use.

**What it predicts.**
- The profile of D10 is buildable, and costs the compiler 2.2% of its
  bootstrap and 6% of its bytecode. Both stay within budget. Building the
  profile as one table and deriving the compositions would save about 42 KB
  of the 120 KB (estimated).
- The lookalikes list cannot be generated alone. It is seeded from
  confusables.txt, then curated by hand and frozen (D10).
- UTS #39's data changes too much to give errors (D13).
- Unicode symbols are 81 of the 397 lookalikes, and 744 more symbols have
  skeletons made of letters (`∨` is `v`), which supports D11.

### E6. The symmetric signatures, built

**Stage 1: on paper, checked by five compilers.**
- Skeleton structures were generated from the suite's transcriptions of the
  specification (`tests/basis/spec-sigs`), with every value `raise Fail`.
- With them, the signatures of *Appendix C* were type-checked on Rune, HaMLet
  2.0.1, MLton, Poly/ML 5.9.2 and SML/NJ 110.99.9. All five accept:
  - `TextIO` and `WideTextIO` each sealed with the one `TEXT_IO`, and a
    functor over `TEXT_IO` applied to both;
  - each host's real `TextIO`, with `type substring` added, matched against
    the new `TEXT_IO`;
  - `WideText : TEXT` with plain `MONO_VECTOR`;
  - each host's real `StringCvt` against the new `STRING_CVT`.
- Three negative files reproduce the defects on all five: the specification's
  `TEXT_IO` against wide text, and its `WideCharVector` against `STRING`'s
  equality and `TEXT`'s sharing.

**Stage 2: in Rune's library.** A copy of `lib/basis` with:
- the wide family in the 8-bit order, sealed once as a whole. This is the
  pattern of `Word8Vector`'s seal (`lib/basis/word8vector.sml:24`).
  `WideCharVector` is `MONO_VECTOR where type vector = WideString.string`.
- `TEXT_STREAM_IO`, `TEXT_IO` and `STRING_CVT` made generic; `TextIO` and
  `StringCvt` sealed with the `where type`s that give back the
  specification's types; `WideTextIO` sealed with `TEXT_IO`.
- A new `WideStringCvt`.
- Notes:
  - new `Deviation:` notes for the three signatures and `WideStringCvt`, each
    pinned;
  - `MONO_VECTOR_EQ`'s and `WideTextIO`'s old deviations gone;
  - `MONO_VECTOR_EQ` kept only inside the library, for `Word8Vector`.
- The suite's transcriptions of the changed signatures, as change-request
  files that `scripts/gen-basis-sigs.sh` and `check-claims.sh` accept.

| Run | Result |
|---|---|
| `make test-basis` | 540/540 (537 before; 3 new tests) |
| `make test-laws` | 230/230, with three lines of `law-skips.txt`: the `skipWS` law at `WideStringCvt`, which is written for 8-bit text; and, by wildcards, every law of `IMPERATIVE_IO` and `STREAM_IO` at `WideTextIO`, which needs an arbitrary for its streams |
| `make check-docs` | passes: 65 signatures token-equal to their transcriptions, 205 claims |
| `make matrix-quick`, rune | 139,371/139,371 |
| `make matrix-quick`, xc1 on MLton, SML/NJ (three builds), Poly/ML | no failure |
| `make matrix-quick`, xc1 on MLKit | 175 failures, the same with master's library: not this change's |
| xc2:mlton | 138,711 checks, no failure |
| compile of the compiler with the new library | +0.036% instructions; with the edits kept line-neutral, `bin/rune.rbc` is byte for byte master's |

No shim was needed for xc1 or xc2, and no line of `deviations.txt`.
`XC2StringOps` needs only `WideString.size`, `sub` and
`WideCharVector.tabulate`, and `WideCharVector.vector = WideString.string`
still holds.

**Stage 3: `WideChar.chr` refusing surrogates.**
- The Basis suite and xc2:mlton still pass.
- But 9 law programs fail, 42 laws in all. The arbitrary for `WideChar`
  draws `chr` over 0 to `maxOrd` (`lib/test/property/basis/family.sml:142`).
- The `CHAR` laws `ord (chr i) = i` and `pred (succ c) = c` become false, at
  the 2,048 surrogates and at U+D7FF.
- `WideChar.fromString "\uD800"` raises `Chr` instead of giving `NONE`.

**A side finding.** After the reorder, `WideString.string` prints as
`string` in the compiler's messages: "type elem is char in the structure but
char in the signature". The type printer should qualify a type name that is
not the top level's.

**What it predicts.**
- D18's option A works as specified. It costs implementations two lines and
  costs Rune no shim; G3 has nothing to stop on.
- D9: keeping code points costs nothing. Scalar values break two laws of
  `CHAR` and the property generator.

### E7. Overloading the string operations

**The single-type operations** `^`, `size`, `concat` and `substring` were
made overloaded over the string class, as the comparisons are (a patch of
102 lines):
- four builtin primitives in `src/elab/env.sml` and `overload.sml`;
- two small changes to translation (`src/core/translate.sml:12-23,152`);
- the four 8-bit definitions removed from `lib/basis/pervasive.sml`.

`WideString`'s existing `_overload` line registers its own `^`, `size`,
`concat` and `substring`.

| Measure | Result |
|---|---|
| the compiler compiling itself, to a fixed point | reached: the second and third builds are byte for byte the same |
| compile of the compiler, instructions | +0.18% |
| the compiler's bytecode | not byte-identical: 52 lines of the library's Mid change (pervasive's closures go, six aliases become primitives); no use in `src/` changes |
| `tests/lang` (289 programs) and `examples` (499), each compiled before and after | the same outcome, messages and bytecode for all 788 |
| the Basis suite, rune and xc1 | as before, with a 3-line shim |

The shim:
- xc1 rebinds the specification's top-level `concat`, `size`, `substring`
  and `^` to dummies, so that Rune's library can define them
  (`tests/basis/host/gen-host-basis.sh:76-80`).
- Once the library no longer defines them, the hosts' own must stand. The
  shim takes the four off that list.

`fun twice x = x ^ x` still defaults to `string`. `"a" ^ "λ"` is a
`WideString.string`.

**`print`** was left out. `WideTextIO.print` is not part of `WideString`, and
the library is loaded by the names a program uses. A wide `print` would need
either a UTF-8 `print` inside `widestring.sml` or a rule for loading.

**The paired operations** `str`, `implode` and `explode` relate a character
type and a string type:
- They need two linked class variables, unified in step:
  - a new kind, or a table of pairs consulted in `Unify.bindVar` and when
    defaults are resolved (`src/elab/elaborate.sml:160-175`);
  - with the companion type taken from the registered structure (`STRING`'s
    `type char`).
- That is days of work, against hours.
- **`chr`** is resolved only by its result. `implode (map chr [955])` would
  default to 8-bit and raise `Chr` at run time, where a type error would be
  expected.

**What it predicts.**
- D20's single-type part is cheap and changes no program that compiles
  today.
- The paired part waits.
- `chr` is never overloaded.
- `^` at `WideString` is only as fast as `WideString.^`, which E8 measured.

### E8. What wide text costs

**Bytes per character,** with Rune's 8-byte header and payloads rounded to 8
(`runtime/value.h`):

| Text | Today: a word each | Packed, 4 bytes | UTF-8 | PEP 393 (1, 2 or 4) |
|---|---|---|---|---|
| ASCII | 8 | 4 | 1.00 | 1 |
| Latin-1 | 8 | 4 | 1.22 | 1 |
| Greek | 8 | 4 | 1.87 | 2 |
| CJK | 8 | 4 | 3.00 | 2 |
| emoji | 8 | 4 | 4.00 | 4 |
| a mixed line with one emoji | 8 | 4 | 1.23 | 4 |

What each would change elsewhere:
- **A word each (today).** `sub` is constant time and already inlined by
  the JIT and the native code generator. The arrays, slices and xc2's shim
  are as they are.
- **Packed.** Needs a raw object kind (as `K_REALS` is) and new primitives in
  the interpreter, the JIT and runeopt.
- **UTF-8.** Makes `sub` and slices linear, makes arrays and vectors convert
  on every copy, and makes MLton's library, run on Rune by xc2, quadratic.
- **PEP 393.** Needs three widths in every primitive, and widens whole
  strings on `^`.

**Measured** with `runevm --count` (`results/E8`):

| What | Instructions | Allocated |
|---|---|---|
| a wide literal of 7 code points, evaluated | 2,467 per evaluation | 3.8 KB |
| the same of 50 code points | 15,262 per evaluation | 24 KB |
| the same bound once with `val` | about 18 per use | none |
| 1,000 times `acc ^ piece`, `String.^` | 15,555 in all | 5 MB |
| 1,000 times `acc ^ piece`, `WideString.^` | **170,287,835** in all | 440 MB |
| `TextIO.inputAll` of 10 MB | 499,301 | 31 MB |
| `WideTextIO.inputAll` of 10 MB of ASCII | **2,063,041,004** (206 a byte) | 3.1 GB; 13 s and 806 MB at peak |

The causes are in the library, not in the representation:
- `WideString.^` concatenates through lists (`lib/basis/widestring.sml:17`,
  `vector.sml:33`).
- `WideTextIO` decodes one byte at a time through `TextIO.input1`
  (`widetextio.sml:176`).
- Wide literals are parsed again at each evaluation.

**What it predicts.**
- D19: keep a word per code point. UTF-8 is ruled out, and packing halves
  memory, but needs new primitives in the interpreter, the JIT and runeopt.
- M8 takes the measured costs as tasks:
  - primitives for vector concatenation, tabulation and extraction;
  - a UTF-8 decoder that reads blocks;
  - wide constants made once, in M4.
- The overloaded `^` of M10 waits for the first of these.

### E9. A lexer with source modes, and what it costs

**What was built.** Three copies of master, built as `make bin/rune` builds
them, with MLton and then by themselves:
- **The base,** master plus a flag `--lex-count N` that lexes its inputs N
  times and prints tokens and bytes.
- **The prototype,** the base plus:
  - `--source-mode legacy|ascii|latin1|utf8`;
  - checks of comments, white space and literals by the table of *The
    architecture*, without the BOM-only and line-end rows;
  - XID identifiers under `utf8` with an NFC quick check, from tables
    generated from the host Python's Unicode 15.0 data (21.5 KB of SML).
- **The optimised prototype,** the prototype plus:
  - a 256-entry class table for the bytes of comments;
  - a byte of properties per code point, built at the first non-ASCII
    identifier, in place of a binary search over 775 ranges.

The scripts and diffs are in the drafts (`scripts/E9`,
`results/E9/prototype`). Instructions are `runevm --count`: the difference
between one pass and five over the same files, so start-up is not counted.

**What each mode accepts:**

| Corpus | Files | Today | default | `--unicode` |
|---|---|---|---|---|
| the compiler (`rune.build`, 1.1 MB) | 74 | 74 | 74 | 74 |
| Rune's tracked sources | 2,152 | 2,149 (3 are tests of lexer errors) | 2,144 | 2,147 |
| HOL4 `src` and `examples`, after `unquote` (104 MB) | 3,419 | 3,419 | 3,419 | 3,419 |
| MLton's sources (14 MB) | 1,787 | 1,784 | 1,784 | 1,784 |

- **Rune's tree in the default mode:** the five files refused are
  `examples/benchmarks/sat/upstream/original.sml` (a raw `"φ("`) and the four
  `tests/diagnostics` files that hold odd characters on purpose.
- **Under `--unicode`,** two of those are still refused: `badbyte.sml` (not
  UTF-8) and `bidi.sml` (U+202E in a literal).
- **MLton's three files refused today** are refused for reasons this roadmap
  fixes or leaves:
  - `regression/widechar.sml:201`: `#"\256"` and `#"\999"` at `WideChar`
    (D8, M1);
  - two files that write `Error.: T`, which Rune's lexer calls a malformed
    long identifier.

Small probes behave as designed:
- a decomposed `é` in a name is refused as not NFC; `été` in NFC is
  accepted;
- U+202E in a comment and VT between tokens are refused;
- Greek structures and long identifiers (`Σ.α`) work;
- `val ㅤ = 1`, a name of one U+3164, is accepted by plain XID, which is X5
  shown.

**Instructions to lex, per pass:**

| Corpus | Today | Prototype, default | Optimised, default | Optimised, `--unicode` |
|---|---|---|---|---|
| the compiler, 1.1 MB, 199,176 tokens | 53.6M | 59.4M (+10.8%) | 57.6M (+7.4%) | 57.6M |
| MLton, 14.1 MB | 595.9M | 666.3M (+11.8%) | 651.8M (+9.4%) | 651.8M |
| HOL4, 103.6 MB | 4,456M | 4,959M (+11.3%) | 4,824M (+8.3%) | 4,824M |
| 20,000 lines with ASCII names | 38.9M | 42.5M (+9.1%) | 40.5M (+4.1%) | 40.5M |
| the same with Greek names | - | - | - | 78.7M (binary search: 205.6M) |
| the same with CJK names | - | - | - | 62.3M (binary search: 150.4M) |

**A whole compile of the compiler** (its 74 files to bytecode) is 1,031M
instructions today. Lexing is 5.2% of it. With the optimised prototype
in the default mode, it is 1,036M: **0.48% more** than the base compiling the
same files by the same absolute paths (1,031.0M; E9's summary).

**What it predicts.**
- The modes cost about 0.5% of a compile in this first form, and
  `--unicode` costs nothing over the default for ASCII text. The remaining 7 to 9%
  of lexing is in the extra tests on each byte of white space and comments,
  which a lexer written for the modes, rather than patched, can share.
- Unicode identifiers cost 1.5 to 1.9 times what ASCII ones cost per token,
  once the property lookup is a table. A binary search over the ranges costs
  3.5 to 4.8 times, which is why the tables are generated in two stages (M5).
- The prototype's NFC test took the quick check's Maybe as No. E4 shows that
  this refuses names that are already in NFC, so the real lexer checks a
  Maybe with `isNFC`. That is rare, and its cost is E4's.
- No random access by code point and no new structure was needed: the
  prototype stayed a byte-indexed lexer (W4).
- The brief's question "benchmark if this does not slow down lexing and
  parsing" (line 31) is answered for lexing. Parsing sees the same tokens and
  is unchanged. Still to be measured in M6:
  - the real lexer's call of `isNFC` on a Maybe;
  - the UTS #39 lints of D13.

### E10. Who consumes positions and names, and what columns cost

**The census** is *Appendix A*: the readers of source, the sixteen consumers
of byte positions, the sixteen places that test identifier characters again,
and the places that print text. Every consumer of a position indexes the
UTF-8 text by bytes. None needs code-point offsets; only a column shown to a
person might.

**Code-point columns.** A copy of the base whose `Source.lineCol` counts code
points from the line's start (it counts the bytes that do not continue a
UTF-8 sequence):

| Compile of the compiler | Instructions |
|---|---|
| base | 1,031.0M |
| code-point `lineCol` | 1,073.1M (**+4.1%**) |

The bytecode is identical, because the compiler's sources are ASCII.
`lineCol` is called for every span of the bytecode's line table, and each
call scans its line.

**What it predicts.**
- Columns in code points must be computed only where a person reads them
  (D15), or with a per-line flag that keeps ASCII lines free.
- The REPL drops a compiled input's text and keeps its line starts
  (`Source.keepLines`). The prototype's `lineCol` raises `Subscript` there,
  so M7 keeps the text of lines that need it.

## Constraints

- **The compiler is built by the hosts.**
  - `src/` and the files of `rune.build` are compiled by MLton, SML/NJ
    (64-bit, 32-bit and 2026.2), Poly/ML and MLKit, and all builds must make
    the same bytecode (`make check-cross`).
  - No `WideChar`, no `WideString`, no wide literal and no `\U` in them.
    Code points are `int`.
  - Tables must not rely on `Int` being wider than 31 bits; 0x10FFFF fits.
  - Arrays of lists of pairs are to be avoided, because of MLton's bug
    (`src/frontend/lexer.sml:27-47`).
- **The bootstrap budgets.**
  - `tests/perf/bootstrap.budget` and `check-heapsim` move with every table
    the compiler holds. Tables are strings decoded at first use, as
    `lib/unicode`'s are, so that a compile that meets no non-ASCII
    identifier never decodes them.
  - The real tables of normalisation and identifiers cost 2.2% of the
    bootstrap, 6.1% of `bin/rune.rbc`, 108 KB of allocation per compile,
    and 266 MB of the MLton build's peak memory (E5). That is within the
    budgets.
- **`lib/basis` uses no library.** Unicode classes for `WideChar`, if they
  ever come, need tables of the Basis's own (*Later*).
- **xc1 has no wide literals.** `tests/basis` builds wide values from code
  points, and no part of `lib/basis` may rely on `_overload` to compile on a
  host.
- **xc2:mlton** relies on:
  - `WideString.string` being an equality type;
  - `WideCharVector.tabulate`;
  - a constant-time `WideString.sub`;
  - `WideChar.chr` taking every code point, for its `XC2FixedWide`, which
    would raise on a surrogate though no check reaches one (E6).
- **The documents are checked.** `make check-docs` holds `docs/language.md`
  to the tests, every deviation note to `tests/basis/deviations.txt`
  (`check-notes.sh`), and every `Implements:` claim to a signature test
  (`check-claims.sh`). A change to what the lexer takes needs a
  `docs/language.md` row and a test in `tests/lang` or `tests/errors`.
- **Unicode 18.0.0** is the version of `lib/unicode`'s tables. New tables
  take the same version, generated by the same script from files pinned by
  SHA-256.
- **Positions are a public interface.**
  - `--serve` and the engine protocol give byte offsets.
  - `Compiler.compile`, through which HOL-rune compiles, takes a start line
    and prints its errors as `file:line:col`, with a byte column today.
- **The REPL reads its continuation state from the lexer's error text**
  (`src/repl/repl.sml:137`). New lexer errors must not contain
  "unterminated" unless more input could complete them.

## The architecture

### Source text stays bytes

The compiler keeps reading a file as one `string`, and positions stay byte
offsets into it (W4, W5). What changes is that the lexer knows the file's
**mode**, and looks at a byte of 128 or more:
- outside a comment or literal, as the start of an identifier;
- inside a literal, as a character of the literal;
- inside a comment, as text to be checked.

It decodes that byte and the ones after it with `Utf8.decode`, which the
compiler already contains.

ASCII bytes take today's paths, with one table lookup in place of two
comparisons inside comments (E9). Invalid UTF-8 is found where it is met, so
no separate pass over the file is needed. A file that is all ASCII is never
decoded.

**A mode is part of a `Source.file`**, not a global flag (D1). It comes from,
in order of precedence:
1. the unit's line in a build file (an annotation, as `allowPrim` is,
   `src/driver/main.sml:772-776`);
2. the command line (`--unicode`, `--unicode=utf8` or `--unicode=latin1`;
   nothing for ASCII);
3. the default (D16).

It also comes from:
- `Compiler.compile`'s parameters, for HOL-rune and other programs that
  compile;
- the REPL's options, for `use` and typed input.

The mode is stored with a unit in its cache settings, so a cache hit under
another mode is a miss (X2). The unit basis, which lexes a unit's source
again to find its functors, uses the unit's mode.

**`--unicode=latin1`** is an encoding, not a repertoire (C1, D3).
- The file is read as Latin-1 and made UTF-8 as it is read (E9's
  `Source.latin1ToUtf8`, one pass). From there on it is `--unicode` text whose
  characters are all at most 255.
- A raw character in a literal means its code point, so at `string` it is the
  file's own byte, as today.
- A file that holds a well-formed UTF-8 sequence of two bytes or more is
  refused as "looks like UTF-8".
- Positions are offsets into the converted text, which is the text that the
  diagnostics show.

### What a source may hold raw

One table for every mode and context (D5). "Escape" means the character may
be written in a literal as an escape and not raw. What changes from today:
- in comments, every "no" (today a comment takes any byte);
- between tokens, VT, a lone CR and a BOM;
- in literals, DEL and bytes above 127.

| Code points | Between tokens | Comment | Literal |
|---|---|---|---|
| space | yes | yes | yes |
| TAB | yes | yes | no: `\t` |
| LF | yes | yes | ends the literal (an error) unless in a gap |
| CR followed by LF | yes, as LF | yes | in a gap only |
| CR alone | no | no | no: `\r` |
| FF | yes (the Definition requires it) | yes | no: `\f` |
| VT | no | no | no: `\v` |
| other C0, NUL | no | no | no: escape |
| DEL | no | no | no: `\127` |
| printable ASCII 33-126 | as tokens | yes | yes |
| C1 controls (U+0080-U+009F) | no | no | no: escape |
| BOM U+FEFF | at the start of the file only, and dropped | no | no: escape |
| NEL U+0085, LS U+2028, PS U+2029 | no | no | no: escape |
| explicit bidi controls (U+202A-202E, U+2066-2069), the nine of Trojan Source | no | no | no: escape |
| bidi marks LRM, RLM, ALM (U+200E, U+200F, U+061C) | no | yes | yes |
| other default-ignorables (ZWSP, ZWJ, ZWNJ, WJ, variation selectors, U+3164 ...) | no | yes | yes |
| any other character above 127 | `--unicode`: in an identifier only (D10); default: no | yes, in every mode (D4) | `--unicode`: by type (D6); default: no |
| bytes that are not UTF-8 | no | no | no |

The rows are the same in every mode except the last but one. So the default
and `--unicode` differ only in where a non-ASCII character may stand outside a
comment. That is D2's rule made concrete: a program the default accepts means
the same under `--unicode`.

`--unicode=latin1` is `--unicode` once its file is converted, so it follows the
`--unicode` column, its characters are all at most 255, and it has no bytes
that are not UTF-8. Its C1 bytes, 0x80 to 0x9F, are C1 controls and refused.

Default-ignorables other than the nine controls are allowed in comments and
literals:
- ZWJ joins emoji, and a variation selector picks a glyph, so text needs them.
- The marks LRM, RLM and ALM change only the direction of the text around
  them, which is what a comment in Hebrew or Arabic needs.

They are refused in identifiers (D10), where nothing needs them.

UTS #55 counts VT, FF, NEL, LS and PS as line ends, and asks that a language
either count them or refuse them, even in comments. The table refuses all of
them but FF. FF stays white space, because the Definition requires it, and
no editor shows it as a line end.

### Literals by type and mode

| Raw in the literal, or escape | `char`/`string` | `WideChar`/`WideString` |
|---|---|---|
| ASCII 32-126 | the byte | the code point |
| `\ddd` | the byte; above 255 an error | the code point (today: above 255 an error; D8) |
| `\uXXXX` | the byte if at most 255, else an error | the code point; a surrogate is an error (D9) |
| `\UXXXXXXXX` | by default an error, "needs `--unicode`" (D7); under `--unicode`, as `\u` | by default the same error; under `--unicode` the code point, up to U+10FFFF, a surrogate an error |
| a raw character above 127, by default | an error: "write it as an escape" | an error: "write it as an escape" |
| a raw character above 127, `--unicode` | an error (D6: recommended; the brief's line 40) | the code point |
| a raw character above 127, `--unicode=latin1` | the byte, which is its code point (D3, D6) | the code point |
| a raw control | an error (table above) | an error |

Raw text and escapes then never disagree. Wherever a raw character is
allowed, it means its code point, which is what its escape means (X1, D6).

The lexer keeps a literal as a list of code points. The present choice of
`STRING` or `WIDESTRING`, by "every code point is at most 255", needs one
more fact: under `--unicode`, whether a raw character above 127 was met. The
lexer marks such a literal, and elaboration refuses the mark at `char` and
`string`, where it knows the type and can give the error with the literal's
span. Under `--unicode=latin1` nothing is marked, because a raw character is its own
byte. Today's check at the 8-bit types (`src/elab/elaborate.sml:117-141`)
grows a case: "raw non-ASCII character at type string".

### Identifiers

A new structure in `src/util`, `Ident`, holds the one definition of an
identifier's characters (D10). It is used by the lexer and by the sixteen
places that each write it again today (*Where we are*, *Appendix A*):
- the REPL's printer, highlighter, completion, line scanner and commands;
- the debugger;
- the kernel;
- runedoc's anchors, resolver, laws, claims, annotations, tests, pages and
  site.

An alphanumeric identifier, under `--unicode`:

```
ident    ::= start continue*
start    ::= ASCII letter | XID_Start \ (Default_Ignorable ∪ Lookalikes)
continue ::= start | ASCII digit | ' | _ | XID_Continue \ (Default_Ignorable ∪ Lookalikes)
tyvar    ::= ' continue*
```

- **Default_Ignorable** is the set of Unicode 18.0, written in the source and
  frozen. UAX #31 §2.3 says the property is not stable, so later versions
  could otherwise make a refused identifier valid, or the reverse. Taking it
  out is UAX #31's Default-Ignorable Exclusion Profile (§7.3).
- **Lookalikes** is a frozen list, written in the source and not derived from
  data, of identifier characters that look like Standard ML punctuation or
  digits, and that UTS #39 does not recommend for identifiers (the owner,
  2026-10-18, for the digits and at G2). It holds 239 code points:
  - of the 85 identifier characters that UTS #39's skeletons map to one
    ASCII punctuation or symbol character, the 76 that are not Recommended,
    such as `ǃ ʼ ʹ ꓸ`;
  - of the 129 identifier characters that look like the digits 2 to 9, the
    116 that are not Recommended: fullwidth, mathematical, outlined and
    segmented digits, and rare letters such as Cherokee and Canadian
    Syllabics;
  - the 21 decimal digits that look like 0 and 1, which the skeletons map
    to the letters O and l, and that are not Recommended;
  - by hand, `·` U+00B7, which the skeletons miss;
  - by hand, the 26 lookalikes of `|`, which the skeletons map to `l`, that
    the code charts draw as a stroke and that are not Recommended, such as
    `ǀ` U+01C0. One of them, U+1FBF1 SEGMENTED DIGIT ONE, is also among the
    digits.

  The 9 Recommended lookalikes of punctuation stay allowed: Hebrew yod
  U+05D9, Katakana no U+30CE, Armenian feh U+0586, the Arabic-Indic zeros
  U+0660 and U+06F0, the visargas U+0903 and U+0A83, and CJK U+4E36 and
  U+4E3F. Refusing them would make most Hebrew names and many Japanese ones
  impossible. The 13 Recommended lookalikes of digits stay allowed too:
  - Cyrillic б, З and Ӡ;
  - Armenian Յ;
  - Georgian Ⴧ, Ჷ and Ვ;
  - Latin Ʒ;
  - Devanagari ३, Gujarati ૩, Bengali ৪ and ৭;
  - the Oriya sign visarga U+0B03.

  They are everyday letters and native digits of living scripts, which UTS #39
  recommends. Refusing them would make Russian names such as `работа`
  impossible. D13's confusable warnings catch a name that differs from
  another only by one of them, and a name that is one of them alone, such as
  `ノ`, whose skeleton is `/` (M6).
- In UAX #31's terms, Rune declares a profile (UAX31-R1-2):
  - it adds `'`, which is Pattern_Syntax, to Continue;
  - it removes the two frozen sets;
  - it keeps Medial empty.
  
  It meets UAX31-R6 (filtered identifiers) with NFC.
- **Symbolic identifiers stay ASCII** (D11).
- **Long identifiers** take any identifier as a part (`Σ.α`).
- **Labels and numbers** stay ASCII.

An identifier with a character above 127 must be in NFC (D12):
- The quick check (NFC_QC) decides almost every one without normalising.
- Only a character marked Maybe sends the identifier to `Normalize.nfc`.
- One that is not NFC is an error that gives the NFC spelling.

So a name is always the bytes of its span: the sixteen places above, the
unit files and the cache need no change for names, and equal names are
equal strings.

The NFC and identifier tables (D10, D12) cost the compiler 2.2% of its
bootstrap, 6.1% of its bytecode and 108 KB of allocation per compile (E5).
ASCII sources never decode them. The UTS #39 data of D13's lints was not
measured; it is the size of `confusables.txt`'s 6,712 mappings at most.
- The profile is one table, XID less the two frozen sets, for start and
  continue.
- The lexer looks it up through a property byte per code point, built at the
  first non-ASCII identifier of a run. In E9's prototype this was a
  `Word8Array` of 0x30000 entries; a generated two-stage table is better.
  With it, Greek identifiers lex at 1.9 times the cost of ASCII ones and CJK
  at 1.5 times, against 4.8 and 3.5 times by binary search (E9).
- The quick check marks a few characters of ordinary words Maybe: Tamil and
  Malayalam vowel signs, the Devanagari nukta, Hangul jamo. For those the
  lexer calls `Normalize.isNFC` (E4).

**Warnings** (D13), never errors, from UTS #39 data:
- an identifier whose characters mix scripts in a way UTS #39's moderately
  restrictive profile refuses;
- two identifiers of a unit that are confusable (equal skeletons) but not
  equal, or an identifier confusable with a reserved word;
- a character of identifier status Restricted;
- a comment that holds something whose skeleton contains `*)`, a lookalike
  of the comment's end, as UTS #55 §5.1.5 suggests.

They are lints that a program can turn off, as rustc's are, and they may
change with a Unicode version without breaking a build.

### Positions and columns

Byte offsets stay in every machine interface: spans, the unit files, the
line table, DWARF, `--serve` and the engine protocol (W5). What a person reads is converted when it is shown (D15):
- `file:line:col` counts code points from 1, as rustc does. It is computed
  only when a diagnostic is shown; computing it on every call costs 4.1% of
  a compile (E10).
- The DAP's columns are converted to UTF-16 units, which is what
  `--diagnostics-json` already gives rune-ide, and what DAP clients count.
- The line table and DWARF keep byte columns. A DWARF column has no defined
  unit, and debuggers show it as given.

`Source.keepLines`, which the REPL uses to drop a compiled input's text,
keeps the text of lines that hold non-ASCII. Otherwise a column could not be
computed (E10).

### Showing source and names

- **Diagnostics** already escape controls, bidi controls and bad bytes in
  excerpts. The first line names the file unescaped today
  (`src/util/diagnostic.sml:21-22`); M7 escapes it the same way.
- **The REPL's printer** shows a name as it is. By D10, a name has no control
  or invisible character to show.
  - It shows a `string` with `String.toString`, as today.
  - It shows a `WideString` as UTF-8 text, with C0, C1, DEL, the bidi
    controls and the default-ignorables escaped as `\u` (D14). A value cannot
    then send a terminal a control sequence (X9).
- **runedoc's anchors** spell a non-ASCII character as `u` and its code point,
  lowercased as anchors are (`val-u3bb`), not byte by byte.
- **`Json.escape`** escapes bytes that are not UTF-8 instead of raising
  `Domain` (M1).

### `lib/unicode`

Two structures join the library, with their tables generated by
`scripts/gen-unicode-tables.py` from pinned UCD files (E4, E5):
- **`Normalize`:** NFD and NFC, the NFC quick check, and `isNFC`. It works
  over UTF-8 strings and over code points. Hangul is handled by algorithm.
  It is tested with all of `NormalizationTest.txt`.
- **`Identifier`:** XID_Start, XID_Continue, Default_Ignorable_Code_Point,
  the frozen lookalikes, and, for the lints, UTS #39's identifier status,
  script sets and confusable skeletons.

The compiler takes the files it needs, as it takes `Utf8` today, so the
library and the compiler share one implementation.

### The symmetric text signatures

The brief asks for "two implementations of the same signatures" (line 4).
`CHAR`, `STRING`, `SUBSTRING`, `TEXT` and `MONO_VECTOR` are already
written so that both widths can match them. Three are not, and one
declaration is missing a constraint. The fix, written out in *Appendix C*,
moves the text types out of the signatures and into the declarations, which
is how the specification already treats `MONO_VECTOR`, `PRIM_IO` and
`STREAM_IO`:

- **`TEXT_STREAM_IO`** includes `STREAM_IO` without fixing `vector` and
  `elem`, and gains `type substring`.
- **`TEXT_IO`** names `vector`, `elem` and `substring` as its stream's. Its
  readers and writers are no longer `TextPrimIO`'s. File names stay `string`,
  which is always `String.string`: a file name is bytes for the operating
  system, not text of the program's width.
- **`STRING_CVT`** takes `eqtype char` and `eqtype string`. `StringCvt` is
  its 8-bit instance, and a new optional `WideStringCvt` its wide one,
  sharing `radix` and `realfmt`.
- **The declarations** say what the signatures no longer say:
  - `TextIO :> TEXT_IO where type StreamIO.vector = CharVector.vector ...
    where type StreamIO.reader = TextPrimIO.reader ...`;
  - `WideTextIO :> TEXT_IO` with the wide types;
  - `WideCharVector :> MONO_VECTOR where type vector = WideString.string
    where type elem = WideChar.char`.

`CHAR` and `STRING` keep converting to and from `String.string`
(`toString`, `fromString`, the C strings). That is not an asymmetry
of the signatures: both families match them, and the rendering with escapes
is ASCII whatever the width.

**In Rune's library:**
- **The wide family is built in the 8-bit order and sealed once.** An
  internal structure holds `WideChar`, `WideString`, `WideSubstring`,
  `WideCharVector` and the rest, sealed together with the constraints of
  the specification plus `where type vector = WideString.string`. The public
  structures are bindings to its parts, as `Word8Vector`'s seal does
  already.
- **`MONO_VECTOR_EQ` leaves the public library.** It stays inside it as
  `RUNE_MONO_VECTOR_EQ`, because `Word8Vector`'s type is born at a vector
  seal and keeps its equality that way.
- **`WideString`'s representation stays a word per code point (D19).** The
  costs E8 measured are fixed where they are:
  - `WideString.^`, `concat` and `tabulate` get primitives instead of lists;
  - `WideTextIO` decodes UTF-8 a block at a time;
  - wide literals become constants.

**The deviations**, each a `Deviation:` note pinned by tests:
- `TEXT_STREAM_IO/generic`, `TEXT_IO/generic` and `STRING_CVT/generic`, the
  change request;
- `WideStringCvt/not-in-the-specification`.

They replace `MONO_VECTOR_EQ/not-in-the-specification` and
`TEXT_IO/WideTextIO-not-matched`. The suite's transcriptions of the three
signatures become change-request files beside the specification's
(`tests/basis/spec-sigs/scr/`), which `scripts/gen-basis-sigs.sh` and
`tests/basis/check-claims.sh` take in their place.

### String operations at both widths

`^`, `size`, `concat` and `substring` become overloaded over the string
class, as `<` is: one builtin each, resolved by the type and defaulting to
`string`. `WideString`'s `_overload` line already registers its own.
- `str`, `implode` and `explode` would need two class variables linked in
  step, a character and a string. That is left for later (D20).
- `chr` is never overloaded: it is resolved only by its result, and a
  default to 8-bit would turn a missing annotation into `Chr` at run time.
- `print` stays 8-bit. A wide `print` belongs to `WideTextIO`, which a
  program names to get it.

## Decisions

Each decision gives the options, what favours each, and the recommendation
it was written with. The owner decided all of them on 2026-10-18, each as
recommended. D1's flags and D7's `\U` are the owner's own (*The request*):

| Decision | Decided |
|---|---|
| D1. Where the mode is set | A: per file; `--unicode[=ENC]` (the owner's names), build annotation, `Compiler` API; in the cache key |
| D2. Modes agree where they overlap | A: yes, as a rule the tests check |
| D3. `--unicode=latin1` | B: an encoding, converted as it is read; a raw character means its code point |
| D4. Comments in the ASCII mode | A: any UTF-8 text but the refused code points |
| D5. What a source may hold raw | A: the table of *The architecture* |
| D6. Raw non-ASCII in a literal at `string` and `char` | A: an error under `--unicode`; a raw character means its code point |
| D7. `\x` and `\U` | A: no `\x`; `\U` only under `--unicode` (the owner, 2026-10-18) |
| D8. `\ddd` at the wide types | A: the whole alphabet, as the Definition says |
| D9. Code points or scalar values | A: `WideChar` holds code points; scalar values at the boundaries |
| D10. Unicode letters in identifiers | A: XID, less default-ignorables and lookalikes |
| D11. Unicode symbols in identifiers | A: no |
| D12. NFC | A: require it, and say the NFC spelling |
| D13. Errors and warnings | A: errors from stable data only; UTS #39 as warnings |
| D14. Printing non-ASCII | A: names raw; wide strings with controls and invisibles escaped |
| D15. Columns | A: bytes in machine data; code points shown, UTF-16 for the DAP |
| D16. The default | A: ASCII (with D4), everywhere, as M3 and M4 bring its rules; no `legacy` mode |
| D17. The Unicode version | A: one pinned version for all tables, in the cache's configuration |
| D18. The symmetric text signatures | A: generic `TEXT_IO`, `TEXT_STREAM_IO`, `STRING_CVT`; `WideCharVector` pinned to `WideString.string` |
| D19. The representation of `WideString` | A: as it is, a word per code point |
| D20. Overloading the string operations | A: `^ size concat substring` over the string class; not `str implode explode chr print` |

### D1. Where the mode is set

**Decided: A** (2026-10-18), as recommended, with the owner's flag names (*The request*).

The mode must reach the lexer for every source: files on the command line,
units of a build, `use` in the REPL, `Compiler.compile`, and the unit basis
when it lexes a cached unit's source again.

* **A. Per file.** `Source.file` gets the mode, one of `ascii`, `utf8` and
  `latin1`. It is set:
  - on the command line, by nothing (`ascii`, the default), `--unicode` or
    `--unicode=utf8` (`utf8`), or `--unicode=latin1` (`latin1`). The owner
    decided these names on 2026-10-18 (*The request*). The last flag wins.
    The value must be joined by `=`: `--unicode latin1` would read `latin1`
    as an input file, so an input of that name that cannot be read gets the
    hint "did you mean `--unicode=latin1`?". The REPL's parser, which takes
    `--color always` with a space, takes `--unicode` only with `=` as well;
  - by an annotation on a unit's line in a build file, which can also say
    `ascii` for a unit of a build whose command line says `--unicode`;
  - by a field of `Compiler.compile`'s parameters;
  - and stored in the unit's cache settings. **Recommended.**
  - One program may mix modes. HOL4's theories can be read with `--unicode`
    where Rune's Basis is ASCII.
  - X2 cannot happen. A unit cached under one mode is a miss under another,
    and the unit basis lexes again with the unit's own mode.
  - It is how `--or-patterns` and `allowPrim` work today.
* **B. One global flag.** Simplest, but the Basis and every library would be
  read in the mode chosen for the program. The cache would still need the
  mode in its key.
* **C. A pragma in the file,** as Python's `coding:` comment. Standard ML has
  no pragma syntax. A comment that changes how the file is read is easy to
  miss, and is itself text in some mode.

### D2. Modes agree where they overlap

**Decided: A** (2026-10-18), as recommended.

* **A. A program that two modes accept means the same in both.** The tests
  check it: every accept test of the default runs under `--unicode` with the same
  output. **Recommended.**
  - A mode only says what is refused. Turning a flag on cannot change what a
    working program does.
  - `--unicode=latin1` (D3) reads another encoding. It is outside the rule, as an
    encoding flag must be: the same bytes are other characters.
  - Within the rule, the default and `--unicode` agree because D6 refuses a raw
    non-ASCII character at `string` rather than giving it a meaning that
    its escape does not have (X1).
* **B. No rule.** Each mode is designed on its own.

### D3. `--unicode=latin1`

**Decided: B** (2026-10-18), as recommended.

The brief has `--latin1` both as a code page to convert (line 18) and as a
repertoire in a file that is UTF-8 (line 40) (C1). HOL4 and MLton do not need
it (C4). The census found 17 sources in Latin-1, 16 of them MLKit's (E1).
Three of those hold `"(æ|ø|å)"` in literals, meaning the bytes E6, F8 and E5,
which Rune keeps today.

* **A. Leave it out.** These 17 files stay compilable only by today's
  behaviour, which no mode keeps.
* **B. An encoding.** The file is Latin-1. It is converted to UTF-8 as it is
  read, so that the lexer, the positions and the diagnostics see one kind of
  text. From there, a raw character means its code point, as in every mode
  (D6):
  - `"æ"` is the byte E6 at `string`, as today, and U+00E6 at `WideString`;
  - `café` is an identifier, the same name as `café` in a UTF-8 file
    (D10). **Recommended.**
  - About 50 lines and their tests (E9's prototype had the conversion).
  - MLKit's three tests mean what they mean today.
  - **The danger** is a UTF-8 file read as Latin-1. `é` would become `Ã©`, and
    both its bytes are above U+009F, so they pass every rule. The mode
    therefore refuses a file that holds a well-formed UTF-8 sequence of two
    bytes or more, with "this file looks like UTF-8; use `--unicode`". Real
    Latin-1 text almost never forms one: `æ` followed by an ASCII letter does
    not.
* **C. A repertoire.** The file is UTF-8, and only code points up to 255 are
  allowed. This gives neither old files nor any new safety.

### D4. Comments in the ASCII mode

**Decided: A** (2026-10-18), as recommended.

This decides whether HOL4 and MLton compile under the default (C4).

* **A. Any UTF-8 text but the refused code points of D5.** **Recommended.**
  - The Definition allows any character in a comment, so non-ASCII text needs
    no deviation. What D5 refuses there (controls, bidi controls, line
    separators, invalid UTF-8) is a deviation of the default, pinned by tests
    in M3. The other is D9's refusal of surrogates in escapes.
  - HOL4's 425 files as HOL-rune compiles it, MLton's 2, SML/NJ's 13 and Rune's 3 with
    non-ASCII comments compile (E1, E9).
  - Bidi controls, controls and invalid UTF-8 are still refused (X8).
* **B. ASCII only,** as line 11 reads.
  - Refused: 425 of HOL4's files as HOL-rune compiles it (165 of them generated by HOL, which
    nobody edits), MLton's 2, SML/NJ's 13, and Rune's `lib/unicode`.
  - It is a deviation, stricter than the Definition, to pin by tests.
  - A comment has no escape, so a name such as `Fowler–Noll–Vo` must be
    respelled.
* **C. Any bytes,** as today. Invalid UTF-8 and bidi controls pass, and with
  them the commented-out-code attack of Trojan Source.

### D5. What a source may hold raw

**Decided: A** (2026-10-18), as recommended.

* **A. The table of *The architecture* (*What a source may hold raw*).**
  **Recommended.** In short:
  - between tokens: space, TAB, LF, CRLF and FF;
  - in literals: no controls of any kind;
  - in any context: none of the nine explicit bidi controls, no C1, no NEL, LS or PS, no BOM past
    the start, and no invalid UTF-8;
  - default-ignorables only in comments and literals.
  
  The cost, over the 17,801 files of E1:
  - None holds NUL, VT, another C0 control, DEL, C1, NEL, LS, PS, a BOM, or
    a bare CR. No literal holds a raw TAB.
  - Two SML/NJ files use FF between tokens, which stays allowed.
  - Only Rune's own `tests/diagnostics` hold bidi controls and joiners.
  - The row for bytes that are not UTF-8 refuses 19 files. MLKit's 16 and
    Moscow ML's one are Latin-1 and pass under `--unicode=latin1`. The other two are
    Rune's bad-byte test and an SML/NJ regression test.
  - VT is refused by SML/NJ, MLKit and Moscow ML already (E2).
  - Bare CR is taken by every system, but Rune counts its lines wrongly
    today (E2), so refusing it costs nothing and fixes that.
* **B. The brief's list only:** `\r \n \t` and nothing else. It refuses FF,
  which the Definition requires, and says nothing about the Unicode-only
  cases.
* **C. Refuse nothing new** beyond what the modes refuse. The bidi controls
  stay a Trojan Source hole.

Zig refuses C0 (but TAB, LF, CR), DEL, NEL, LS and PS anywhere in a source,
comments included. Elixir and Scala refuse the nine bidi controls, and rustc
refuses them in comments and literals as lints that deny by default (E3).

UTS #55 advises the opposite for bidi controls: "The solution is not to
forbid the directional formatting characters." It would leave them to
editors and warnings. A refusal costs Rune little, because a literal can
escape them. A comment cannot, but code comments that need an explicit
embedding are rare, and the marks LRM, RLM and ALM stay allowed. A rule
holds for every reader, every editor and every review tool; a display fix
holds only where it is installed.

UTS #55 also suggests allowing the marks LRM and RLM between lexical
elements, as invisible spacing that steadies the display of right-to-left
names. D5 allows them in comments and literals but refuses them between
tokens. With D11, SML code has no right-to-left operators. Right-to-left
identifiers are rare in code, and an invisible character between tokens is
what X5 warns of. If programs in Hebrew or Arabic names ask for it, the row
can be opened later without breaking anything.

### D6. Raw non-ASCII in a literal at `string` and `char`

**Decided: A** (2026-10-18), as recommended.

In every mode, **a raw character in a literal means its code point**, as its
escape would:
- At `WideString`, `"é"` is U+00E9.
  - Today Rune, like MLton with `allowExtendedTextConsts`, makes it the two
    code points U+00C3 U+00A9, one per byte (E2). This roadmap leaves that
    reading deliberately.
- Under `--unicode=latin1`, every character is at most 255 and is the file's own
  byte, so at `string` raw text and escapes agree. `"æ"` is the byte E6, as
  today (D3).

Under `--unicode` the file's bytes and the code point disagree: `é` is C3 A9 in
the file and 233 as a character. At `string`:

* **A. An error,** as the brief's line 40 asks. The 8-bit spelling is
  `"\195\169"` for the UTF-8 bytes, or `"\233"` for Latin-1. **Recommended.**
  - Raw text and escapes never disagree (X1).
  - A program that wants bytes says which.
  - HOL4 is unaffected: its filter escapes such bytes (C4).
  - MLKit's three Latin-1 literals compile under `--unicode=latin1`.
  - Rune's tree has one raw UTF-8 literal outside its diagnostics tests,
    in an upstream copy of a benchmark
    (`examples/benchmarks/sat/upstream/original.sml`). It takes the
    escape `"\207\134("` (M11).
  - Other systems show why converting silently is the danger (E2):
    - HaMLet cuts a literal at its first non-ASCII character (`"café"` in
      Latin-1 becomes `"caf"`);
    - MLKit turns a raw TAB into spaces;
    - Moscow ML ends the file at a NUL.
* **B. The UTF-8 bytes,** as Rune does today and as SML/NJ, MLKit, Moscow ML
  and MLton with its annotation do. `print "λ\n"` works.
  - `"é"` is then two bytes while `"\u00E9"` is one, and `"€"` compiles
    while `"\u20AC"` is an error.
  - `#"é"` must stay an error.
  - It breaks the rule above, that a raw character means its code point.
* **C. The code point as a byte** where it is at most 255, otherwise an
  error.
  - It keeps the rule: `"é"` is `"\233"`.
  - But a UTF-8 file's `"é"`, two bytes today on every system, would
    silently become one.

### D7. `\x` and `\U`

**Decided: A** (2026-10-18), as recommended, for `\x`; `\U` as the owner set it, below.

**`\U`: decided by the owner (2026-10-18).** `\UXXXXXXXX`, Rune's extension from
Successor ML, is allowed only under `--unicode`. By default it is an error
that says so ("`\U` needs `--unicode`"). This is as MLton gates it, behind
the annotation that also admits its UTF-8 literals (E2).
- With it the default writes only the Definition's escapes, and adds no
  extension to them. Its two deviations are restrictions: D5's rules for
  comments, and D9's refusal of surrogates in escapes.
- A code point above U+FFFF then has no spelling in a literal by default:
  `\u` has four digits and `\ddd` stops at 999. A program that wants one says
  `--unicode`, or builds it at run time (`WideChar.chr 0x1F600`).
- The Basis's run-time conversions have no mode and keep `\U`:
  `WideChar.toString` and `WideString.toString` write it above U+FFFF, and
  `fromString` and `scan` read it. What they write is source text only
  under `--unicode`.
- Two tests use it as an escape: `tests/lang/ty.overload.literal_wide.sml`
  and `ty.overload.literal_cached_limits.sml`. They take `--unicode` in their
  `.cargs` (M4).

**`\x`:**

* **A. No `\x`.** `\ddd` and `\u` say every byte and code point already. No
  host takes `\x`, so the compiler's sources could never use it.
  **Recommended.**
* **B. `\xHH`** as Python reads it: the character with that number, so a
  byte at `string` and U+00HH at `WideString`. `String.fromString`,
  `Char.scan` and `toString` would have to take it too, or the lexer and
  the Basis disagree about what an escape is.

### D8. `\ddd` at the wide types

**Decided: A** (2026-10-18), as recommended.

* **A. The alphabet's whole range,** as the Definition says. `\999` is
  U+03E7 at `WideChar`, and an error at `char`. MLton takes it, and its
  regression suite uses it (`regression/widechar.sml:201-202`), which Rune
  cannot lex today. **Recommended.**
* **B. At most 255 everywhere,** as today: a restriction the Definition
  does not make.

### D9. Code points or scalar values

**Decided: A** (2026-10-18), as recommended.

`WideChar.chr` takes any number from 0 to 0x10FFFF, surrogates included. The
`CHAR` law `ord (chr i) = i` for every `i` up to `maxOrd` requires it
(`lib/basis/sig_char.sml:76`). `docs/unicode.md` claims otherwise.

* **A. `WideChar` holds code points; scalar values are enforced where text
  meets the world:**
  - the lexer: a surrogate in `\u` or `\U` is an error. By D8's reading of the
    Definition (any number of the alphabet) that is a deviation, pinned by a
    test;
  - the UTF-8 encoder and decoder of `WideTextIO`;
  - `Serve`;
  - `Utf8`.
  
  **Recommended.** It keeps the law and the shim, and no surrogate is ever
  written as text.
* **B. Scalar values only.** `chr` raises `Chr` on a surrogate. E6 built it:
  - The laws `ord (chr i) = i` and `pred (succ c) = c` become false, at the
    surrogates and at U+D7FF: a deviation from `CHAR`.
  - Nine law programs of the wide family fail, because the property
    generator draws `chr` over the whole range.
  - `WideChar.fromString "\uD800"` raises instead of giving `NONE`.
  - xc2's shim would raise on a surrogate, though no test reaches one.
  - The gain is a guarantee that the boundaries of A give already.

### D10. Unicode letters in identifiers

**Decided: A** (2026-10-18), as recommended.

* **A. UAX #31's default syntax, adapted to SML, less the default-ignorables
  and a frozen list of lookalikes** (*The architecture*, *Identifiers*).
  **Recommended.**
  - XID is stable: a valid identifier stays valid in later Unicode versions
    (X7).
  - Refusing default-ignorables closes the invisible identifier (X5). It is
    what UAX #31 §2.3 advises for general-purpose identifiers since joiners
    entered XID_Continue in 15.1, and what Rust and Elixir do. Nothing that
    needs ZWJ or ZWNJ in a word is lost in a language whose identifiers are
    names in code.
  - The excluded default-ignorables are frozen at 18.0, because the property
    is not stable (UAX #31 §2.3).
  - UTS #55 recommends UAX #31's mathematical profile too: `∂ ∇ ∞` and the
    sub- and superscript digits, as in `x₁`. It could join later; its signs
    `⁺ ⁻ ⁼ ₊ ₋ ₌` look like SML symbols and would join the lookalikes.
  - The lookalikes list is seeded from UTS #39's confusables, as 18.0 has
    them, completed by hand, and frozen, so it cannot change with Unicode
    (X4, E5). What UTS #39 recommends for identifiers is left to the
    warnings (the owner, 2026-10-18, for the digits and at G2; *The
    architecture*). It holds 239 code points: 76 of the 85 identifier
    characters that look like punctuation, 116 of the 129 that look like
    the digits 2 to 9, the 21 decimal digits that look like 0 and 1, `·`,
    and the 26 lookalikes of `|`, such as `ǀ`, one of which is also a
    digit.
  - `lib/` keeps its exports ASCII, so every mode can use them (X11).
* **B. Plain XID,** as Rust does. It lets `val ㅤ = 1` through, which E9's
  prototype accepts, as well as `ʼa` and the other punctuation lookalikes.
* **C. UTS #39's identifier status Allowed as the rule.** It is the safest
  set, but its data changes between versions (X7), so a program could stop
  compiling when Rune's tables are updated.

### D11. Unicode symbols in identifiers

**Decided: A** (2026-10-18), as recommended.

* **A. No: symbolic identifiers stay ASCII.** **Recommended.**
  - Unicode symbols would join ASCII ones in one token, and several look
    like SML's own punctuation (X3).
  - HOL4 and Isabelle, the provers that use `∀` and `⇒`, keep them inside
    their quotations, not in ML.
* **B. Mathematical symbols** (General Category Sm, less the lookalikes)
  join the twenty ASCII symbols. Haskell does this with all symbols and
  punctuation.
* **C. A separate class** of Unicode operators that never joins ASCII
  symbols, so that `x≤y` is three tokens. It is more rules for the reader
  to learn.

### D12. NFC

**Decided: A** (2026-10-18), as recommended.

* **A. Require NFC.** An identifier with a non-ASCII character must already
  be in NFC, or the lexer gives an error with the NFC spelling, as C++23
  does. **Recommended.**
  - A name is always the bytes of its span. The sixteen places that take
    names from spans need no normalising (*Where we are*), and equal names
    are equal strings, which is what the brief asks for (line 28).
  - Editors write NFC almost always.
  - It costs the same as B. Both run the quick check on every non-ASCII name
    and the full algorithm on the few that need it (E4).
* **B. Normalise to NFC as the lexer reads,** as Rust and the brief (line 28)
  do.
  - A name and its span then differ. Every consumer that takes a name from
    the text must normalise too, or completion and the highlighter miss
    names.
* **C. NFKC,** as Python does. It also folds `ﬁ` to `fi`, `ℌ` to `H` and the
  fullwidth forms to ASCII. More text means the same, but a name in a
  message is not what the file says.

Under every option, **string literals are not normalised, nor is the whole
source** (line 29). NFC changes characters that are not combining marks
(X6). No language we know of normalises literals (E3).

### D13. Errors and warnings

**Decided: A** (2026-10-18), as recommended.

* **A. Errors come only from stable data:**
  - XID and NFC, which Unicode's stability policy covers;
  - the frozen sets of D10: the default-ignorables of 18.0, a property that
    is not stable, and the lookalikes;
  - the table of D5.

  UTS #39's checks are warnings that a program can turn off: identifier
  status, mixed scripts, confusable pairs within a program, and UTS #55's
  `*)` lookalike in a comment. **Recommended.** This is what rustc does
  (`uncommon_codepoints`, `mixed_script_confusables`, `confusable_idents`).
* **B. Everything an error.** Programs could stop compiling when the Unicode
  version changes: 79,024 code points left UTS #39's Allowed between 16.0 and
  17.0, and between 17.0 and 18.0 confusables gained 1,216 mappings, lost
  1,069 and changed 241 (E5).
* **C. No lints.** Homoglyph attacks are left to code review.

### D14. Printing non-ASCII

**Decided: A** (2026-10-18), as recommended.

* **A. Names as they are; `string` values as today; `WideString` values as
  UTF-8, with C0, C1, DEL, the bidi controls and the default-ignorables
  escaped. runedoc's anchors spell code points as `u3BB`.**
  **Recommended.**
  - A name cannot hold a control (D10).
  - A wide string value cannot drive the terminal (X9).
* **B. Everything above 126 escaped.** Safe, but `val λ = ...` would print
  as `\u03BB`.

### D15. Columns

**Decided: A** (2026-10-18), as recommended.

* **A. Byte columns in machine data; code-point columns in what a person
  reads; UTF-16 columns for the DAP,** as `--diagnostics-json` already gives
  rune-ide. Computed when shown. **Recommended.**
  - A code-point column is what rustc and Emacs count. Computing it only for
    a diagnostic costs nothing; computing it for the line table costs 4.1%
    of a compile (E10).
* **B. Code-point columns everywhere,** with a per-line flag to keep ASCII
  lines cheap. It changes the line table and the DAP for no reader.
* **C. Bytes everywhere,** as today. An editor and Rune then disagree about
  every column after a non-ASCII character.

### D16. The default

**Decided: A** (2026-10-18), as recommended.

The brief makes `--ascii` the default "for now" (line 16). The owner's flags
(2026-10-18) have no `--ascii`, so the ASCII mode is what a compile gets
when no flag asks for more.

* **A. ASCII with D4's comments, for the compiler and the REPL, from the
  milestones that bring its rules. The REPL takes `--unicode` as an option.**
  **Recommended.**
  - It is SML '97 read from UTF-8, with two deviations: D5's rules for
    comments, and D9's refusal of surrogates in escapes.
  - HOL4, MLton and the compiler pass (E1, E9).
  - It arrives in two steps, so that `make check` stays green.
    - M3 brings the refusals that hold in every mode. Rune's `bidi.sml` and
      `badbyte.sml` are rewritten then.
    - M4 brings the ASCII rule outside comments. The other three files of
      A3 are rewritten then.
  - G1, before M4, shows the owner the corpus results of M3 against the
    rule.
  - There is no `legacy` mode. A program that needs today's handling of raw
    bytes in an 8-bit literal writes escapes (D6).
* **B. `--unicode` as the default.** More programs compile, and the default
  is a deviation.
* **C. ASCII for files, `--unicode` for the REPL,** whose input comes from a
  terminal that speaks UTF-8. A line pasted from a file could then behave
  otherwise in the REPL, against D2's spirit.

### D17. The Unicode version

**Decided: A** (2026-10-18), as recommended.

* **A. One version for every table** (`lib/unicode`'s, now 18.0.0), upgraded
  in a milestone of its own, with the version in the unit cache's
  configuration so that a change recompiles. **Recommended.**
  - XID and NFC are stable across versions, so an upgrade makes valid
    identifiers only more numerous.
  - UTS #39 data is not stable, but it only gives warnings (D13).
* **B. Each table its own version.** A name could then be valid to the
  lexer and refused by the lints, or the reverse.

### D18. The symmetric text signatures

**Decided: A** (2026-10-18), as recommended.

The brief asks for "the most elegant fix possible", recorded as a change
request (line 5).

* **A. Generic signatures, with the types in the declarations.**
  `TEXT_STREAM_IO`, `TEXT_IO` and `STRING_CVT` stop fixing their character
  and string types. `TextIO`, `WideTextIO`, `StringCvt` and the new
  `WideStringCvt` say them with `where type`. `WideCharVector` gets `where
  type vector = WideString.string`, and the wide family is built in the 8-bit
  order (*Appendix C*, *The architecture*). **Recommended.**
  - It is the specification's own pattern, that of `MONO_VECTOR`, `PRIM_IO`
    and `STREAM_IO`. The synopsis line `WideTextIO :> TEXT_IO` becomes true
    as written. No new signature name is needed, and `MONO_VECTOR_EQ` goes.
  - E6 built it:
    - five compilers type-check it;
    - the Basis suite passes in every configuration it ran, with no shim and
      no deviation line;
    - the compiler's bytecode is unchanged.
  - The cost:
    - implementations of 8-bit text add `type substring` in two places;
    - a functor over `TEXT_IO` no longer knows that `vector` is `string`.
      E6 found no such functor outside implementations of the Basis.
* **B. A new `GEN_TEXT_IO`,** with `TEXT_IO` as its 8-bit instance, as
  `BIN_IO` is of `IMPERATIVE_IO`. `TEXT_IO` stays as it is for programs, but
  the synopsis line `WideTextIO :> TEXT_IO` stays false and needs its own
  correction.
* **C. `IO` inside `TEXT`** (`Text.IO`, `WideText.IO`). It still needs A's
  generic `TEXT_IO` to say what `IO` is, and it makes `TEXT` larger for every
  user.

For `STRING_CVT`, a signature over a pair of types beats a separate
`WIDE_STRING_CVT`: one signature with two implementations, and `radix` and
`realfmt` shared.

### D19. The representation of `WideString`

**Decided: A** (2026-10-18), as recommended.

* **A. As it is: a word per code point.** **Recommended.**
  - `sub` and slices stay constant time, and are already inlined by the JIT
    and the native code generator.
  - `WideCharArray` and xc2's shim are untouched.
  - The costs E8 measured are elsewhere. `^` goes through lists, about 11,000 times
    `String.^`'s cost. Reading a file goes one byte at a time, at 206
    instructions a byte. Literals are parsed at every evaluation. M8 and M4
    fix these as tasks.
* **B. Packed, four bytes a code point.** Half the memory. It needs a raw
  object kind and new primitives in the interpreter, the JIT and runeopt. A
  candidate for *Later*.
* **C. UTF-8,** as the brief's line 41 assumes.
  - It is compact for ASCII.
  - `sub` and slices become linear, arrays and vectors would convert on
    every copy, and MLton's library under xc2 becomes quadratic (W3).
* **D. PEP 393's 1, 2 or 4 bytes.** Compact and constant-time, but every
  primitive branches three ways, and one emoji widens a whole string (E8).

### D20. Overloading the string operations

**Decided: A** (2026-10-18), as recommended.

The brief asks for "the usual string operations (e.g. ^) symmetrically via
overloading" (line 8). The Definition's list of overloaded identifiers is
closed (Appendix E), so any answer but C is a deviation, to be pinned.

* **A. `^`, `size`, `concat` and `substring` overloaded over the string
  class, defaulting to `string`.** `str`, `implode` and `explode` wait, and
  `chr` and `print` are never overloaded. **Recommended.**
  - E7 built it for 0.18% more compile time, a three-line shim for xc1, and
    no change to the typing of any of 788 programs.
  - It comes after M8's primitive for `WideString.^`, without which an
    overloaded `^` is about eleven thousand times slower at the wide type.
* **B. A, plus `str`, `implode` and `explode`,** through a pair of linked
  class variables: days of elaborator work (E7). Pair them later if programs
  ask.
* **C. No overloading.** Programs write `WideString.^`, as today, and Rune
  makes no deviation. Literals are already overloaded, as the Definition
  allows.

## The milestones

Each milestone is one commit or a few, and each commit leaves `make check`
green. A milestone that touches the following has more gates:
- the compiler's sources: the host builds and `make check-cross`;
- `lib/basis`: `make matrix-quick` (rune and xc1), and xc2:mlton for the
  wide family;
- a library: `make test-lib-hosts`.

Every milestone of the source track also has, among its *Done when*, the
corpus run:
- Rune's tree, HOL4 after `unquote`, and MLton are lexed in every mode, with
  the counts of *The experiments*;
- a file that passed before passes still, or the change of the default says
  why not.

E9's scripts become `scripts/lex-corpus.sh` for this.

The sizes are lines of code and tests, not counting generated tables.

### M1. Fixes that follow the Definition or fix bugs (S, about 300)

* **What:**
  - `WideTextIO`'s decoder (`lib/basis/widetextio.sml:145-167`):
    - it refuses overlong forms, surrogates and lead bytes F5 to FF as
      `IO.Io` with cause `Fail "UTF-8"`;
    - past 0x10FFFF it raises that `Io` instead of `Chr`;
    - tests with the Kuhn and Table 3-8 cases of E4.
  - `Serve.parse` refuses a lone surrogate escape.
  - `Json.escape` escapes bytes that are not UTF-8 instead of raising
    `Domain`.
  - The lexer:
    - refuses DEL in a literal (the Definition's 33-126; D5's DEL row);
    - takes `\ddd` above 255 at the wide types (D8's option A, the
      Definition's reading);
    - names the character, not the byte, in "unexpected character
      U+03BB".
  - Reject tests in `tests/errors` for each lexer error that has none
    today: unexpected character, control character in a literal, invalid
    escapes.
  - Corrections:
    - `docs/unicode.md`: surrogates, `WideString.scan`, MLton's
      `WideChar`;
    - `docs/language.md:24-25,49`, which contradict each other.
* **Why now:** each is a bug, a wrong sentence, or a rule of the Definition
  that Rune does not keep. Two items carry out decisions: D5's DEL row and
  D8 A.
* **Done when:** the tests above pass on every configuration that runs them,
  and the documents agree with the code.
* **Done, the Basis part** (2026-10-18, at `362762f7`):
  - **The decoder** of `WideTextIO` (`lib/basis/widetextio.sml`) takes the
    well-formed sequences of the Unicode Standard's Table 3-7 and nothing
    else. Anything else raises `IO.Io` with the cause `Fail "UTF-8"`:
    - an overlong form, a surrogate, a value past 0x10FFFF;
    - a lead byte C0, C1 or F5 to FF, a continuation byte where a sequence
      begins;
    - a sequence cut short.

    The range of the second byte decides the first three, so no value past
    0x10FFFF reaches `WideChar.chr`, and `Chr` is gone.
  - **The encoder refuses a surrogate** with the same `Io` (function
    `output`), as D9 A has it ("the UTF-8 encoder and decoder of
    `WideTextIO`"). M1 named only the decoder. Without the encoder,
    `WideTextIO` would write files that it then refuses to read. A vector is
    encoded whole before any byte of it is written.
  - **Tests:** `tests/basis/widetextio_utf8.sml`, 197 checks, with the values
    made from numbers (xc1):
    - E4's 85 cases of Kuhn's test and of 3.9.6;
    - each byte that cannot begin a sequence;
    - each row of Table 3-7, its second byte at both ends of the range and
      just outside, and a later byte out of range;
    - the output of every well-formed case, and five surrogates written.

    The decoder from before fails 39 of them. A strict decoder stops at the
    first ill-formed sequence, so where a case strings several together
    (Kuhn 3.2 and 3.4, the tables of 3.9.6) only the first is tested; the
    rows of lead bytes and of Table 3-7 test each one alone.
  - **Documents:**
    - `docs/unicode.md`:
      - `WideChar` holds code points, surrogates included (D9);
      - `WideString.scan` reads `WideChar.char`, and `WideChar.scan` reads
        `Char.char`, as `CHAR` writes it;
      - MLton's `WideChar` is `Char32` by default, and `Char16` under
        `-default-type widechar16` (both checked on MLton 20241230).
    - The row `basis.widetextio` of `docs/language.md` and the note
      `WideTextIO/files-hold-utf-8` say what is refused.
  - **Not foreseen:**
    - The reader loses the characters that come before a bad sequence in
      the same chunk: `readVec` raises before it returns them. So `input1`
      on `a` followed by the byte FF raises, and does not give `a` first. It
      did so before M1 too. M8's decoder, which reads blocks, can give them
      first.
    - xc1:mlkit fails 175 checks (`intn_int64` 173,
      `@section/textio/instream-equality`, `@load/posix_sysdb`) under MLKit
      4.7.23. The labels are the same as those of E6's run on master
      `9b327248`, so the failures were there before M1. No deviation line
      was added.
    - This machine's `~/.local/rune-hosts/mlkit` is MLKit 4.7.23. The tree
      needs 4.7.25 (`scripts/fetch-hosts.sh`; `ffb51b95` dropped the
      work-arounds for 4.7.23), so `make check` stops at
      `bin/rune-mlkit.bin` on `src/driver/serve.sml`. The checks of M1 were
      run with `MLKIT=` and `MLKIT_LIB=` of the 4.7.25 beside it.
  - **Checks:** `make check` and `make matrix-quick` at the commit that
    records this, with MLKit 4.7.25 (logs `bas-m1-final` and
    `bas-m1-final-matrix` of the campaign).
* **Done, the source part** (2026-10-18, at `c6d588ad`):
  - **The lexer** (`src/frontend/lexer.sml`):
    - A raw control character in a literal, DEL included, is refused with
      its code point and its escape: "control character U+007F in string
      literal (write it as `\127`)".
    - `\ddd` is taken up to 999. Above 255 elaboration refuses it at `char`
      and `string`, by the check that `\u` had already (`checkLiteral`), so
      `#"\999"` is U+03E7 at `WideChar` and an error at `char`.
    - "unexpected character U+03BB" names the UTF-8 character, and its span
      covers the character's bytes. A byte that is not UTF-8 is "unexpected
      byte 0xE9 (invalid UTF-8)", and an ASCII control "unexpected character
      U+0001".
  - **Reject tests:** 18 in `tests/errors/err.lex_*`, one for each lexer
    error that had none: the unexpected character, byte and control, a
    control and DEL in a literal, every invalid escape, the gaps, the length
    of a character literal, a lone `.` and the long identifiers. Two more,
    `err.literal_ddd_char` and `err.literal_ddd_string`, refuse `\ddd` above
    255 at the 8-bit types. `tests/lang/lex.string_wide_ddd` takes it at the
    wide types, in expressions and in patterns.
  - **`Serve.parse`** refuses a `\u` escape of a lone surrogate, high or
    low: "not JSON: a lone surrogate in a `\u` escape" (-32700), and the
    service goes on. It encodes with `Utf8.encode`. The runner's `serve`
    test checks it.
  - **`Json.encode`** writes a byte that is not part of a string's UTF-8 as
    `\u00XX`, the character of its number, instead of raising `Domain`. The
    signature says so, with an example; `tests/lib/json/roundtrip.sml`
    checks bytes alone, a sequence that breaks off, a surrogate's bytes and
    an overlong form. The runner's `diagnostics/latin1-name` compiles a file
    named `caf\233.sml` with `--diagnostics-json` and reads its report back.
  - **`docs/language.md`:** the rows *Integer literals*, *Strings*,
    `lex.char` and `lex.string` now agree. A code point above 255, by any
    escape, is an error at the 8-bit types and taken at the wide ones.
  - **MLton's `regression/widechar.sml`** now lexes and compiles. It passes
    every test but test42, which wants `WideChar.fromCString` to read C's
    hexadecimal escape `\x67ab` as U+67AB. Rune's reads a `\x` escape up to
    255 only, as the note on `WideChar` says. Its line in
    `tests/external/mlton-skip.txt` now gives that reason (READING) instead
    of SCOPE. Whether `fromCString` should take more is the Basis track's
    question.
  - **The corpus run.** `scripts/lex-corpus.sh` comes in M3, so this used
    E9's acceptance check, with `--dump-tokens`:

    | Corpus | Files | Lexed before | Lexed now |
    |---|---|---|---|
    | Rune's tracked `.sml`, `.sig`, `.fun` (before this commit) | 2,152 | 2,149 | 2,149 |
    | HOL4 after `unquote` | 3,419 | 3,419 | 3,419 |
    | MLton | 1,787 | 1,784 | 1,785 |
    | The Latin-1 files of E1 | 17 | 16 | 16 |

    - The three of Rune's that are refused are `tests/diagnostics/eof.sml`,
      `err.unterminated_comment` and `err.unterminated_string`. The new
      lexer tests of `tests/errors` are refused, as they must be.
    - The file of MLton's that lexes now is `regression/widechar.sml`. The
      two files with `Error.: T` ("malformed long identifier") stay
      refused.
    - The Latin-1 file refused is MLKit's `test/cobol.sml`, with an
      unterminated comment.
    - No file that lexed before is refused.
  - **Not foreseen:**
    - `make check` failed once in `make/test-census` with "mv: cannot stat
      'build/gmp/selected.tmp'". Every make remakes `build/gmp/selected`,
      through the phony `gmp-force`, and the makes that the runner starts
      at once shared the one temporary file. The commit after this one
      gives each make a temporary file of its own.
    - MLKit 4.7.23, as the Basis part found: these checks too were run with
      `MLKIT=` and `MLKIT_LIB=` of 4.7.25.
  - **Checks:** `make check` and `make test-lib-hosts` at the commit that
    fixes the race, with MLKit 4.7.25 (logs `src-m1-final` and
    `src-m1-final-libhosts` of the campaign).

### M2. Source modes: the plumbing (M, about 500)

* **What:** D1 and D2, with no change to what any mode accepts.
  - `Source.file` gets a mode, `Ascii | Unicode of encoding` with `encoding =
    Utf8 | Latin1`. `Ascii` is the default (D16).
  - It is set:
    - by `--unicode` and `--unicode=utf8|latin1`, the owner's names, with the
      hint for `--unicode latin1` written with a space (D1);
    - by a build-file annotation (`ascii`, `unicode`, `unicode=latin1`);
    - by `Compiler.compile`'s parameters.
    
    The REPL's `use` and typed input take the REPL's own.
  - The unit cache's settings take the mode, and so do the unit files. The
    unit basis lexes again with a unit's own mode.
  - `lexerOf` takes the mode. Its about 25 callers pass the file's.
  - Every mode behaves as today, the default included; M3 and M4 give them
    their rules.
* **Why now:** every later milestone of the track needs a mode to read, and
  X2 must be closed before any mode refuses anything.
* **Done when:**
  - The bytecode is identical to before under every mode, on the bootstrap
    and on `tests/lang`.
  - A test caches a unit under one mode and finds it a miss under the other.
  - `docs/units.md` and the man page say where a mode comes from.
* **Done** (2026-10-18, at `54552075`):
  - **The mode** is a field of `Source.file`: `Ascii | Unicode of
    encoding`, with `encoding = Utf8 | Latin1`. Its names are those of the
    annotations: `ascii`, `unicode` (or `unicode=utf8`) and
    `unicode=latin1` (`Source.modeName`, `Source.modeNamed`).
    - `Source.load`, `readFile` and `fromStringAt` take a mode, and
      `fromStringIn` is `fromString` with one. `fromString` is left for the
      text the compiler makes for itself, which is read in the default.
    - `Lexer.lexerOf` and `Lexer.scan` take the mode, and `tokenize` uses
      the file's. As yet the lexer reads every mode alike.
  - **Where it comes from:**
    - `--unicode`, `--unicode=utf8` and `--unicode=latin1`, the last of
      them given. A value without `=` is an error, and `--unicode latin1`
      gives "cannot read latin1 (did you mean --unicode=latin1?)".
    - A build file's annotation, over the command line's. The last one in
      force wins.
    - `Compiler.compileIn : string -> {read, file, line} -> unit -> unit`,
      new, with the mode by the annotations' names. Another name raises
      `Fail`. `Compiler.compile` keeps its type and is `compileIn "ascii"`
      (*Not foreseen*, below).
    - `rune-repl --unicode[=ENC]` (and `rune -i`, which runs it), with `=`
      as `rune` wants it. It is the mode of the files the REPL uses, by
      `use`, `:reload` and its command line (`ReplSession.mode`). What is
      typed is read as UTF-8 under `--unicode`, whatever the encoding
      (`ReplSession.typedMode`): in the highlighter, completion, the
      engine's queries and the debugger too.
    - The Basis Library and the libraries are read in the default, in the
      compiler and in runedoc.
  - **The cache.**
    - A unit's key has its mode in its settings where the mode is not the
      default, so the keys of the default are those of before. The same
      holds for the REPL's units.
    - A unit's basis writes the mode after the hash of its source, where
      it is in no identity. Loading reads a functor's body again in that
      mode. `UnitBasis.version` is 5, and `docs/bytecode.md` shows the
      field.
  - **Tests:**
    - Scenario S63 of `tests/incremental` builds a file under `--unicode`,
      then without it, then under `--unicode=latin1`. Each is a miss, and
      `--unicode` again is a hit. A build file's `unicode` annotation is a
      hit under the command line's `--unicode`, and `ascii` is a miss.
    - `tests/repl/compilecache` compiles a part again by `compileIn` in
      another mode, and gets an entry more. `tests/repl/compile` compiles
      under `unicode=latin1`, and a mode of another name is refused.
    - `tests/lang/basis.compiler` and `tests/basis/compiler.sml` cover
      `compileIn`.
  - **The bytecode is the same.** The compiler before (`f322ed7e`), in the
    default, was compared with this one under no flag, `--unicode`,
    `--unicode=utf8` and `--unicode=latin1`. Both ran on the same VM and
    library.
    - All 290 programs of `tests/lang`, for both targets: the same bytes
      in every case.
    - The compiler compiled by itself: the same 2,146,487 bytes all five
      times.
  - **The corpus run** (E9's check with `--dump-tokens`, under each of the
    three modes). Each corpus refuses the same files in every mode:
    - Rune's tracked tree: 2,167 of 2,188 lex. The 21 refused are
      `tests/diagnostics/eof.sml` and the 20 lexer tests of `tests/errors`.
    - HOL4 after `unquote`: 3,419 of 3,419.
    - MLton: 1,785 of 1,787.
    - The Latin-1 files: 16 of 17.
  - **Documents:** a section *Source modes* in `docs/units.md`, with the
    cache key and the export basis. Also the annotations in
    `docs/build.md`, `--unicode` in the man page and in `docs/repl.md`,
    `Compiler.compileIn` in `docs/repl.md` and in the row
    `basis.compiler`, and the usage texts of `rune` and `rune-repl`.
  - **Not foreseen:**
    - **A deviation from D1's wording.** D1 and the flag table say the
      mode is "a field of `Compiler.compile`'s parameters". A field would
      change `compile`'s type, and every caller would then have to give a
      mode. HOL-rune's calls (`tools-rune/rune-polyml.ML`,
      `tools-rune/Holmake/CompilerSpecific.ML`) are outside Rune's trees
      and must not change. HOL4 needs no mode either: it reads in the
      ASCII default, with UTF-8 in comments. So, as the lead decided
      (2026-10-18), `compile` keeps `{read, file, line}` and reads in the
      default, and the mode comes by a function beside it, `compileIn`,
      which adds to the signature and changes nothing in it.
    - `docs/bytecode.md` gave a basis's version as 1, though it was 4.
    - `rune -i` exists: the wrapper runs `rune-repl` with what follows it.
      So the flag table's `rune -i --unicode` works as it stands.

### M3. What a source may hold raw (M, about 600)

* **What:** D4 and D5.
  - The lexer refuses, in every mode, the code points of the table in *The
    architecture*: comments checked byte by byte with a class table, and
    non-ASCII decoded where met.
  - A BOM at the start is dropped. CRLF counts as one line end in
    `Source.computeLineStarts`.
  - Accept and reject tests for each row and each mode: `tests/lang/lex.*`
    and `tests/errors/err.lex_*`, with `.cargs` for the mode. Among them
    are Trojan Source's three patterns with bidi controls, each refused:
    - an early return disguised as a comment;
    - code commented out;
    - a stretched string.
    
    Its invisible identifier and homoglyph function come in M6.
* **Why now:** the safety rules hold in every mode, so they come before the
  modes differ.
* **Done when:**
  - Rune's tree, HOL4 and MLton pass under each mode as E9 found.
  - Rune's two files with a bidi control or a bad byte (`tests/diagnostics/
    bidi.sml`, `badbyte.sml`) become reject tests of those rules. Their
    excerpts still show the character escaped, which is what they test.
  - `docs/language.md` has a row for each rule. The deviation of D5's rules
    for comments, where the Definition allows any character, is pinned by
    tests.
  - The cost of lexing the corpora is within 10% of today's (E9: 7 to 9%).

### M4. Literals by type and mode (S-M, about 400)

* **What:** D3, D6, D7 and D9's boundary at the lexer.
  - The default refuses non-ASCII outside comments. From here the ASCII mode
    is what a compile without a flag gets (D16).
  - The lexer keeps every literal as code points. Under `--unicode` it marks
    one that holds a raw character above 127.
  - Elaboration refuses that mark at `char` and `string`, with the
    literal's span and the escapes that would say it.
  - A surrogate in `\u` or `\U` is an error at every type, a deviation pinned by a
    test (D9).
  - `\U` is refused by default, with "needs `--unicode`" (D7, the owner's
    decision). `tests/lang/ty.overload.literal_wide.sml` and
    `ty.overload.literal_cached_limits.sml` take `--unicode` in their
    `.cargs`, and `docs/language.md`'s escapes row says when `\U` is allowed.
  - Under `--unicode`, raw text in a wide literal is its code points: U+00E9,
    no longer U+00C3 U+00A9.
  - Wide literals become constants. The compiler encodes them once, not
    through `fromString` at each evaluation (E8).
  - `--unicode=latin1` (D3):
    - conversion as the file is read;
    - the "looks like UTF-8" refusal;
    - tests on MLKit's Latin-1 regexp tests, which must mean what they mean
      today;
    - accept and reject tests of its own: raw Latin-1 at `string` and
      `WideString`, C1 bytes refused, and a UTF-8 file refused as "looks like
      UTF-8".
* **Why now:** the first visible difference between the default and
  `--unicode`.
* **Done when:**
  - Tests at the four types under the three modes, including the cases of X1.
  - Rune's three other files of A3 are rewritten:
    - `tests/diagnostics/wide.sml` and `emoji.sml` keep their characters in
      comments or wide literals under `--unicode`;
    - `examples/benchmarks/sat/upstream/original.sml` takes escapes.
  - The corpora run.
  - `docs/language.md`'s *Strings* row says it all.

**Gate G1**, between M3 and M4. With M3 built, the corpora, HOL-rune and
the examples are lexed under the ASCII rule as M4 will apply it. The owner
then confirms that the default becomes ASCII in M4 (D16).

### M5. `lib/unicode`: normalisation and identifier tables (M, about 1,500 with tests)

* **What:** E4's and E5's prototype made a library. The prototype is a
  patch of 4,774 lines, tables included:
  - `Normalize`: NFC, NFD, the quick check and `isNFC`.
  - `Identifier`: XID, Default_Ignorable, the frozen lookalikes, and UTS #39's
    status, scripts and skeletons for the lints.
  - The generator extended to the new UCD files, pinned by SHA-256.
  - `NormalizationTest.txt` in full, plus properties with
    `lib/test/property`.
  - The generated identifier tables checked against their sources: XID_Start
    and XID_Continue against `DerivedCoreProperties.txt`, the
    default-ignorables against it too, and the seeded lookalikes against
    `confusables.txt`, by a test that reads the files.
  - The 62 ill-formed cases of Kuhn's test and chapter 3's tables join
    `tests/lib/unicode/utf8.sml`, whose "Table 3-8" example is Unicode 6.0 to
    10.0's.
  - Every file `host yes`, tested on the hosts.
* **Why now:** it is independent of everything else, and can start on the
  first day. M6 needs it.
* **Done when:**
  - `make test-lib` and `make test-lib-hosts` pass on every host, MLKit and
    SML/NJ included. E4 found a flexible record that only those two refuse,
    and an existing test that runs out of memory on MLKit.
  - The tables' cost to the bootstrap budget is measured (E5: +2.2%), and
    the budget updated with the reason.
* **Done** (2026-10-18, at `99df9fc0`):
  - **`Normalize`** (`NORMALIZE`, `lib/unicode/normalize.sml`): `nfd`, `nfc`,
    `nfdList`, `nfcList`, `quickCheck`, `quickCheckList`, `isNFC`,
    `isNFCList` and `combiningClass`, as E4's prototype. NFKC is left out
    (E4). The tables take 20.9 KB of source, against E4's 73 KB:
    - numbers are written in base 32, a third of six hexadecimal digits;
    - the compositions are not written out but found through the
      decompositions, by an index in order of first and second.
  - **`Identifier`** (`IDENTIFIER`): `isXIDStart`, `isXIDContinue`,
    `isDefaultIgnorable`, the profile (`isStart`, `isContinue`,
    `isAlphanumeric`), and `exclusion`, which says why the profile leaves a
    code point out (`Ignorable`, or `Lookalike #"x"`, for M6's errors).
    - The profile is one table of two stages, as *The architecture* asks:
      blocks of 128 code points (220 distinct below U+3FC80), two bits a
      code point, 18 KB of hexadecimal digits that a lookup reads in place.
      No table is built at first use, and an ASCII name reads none.
    - The tables take 24.9 KB, against E5's 49 KB.
  - **The frozen sets** are written in `scripts/gen-unicode-tables.py`, not
    derived (D10):
    - the 269 default ignorables of XID_Continue, in 10 ranges;
    - 221 lookalikes: the 85 of SML's punctuation, the 116 of the digits 2
      to 9 that are not Recommended, and 20 by hand. Those are U+00B7 and the
      19 lookalikes of `|` that the code charts of Unicode 18.0 draw as a
      bare vertical stroke (no serif, foot, hook, loop or slant) and that
      UTS #39 does not recommend, by the owner's rule for the digits.
    - The generator checks the seeds against the data while it is
      18.0.0's, and shows what a later version's would change.
  - **`UnicodeSecurity`** (`UNICODE_SECURITY`) holds the lints' data. It is
    a structure of its own, not part of `Identifier` as *What* has it, so
    that a program can take the profile without them. It has:
    - `status` and `types` (Identifier_Status and Identifier_Type);
    - `scripts`, `resolvedScripts` and `isSingleScript` (augmented script
      sets, with 18.0's new Hntl);
    - `restriction`, the levels of UTS #39, section 5.2;
    - `skeleton` and `isConfusable`.

    Its tables take 76 KB: confusables 43 KB, types 18 KB, scripts 11 KB.
  - **Tests** (`tests/lib/unicode`, in `make test-lib`), with the data files
    they read committed beside them (5.7 MB):
    - `normalize.sml`: all of `NormalizationTest.txt`, over lists and UTF-8,
      and Part 1's rule over every scalar value;
    - `normalize_props.sml`: ten properties;
    - `identifier.sml`: every code point against
      `DerivedCoreProperties.txt`; the frozen sets against `confusables.txt`
      and `IdentifierType.txt`, through skeletons the test makes itself; the
      profile; nine names taken and fifteen refused;
    - `security.sml`: every code point against `IdentifierType.txt`,
      `IdentifierStatus.txt`, `Scripts.txt`, `ScriptExtensions.txt` and
      `confusables.txt`; the restriction levels of eighteen strings, among
      them UTS #39's Table 1a;
    - `utf8.sml`: the 62 ill-formed cases of Kuhn's test and of Tables 3-8 to
      3-11 of Unicode 18.0. Its old example is now named as Unicode 6.0 to
      10.0's.
  - **On the hosts:** all six programs of `unicode` pass on MLton, SML/NJ
    110.99.9 (64 and 32 bits), SML/NJ 2026.2, Poly/ML and MLKit. SML/NJ
    110.99.9 for 64 bits stops now and then in `normalize_props.sml`, with
    "bogus overflow fault" (4 runs of 45, none with address randomisation
    off): a `HOST-FLAKY` line, with a report in
    `docs/bugreport/smlnj/GC/bogus-overflow-fault`.
  - **MLKit's 7 GB** is MLKit's fault. It binds the region of a value made
    in a `let` around a tail call in its body, although
    `--preserve_tail_calls` is on. Every step of `utf8.sml`'s round trip
    then keeps a region and a frame, 4.3 KB, so the test takes 7.1 GB and
    fails where the machine cannot give that (E4's `ulimit -v 14000000`).
    It is reported in `docs/bugreport/mlkit/preserve-tail-calls`, with a
    `HOST-FLAKY` line, since the test passes where the memory is there.
  - **What a lookup costs** (`runevm --count`, instructions for a name of
    ten characters, with E5's in brackets):

    | Name | `isAlphanumeric` | and `isNFC` | `skeleton` | `restriction` |
    |---|---|---|---|---|
    | ASCII | 352 (352) | 494 (494) | 4,644 | 2,359 |
    | Latin, `Größenmaße` | 760 (1,071) | 1,220 (1,531) | 6,868 | 4,848 |
    | Greek | 1,596 (2,482) | 5,095 (5,981) | 10,443 | 5,629 |
    | Han | 2,174 (2,798) | 6,676 (7,300) | 13,179 | 7,317 |

    At first use the profile costs nothing (E5: 0.58M), the quick check 77K,
    the rest of NFC 0.45M (E4: 1.73M), the lints' types and scripts 1.0M,
    the confusables 1.4M. Decoding the profile into a string of one value a
    code point would save a tenth of a lookup, for 1.0M at first use: not
    taken.
  - **What the files would cost the compiler**, measured as E5 did: added
    to `rune.build` after `grapheme.sml` in a copy, with a use in the
    lexer's "unexpected character" error. *Errors* adds `Normalize` and
    `Identifier`, which the errors of D10 and D12 need; *lints* adds
    `UnicodeSecurity` too, for D13's warnings.

    | | Base | Errors | Lints |
    |---|---|---|---|
    | sources (@boot), bytes | 1,114,352 | 1,181,000 (+6.0%) | 1,269,803 (+14.0%) |
    | `bin/rune.rbc`, bytes | 2,138,776 | 2,198,415 (+2.8%) | 2,279,332 (+6.6%) |
    | `bin/rune.stack.rbc`, bytes | 1,368,498 | 1,418,167 (+3.6%) | 1,492,882 (+9.1%) |
    | bootstrap, register (budget 1,134.2M) | 1,030.7M | 1,047.6M (+1.64%) | 1,062.1M (+3.04%) |
    | bootstrap, stack (budget 1,688.7M) | 1,607.5M | 1,634.3M (+1.67%) | 1,657.6M (+3.12%) |
    | a compile of `hello.sml`, register | 1,965,058 instructions, 2.55 MB | +388, +36 KB | +412, +104 KB |
    | MLton build, peak memory | 2,604,716 KB | 2,623,604 KB (+0.7%) | 3,107,784 KB (+19.3%) |
    | MLton build, user time, two runs | 49.6 s, 50.7 s | 51.2 s, 47.5 s | 49.8 s, 51.8 s |
    | Poly/ML build, user time and peak memory | 7.2 s, 323 MB | 7.3 s, 325 MB | 6.5 s, 325 MB |
    | `rune-mlton.bin`, bytes | 9,427,592 | 9,529,032 | 9,665,320 |

    E5 measured +2.2% for 120 KB of tables. Both variants stay within the
    budgets. The budget is not changed here: the files join `rune.build` in
    M6, which updates it with the reason (the campaign's brief).
  - **G2's questions,** each with what the owner's rule for the digits (leave
    to the lints what UTS #39 recommends, refuse the rest) would do:
    - Of the 85 lookalikes of punctuation, 9 are Recommended letters and
      digits of living scripts: Hebrew yod U+05D9 (`'`), Katakana no U+30CE
      (`/`), Armenian feh U+0586 (`$`), the Arabic-Indic zeros U+0660 and
      U+06F0 (`.`), the visargas U+0903 and U+0A83 (`:`), and the CJK
      U+4E36 (`\`) and U+4E3F (`/`). Refusing yod and no makes most Hebrew
      names and many Japanese ones impossible. The rule would allow the 9
      and refuse the other 76, U+02BC and U+02BB among them (Inclusion, not
      Recommended). Built as decided: all 85 refused.
    - The rule covers 2 to 9, which UTS #39 maps to digits; it maps 0 and 1
      to the letters O and l. Of the decimal digits that look like 0, 13 are
      not Recommended, and of those that look like 1, 10, two of them among
      the bars (fullwidth, mathematical, outlined and segmented ones, and
      the digits of rare scripts). The rule would refuse the 13 and the 8;
      Kannada zero and the two Arabic-Indic ones stay allowed. Built as
      decided: allowed.
    - Seven lookalikes of `|` were left out as drawn otherwise: U+1050E (a
      short stroke), U+1D62D and U+1D661 (slanted), U+1FBF1 (a broken bar),
      U+2C92 (curled), and U+A7FE and U+217C (serifs in the charts, a bare
      stroke in some fonts). None is Recommended, so the rule would refuse
      all seven.

* **After G2** (2026-10-18, the commit after `7f8a37c6`): the frozen list as
  the owner decided (*The request*), 239 code points: 76 lookalikes of
  punctuation, 116 of the digits 2 to 9, 21 of 0 and 1, `·`, and 25 of `|`
  (U+1FBF1, the 26th, is with the digits as a 1).
  - `scripts/gen-unicode-tables.py` holds them as `SEEDED_PUNCTUATION`,
    `SEEDED_DIGITS`, `ZEROS_AND_ONES` and `BY_HAND`. It checks the seeds
    against 18.0's data, the digits' general category included.
  - `tests/lib/unicode/identifier.sml` counts each group, and takes Hebrew
    and Katakana names with yod and no.

**Gate G2.** The owner sees the cost of the tables to the compiler (E5, M5)
and the final identifier profile before M6. That includes the lookalikes list
as built: the owner settled its digits on 2026-10-18 (D10).

**Passed** (2026-10-18): the owner took M5's three recommendations on the
lookalikes, and the lints' data goes into the compiler (*The request*).

### M6. Unicode identifiers (M, about 800)

* **What:** D10 to D13.
  - `Ident` in `src/util`, used by the lexer and by the sixteen places that
    test identifier characters themselves (*Appendix A*).
  - Under `--unicode`, alphanumeric identifiers by the grammar of *The
    architecture*, required in NFC, through a property table built at first
    use.
  - The UTS #39 warnings, with a flag to turn them off. `UnicodeSecurity`
    joins the compiler for them (G2).
  - The confusable warning also compares a name's skeleton with Standard
    ML's punctuation and symbolic identifiers, so that a lone `ノ` (whose
    skeleton is `/`) or `٠` (`.`) warns: the lookalikes that UTS #39
    recommends stay allowed (G2).
  - Reject tests: each lookalike, each kind of invisible identifier, a
    decomposed spelling, and Trojan Source's invisible identifier.
  - Warning tests: a mixed-script name, a confusable pair, Trojan Source's
    homoglyph function, and a `*)` lookalike in a comment.
  - The cost of the real lexer measured as E9 measured the prototype's,
    with its `isNFC` on a Maybe and the lints.
* **Why now:** the brief's line 27, on the tables of M5. G2 passed on
  2026-10-18.
* **Done when:**
  - Programs with Greek, Cyrillic, CJK and Devanagari names compile, run, and
    print their names in the REPL and the debugger.
  - runedoc makes anchors for them.
  - The bootstrap stays within the budget M5 set, and an ASCII source
    decodes no table.

### M7. Showing source and names (S, about 300)

* **What:** D14 and D15.
  - `file:line:col` in code points.
  - The DAP's columns in UTF-16.
  - `keepLines` keeps the text of non-ASCII lines.
  - The REPL prints `WideString` values with controls and invisibles
    escaped.
  - Diagnostics escape file names.
  - The tests in `tests/diagnostics` move to code-point columns.
* **Why now:** last in the track, because only M6 lets a name hold a non-ASCII
  character.
* **Done when:**
  - `docs/diagnostics.md` says which unit each column counts.
  - rune-ide still points at the right character.

### M8. The wide family in the 8-bit order, and its costs (M, about 800)

* **What:** D18's first half, and D19's tasks.
  - The wide structures are sealed together, once, as one internal
    structure, and published as bindings to its parts, as `Word8Vector` is
    (E6):
    - `WideCharVector` is `MONO_VECTOR where type vector =
      WideString.string`;
    - `MONO_VECTOR_EQ` leaves the public library and its deviation goes;
    - inside the library it stays as `RUNE_MONO_VECTOR_EQ`, for
      `Word8Vector`.
  - Primitives for vector concatenation, tabulation and extraction, so that
    `WideString.^` and `concat` stop going through lists (E8: about 11,000 times
    slower than `String.^`).
  - A UTF-8 decoder in `WideTextIO` that reads blocks, not one byte at a time
    (E8: 206 instructions a byte).
  - The type printer qualifies a type name that is not the top level's, so
    that messages say `WideString.string` (E6).
  - The representation stays a word per code point (D19).
* **Why now:** the symmetric signatures of M9 rest on the order, and the
  overloaded `^` of M10 on the primitive.
* **Done when:**
  - `make matrix-quick` and xc2:mlton pass. E6 needed no shim.
  - `docs/basis-compat.md` loses its section on `MONO_VECTOR_EQ`, and
    `docs/unicode.md` its description of the old order.
  - E8's measurements are run again and the costs gone: `WideString.^` within
    a small factor of `String.^`, and `WideTextIO.inputAll` within a small
    factor of `TextIO.inputAll`.

* **Done** (2026-10-18, at `ad4e1a56`):
  - **The order.** E6's stage 2, the part of it that is M8's:
    - widechar.sml makes the character and the vectors, slices and arrays
      of it as they are before the seal (`RuneWideCharVector` and the
      others);
    - widestring.sml makes the strings and substrings on them, seals the
      family at once (`RuneWideText`), and binds the public structures to
      its parts;
    - `WideCharVector` is `MONO_VECTOR where type vector =
      WideString.string`, and `MONO_VECTOR_EQ` is `RUNE_MONO_VECTOR_EQ`,
      inside the library only, for `Word8Vector`;
    - `tests/basis/mono.widechar_sig.sml` checks the new constraint, and
      that the vectors admit equality.
  - **Four primitives** (`src/isa/prims.sml`, at the end):
    - `vector_concat`, `vector_concat_list` and `vector_extract` copy the
      fields of vectors in C. `Vector.concat`, `VectorSlice.vector`,
      `WideString.^`, `concat`, `extract` and `substring` and
      `WideSubstring.string` use them;
    - `utf8_decode` decodes UTF-8 in C, by Table 3-7, and says where it
      stopped and why.

    A reader in Standard ML alone could not come within a small factor of
    `TextIO.inputAll`, whose work is one read in C: the fourth primitive
    was not foreseen. A tabulation primitive was not needed:
    `WideCharVector.tabulate` costs 1.4 times `CharVector.tabulate`, and
    both go through a list.
  - **The reader** of `WideTextIO` decodes the blocks that `TextIO.input`
    gives. A sequence that the end of a block cuts short waits for the next
    block. The characters before a sequence that is not UTF-8 are given
    first, and the read after them raises; so does every later read. The
    chunk of a file's reader and writer is 4096 characters, where it was
    1024. `RuneStreamIOFn` gives a chunk that is read whole without copying
    it, which takes 8% of the instructions and a third of the allocation
    off `TextIO.inputAll` too.
  - **The type printer** names a type as the program's top level names it:
    `Types.qualifier`, set by `Elaborate.elabTop`, from
    `Env.qualifiedName`, the REPL's path finder moved into `Env`. Among
    paths of one length, a structure named for the type comes first
    (`WideString.string`, not `WideChar.string`). Unify's reasons use it
    too. Three messages of `tests/errors` changed for the better
    (`A.d vs B.d` where it said `d vs d`), and
    `err.ty_qualified-name` is new; `docs/diagnostics.md` says so.
  - **E8 again** (`results/M8`, `runevm-stack --count`):

    | What | Before | After | 8-bit |
    |---|---|---|---|
    | 1,000 times `acc ^ piece` | 170,287,835 | 15,833 | 15,555 |
    | `inputAll` of 10 MB of ASCII | 2,063,041,004 | 1,106,888 | 460,281 (499,301 before) |
    | `concat` of 100,000 pieces of 10 | | 1,202,983 | 1,202,706 |
    | 100,000 substrings of 100 | | 2,333,743 | 1,924,555 |
    | `tabulate` of 100,000 | | 3,102,740 | 2,202,559 |

    The wide side allocates about eight times what the 8-bit side does:
    a word per code point (D19). Wide literals are still parsed at each
    evaluation; that is M4's.
  - **Documents:** `docs/basis-compat.md` says what Rune does now about the
    erratum, `docs/unicode.md` describes the new order, and the rows
    `basis.widechar`, `basis.widestring`, `basis.mono.widechar` and
    `basis.widetextio` of `docs/language.md` say it too; `docs/bytecode.md`
    lists the primitives.
  - **G3's data:** what xc1 needed is the four primitives on the hosts in
    `tests/basis/host/rune-prim.sml`, written from their descriptions, as
    every primitive is. Nothing else: no shim, no line of
    `deviations.txt`. xc2:mlton needed nothing.
  - **Checks,** with MLKit 4.7.25: `make check`, `make matrix-quick` and
    xc2:mlton on the commit that recorded this before the rebase on M5's
    lookalikes (logs `bas-m8-final`, `bas-m8-final-matrix` and
    `bas-m8-final-xc2` of the campaign), and `make check` again after it
    (`bas-m8-rebased`), since the lookalikes touch nothing the others test.
    Before the rebase on M1's source part and M5, the same three passed on
    `838cb2ae`. The only failure was one of xc1:smlnj-legacy,
    `Real.fromLargeInt/maxFinite`, under the matrix's load: SML/NJ
    110.99.9's floats, as the `HOST-FLAKY` lines for its `Real` laws say.
    It passed in three runs alone.

**Gate G3.** E6 found nothing for xc1 or xc2 to need. If M8 does, the owner
sees the list before M9. Passed on 2026-10-18: xc1 needed only the hosts'
versions of the new primitives, which every new primitive needs, and xc2
nothing.

### M9. The symmetric text signatures, and the change request (M, about 800)

* **What:** D18's second half, as E6 built it.
  - `TEXT_STREAM_IO`, `TEXT_IO` and `STRING_CVT` made generic, with
    `TextIO`'s and `StringCvt`'s `where type`s giving back the
    specification's types.
  - `WideTextIO` sealed with `TEXT_IO`, and `WideStringCvt` added.
  - The deviations `TEXT_STREAM_IO/generic`, `TEXT_IO/generic`,
    `STRING_CVT/generic` and `WideStringCvt/not-in-the-specification`, each
    pinned. `TEXT_IO/WideTextIO-not-matched` goes.
  - The change-request transcriptions in `tests/basis/spec-sigs/scr/`, taken
    by `scripts/gen-basis-sigs.sh` and `tests/basis/check-claims.sh`.
  - The tests:
    - `TextIO` and `WideTextIO` through one functor;
    - every member of `WideTextIO`, which runedoc asks for once it claims
      `TEXT_IO`;
    - `WideStringCvt`.
  - Three lines of `tests/basis/law-skips.txt`:
    - the `skipWS` law at `WideStringCvt`, which is written with
      `Char.isSpace` and must be restated for both widths;
    - every law of `IMPERATIVE_IO` and `STREAM_IO` at `WideTextIO`, until an
      arbitrary for its streams exists.
  - `docs/unicode.md` gets the change request of *Appendix C*.
* **Why now:** the brief's lines 2 to 7.
* **Done when:**
  - `make test-basis`, `make test-laws`, `make check-docs`, `make
    matrix-quick` and xc2:mlton pass, as they did for E6.
  - The bootstrap's bytecode is unchanged but for its line table.
  - The change request names every signature and declaration it changes.
* **Done** (2026-10-18, at `81178771`):
  - **E6's stage 2, the rest of it,** applied as E6 left it, with no change
    of substance:
    - `TEXT_STREAM_IO`, `TEXT_IO` and `STRING_CVT` are generic;
    - `TextIO` and `StringCvt` are sealed with the `where type`s that give
      back the specification's types;
    - `WideTextIO` is sealed with `TEXT_IO`, and `WideStringCvt` is new;
    - the four deviations are pinned, and
      `TEXT_IO/WideTextIO-not-matched` is gone;
    - `tests/basis/spec-sigs/scr/` holds the change request's
      transcriptions;
    - the tests and the three lines of `law-skips.txt` are E6's.
  - **`docs/unicode.md`** describes what Rune does now, and has the change
    request of *Appendix C* as its own section. The rows `basis.textio`,
    `basis.stringcvt`, `basis.widestringcvt` (new) and `basis.widetextio`
    of `docs/language.md` say so too.
  - **Not foreseen: the laws of `STRING_CVT` at `WideStringCvt`.**
    - `takel` and `dropl` drew their reader as a random function from `int`
      to `(WideChar.char * int) option`. A stream of such a reader need not
      end, and the watchdog stopped cases after 60 s: 270 s for the
      program, and a law stopped outright on an unlucky seed.
    - `WideTextArb.reader` (`lib/test/property/basis`) is now a reader
      over a drawn wide string, as `BasisDataArb.reader` is over a string,
      and runedoc draws it for a reader of wide characters. The test is a
      law of `tests/doc/laws.lib`.
    - The program takes seconds now. `make test-laws` passes 230 of 230.
  - **The bootstrap:** the compiler compiled against M8's library and
    against M9's, from paths of one shape, is 7 bytes longer with M9's.
    `--dump-code` differs only in the positions of its comments, which is
    the line table.
  - **Checks,** with MLKit 4.7.25 (logs `bas-m9`, `bas-m9-matrix` and
    `bas-m9-xc2` of the campaign): `make check`, which runs `test-basis`,
    `test-laws` and `check-docs`; `make matrix-quick`; and xc2:mlton, all
    passing before the rebase on M2. After it, `make check` and
    `make matrix-quick` again, on M10's last commit (`bas-m10-rebased`,
    `bas-m10-rebased-matrix`).

### M10. String operations at both widths (S, about 300)

* **What:** D20's recommendation, as E7 built it.
  - `^`, `size`, `concat` and `substring` overloaded over the string class,
    as builtins defaulting to `string`.
  - The three-line shim that leaves the hosts' own operations standing under
    xc1.
  - Tests in `tests/lang`, which only Rune runs. `tests/basis` keeps writing
    `WideString.^`, because the hosts' overloading is closed.
  - The deviation from Appendix E, pinned.
* **Why now:** the brief's line 8. It waits for M8's primitive, without which
  `^` at the wide type is slow.
* **Done when:**
  - Every program of `tests/lang` and `examples` compiles as before (E7:
    788 of 788).
  - The compiler reaches a fixed point.
  - The Basis suite passes in every configuration.

**Gate G4**, the owner accepting overloading as a deviation from Appendix E,
was passed on 2026-10-18 with D20.

### M11. The corpora and the comparison (S, about 200 and documents)

* **What:**
  - HOL-rune is built under the default, and MLton's sources are compiled
    under it.
  - The comparison of the brief's line 23 is completed in
    `docs/unicode.md`, one column per mode, as *Appendix B* sketches.
* **Why now:** it closes both tracks.
* **Done when:**
  - HOL-rune builds.
  - `docs/unicode.md` has the comparison, the change request and the modes.
  - `docs/language.md`'s deviations are pinned.

### Later

- Unicode classes and case mappings for `WideChar` (`isAlpha`, `toUpper`),
  with tables of the Basis's own. Today they are ASCII's.
- Unicode symbols in identifiers, if a client asks (D11).
- A packed `WideString`, four bytes a code point, if memory ever matters
  (D19, E8).
- `str`, `implode` and `explode` overloaded through linked class variables
  (D20, E7).
- An arbitrary for `WideTextIO`'s streams, so that the `IMPERATIVE_IO` and
  `STREAM_IO` laws M9 skips run at the wide width.
- `\x`, if Successor ML adopts it (D7).
- Windows paths and arguments in UTF-16 (`CreateFileW`, `GetCommandLineW`),
  or a UTF-8 manifest (*Where we are*).

### Why this order

- **M1** fixes what is wrong whatever is decided.
- **M2** before any rule, so that no rule can be bypassed by the cache (X2).
- **M3** before M4, because its safety rules hold in every mode.
- **G1** before M4, because M4 makes the ASCII rule the default.
- **M4** gives the modes their first difference.
- **M5** can go first. It is a library with its own tests, and M6 needs it.
- **M6** after G2, which shows its cost and its profile.
- **M7** after M6, which brings the first non-ASCII names.
- **M8** before M9, because the signatures rest on the order; it also fixes
  the costs of wide text that E8 measured.
- **M10** after M8's primitive for `^`.
- **M11** closes both tracks.

## Prerequisites and flags

| Flag or annotation | Milestone | Meaning |
|---|---|---|
| no flag | M2, M3, M4 | the ASCII mode, the default (D16) |
| `--unicode`, `--unicode=utf8` | M2 | a UTF-8 file, Unicode outside comments |
| `--unicode=latin1` | M2, M4 (D3) | a Latin-1 file, converted as it is read; a raw character is its code point |
| a mode on a unit's line in a build file: `ascii`, `unicode`, `unicode=latin1` | M2 | the unit's mode, over the command line's |
| `Compiler.compile`'s `mode` | M2 | the mode of what it compiles |
| `rune -i --unicode` | M2 | the REPL's mode for typed input and `use`; typed input is always UTF-8, so `=latin1` applies only to files it `use`s |
| `--no-unicode-lints` (name to be settled) | M6 | turns off D13's warnings |

No new tool is needed. The UCD files come from unicode.org through the
existing generator. The hosts are those of `make hosts`.

## Relation to the other plans

- **`docs/plans/sml97-extensions.md`** (branch `sml97-extensions`) tabulates
  "Successor ML: text beyond ASCII":
  - what each system does with `"é"` and `\U`;
  - issues #29 (non-ASCII text in literals) and #33 (Unicode letters,
    symbols and digits in identifiers).
  
  This roadmap is Rune's answer to both issues. It admits Unicode letters
  (D10) but not symbols (D11), and it keeps raw non-ASCII text out of 8-bit
  literals (D6).
- **The specification** (`docs/plans/specification.md`, branch `runespec`)
  must state the lexical rules of M3, M4 and M6. Its parser milestone checks
  against Rune's lexical tests, which M3 adds to.
- **`docs/plans/repl.md`** made `lib/unicode` (its D9). This roadmap adds two
  structures to it, and M7 changes what the REPL prints.
- **`docs/plans/incremental-compilation.md`** and **`docs/units.md`:** M2
  puts the mode into a unit's settings and its file. Any later change to how
  units are keyed must keep it.
- **`docs/plans/performance.md`:** the lexer is 5.2% of a compile of the
  compiler (E9). M3 and M6 must stay within the bootstrap budget, or update
  it with the reason.
- **`docs/plans/unit-testing.md`:** the new tests run as `tests/lang` and
  `tests/errors` do, and the corpus run joins the runner's nightly tier.

## Risks

- **A rule refuses a program that used to compile.** The modes do refuse
  some, by design.
  - The corpora of E1 and E9 are the guard: every source milestone runs them.
  - G1 settles the default with the results in hand.
  - The five files of Rune's tree are known, and M11 rewrites them.
- **The cache serves a unit compiled under another mode.** M2 puts the mode
  in the key before any mode refuses anything, with a test.
- **Tables slow the compiler down.** They are decoded at first use, and
  ASCII sources never decode them. Still, they cost 2.2% of the bootstrap
  and 108 KB of allocation per compile (E5), and the modes about 0.5% (E9).
  M5 and M6 measure them against the bootstrap budget, and G2 shows the
  result.
- **The lookalikes list is incomplete.** It is the part of D10 most likely
  to be wrong. It is seeded from confusables.txt (E5) and frozen, and the
  UTS #39 lints catch what it misses as warnings.
- **The symmetric signatures break the hosts' configurations.** E6 ran them.
  G3 stops the track if M8 needs more than E6 found.
- **The change request is not taken up.** Rune's library then keeps a
  documented deviation, as it does today with `MONO_VECTOR_EQ`. That
  deviation is the smaller of the two, and is pinned.
- **Requiring NFC (D12) refuses text an editor wrote decomposed.** The error
  gives the NFC spelling. macOS file names are NFD, but file contents are
  rarely so.

## Testing the modes

- **Accept and reject, per mode.** Each row of the table of *What a source
  may hold raw* has a test in `tests/lang` (accepted) or `tests/errors`
  (refused), with `.cargs` naming the mode. Every accept test of the default
  also runs under `--unicode` with the same output (D2).
- **Literals.**
  - A matrix: the four types × raw, `\ddd`, `\u` and `\U` × the three
    modes × in range, out of range and surrogate.
  - `\U` refused by default and taken under `--unicode`.
  - `--unicode=latin1`: raw Latin-1 at both widths, C1 bytes refused, a UTF-8 file
    refused as "looks like UTF-8", and MLKit's Latin-1 tests.
  - Wide literals checked by their code points, not their printing.
- **Identifiers.**
  - One test per lookalike, per kind of invisible character, and per
    script of M6.
  - A decomposed spelling refused with the NFC spelling in the message.
  - The UTS #39 warnings on, and off.
- **Trojan Source.** Boucher and Anderson's patterns:
  - early returns, commenting out and stretched strings refused (M3);
  - the invisible identifier refused, and the homoglyph function warned of
    (M6).
- **The library.**
  - `NormalizationTest.txt` in full.
  - Properties: idempotence, NFC∘NFD = NFC, `isNFC (nfc s)`, and the round
    trip with `Utf8`.
  - The Kuhn and Table 3-8 cases for `Utf8` and `WideTextIO`.
  - On Rune and on the hosts.
- **The corpora.** Rune's tree, HOL4 after `unquote`, and MLton, lexed in
  every mode by `scripts/lex-corpus.sh`, against a recorded expectation:
  which files each mode refuses, and the instructions to lex them.
- **The Basis.**
  - Every configuration of the suite (rune, xc1, xc2:mlton, native) after M8
    and M9.
  - The spec-sigs tests and `check-notes`/`check-claims` for the new
    deviations.
- **Every milestone of the source track** runs the corpus run, `make check`
  and the host builds.

## References

### Standard ML

- Robin Milner, Mads Tofte, Robert Harper and David MacQueen. *The Definition
  of Standard ML (Revised)*. MIT Press, 1997. Section 2 (lexical
  conventions) and Appendix E (overloading).
- Emden Gansner and John Reppy, eds. *The Standard ML Basis Library*.
  Cambridge University Press, 2004; https://smlfamily.github.io/Basis/:
  `char.html`, `string.html`, `text.html`, `text-io.html`,
  `text-stream-io.html`, `mono-vector.html`, `string-cvt.html`.
- Successor ML issues #29, "Relax string literal rules", and #33, "Unicode in
  SML text": https://github.com/SMLFamily/Successor-ML/issues/29, /33.
- MLton, "Successor ML: extended text constants":
  http://mlton.org/SuccessorML#ExtendedTextConsts; its lexer,
  `mlton/front-end/ml.lex` (20241230).
- SML/NJ's lexer, `base/compiler/Parse/lex/ml.lex` (110.99.9 and 2026.2).

### Unicode

- *The Unicode Standard*, version 18.0.0. Chapter 3 (Tables 3-7 to 3-11:
  well-formed UTF-8 and the ill-formed cases), and §23.8.1 on the BOM in
  UTF-8.
- UAX #31, *Unicode Identifiers and Syntax*, revision 45 (18.0.0):
  https://www.unicode.org/reports/tr31/tr31-45.html. Also revisions 37 and
  39 for the change of 15.1.
- UAX #15, *Unicode Normalization Forms*, revision 58:
  https://www.unicode.org/reports/tr15/.
- UTS #39, *Unicode Security Mechanisms*, revision 34 (18.0.0):
  https://www.unicode.org/reports/tr39/tr39-34.html.
- UTS #55, *Unicode Source Code Handling*, version 2, revision 5:
  https://www.unicode.org/reports/tr55/tr55-5.html.
- UAX #44, *Unicode Character Database*, revision 32, §7 (the 15.1 change
  to Other_ID_Continue).
- *Unicode Character Encoding Stability Policies*:
  https://www.unicode.org/policies/stability_policy.html.
- The Unicode Character Database 18.0.0: `UnicodeData.txt`,
  `DerivedCoreProperties.txt`, `PropList.txt`, `DerivedNormalizationProps.txt`,
  `CompositionExclusions.txt`, `NormalizationTest.txt`; and the security data
  `confusables.txt`, `IdentifierStatus.txt`, `IdentifierType.txt`:
  https://www.unicode.org/Public/18.0.0/.
- Markus Kuhn, *UTF-8 decoder capability and stress test*:
  https://www.cl.cam.ac.uk/~mgk25/ucs/examples/UTF-8-test.txt.

### Security

- Nicholas Boucher and Ross Anderson. "Trojan Source: Invisible
  Vulnerabilities". 32nd USENIX Security Symposium, 2023;
  https://arxiv.org/abs/2111.00169; https://trojansource.codes/.
- CVE-2021-42574 (bidirectional reordering) and CVE-2021-42694 (homoglyphs).

### Other languages

- **Rust Reference.** "Input format", "Identifiers", "Tokens":
  https://doc.rust-lang.org/reference/. And the rustc lints
  `text_direction_codepoint_in_literal`,
  `text_direction_codepoint_in_comment`, `confusable_idents`,
  `mixed_script_confusables` and `uncommon_codepoints`:
  https://doc.rust-lang.org/rustc/lints/listing/.
- **C23** (draft N3096), §6.4.2.1 and Annex D. **C++23** (draft N4950),
  [lex.phases] and [lex.name]. The papers: P1949R7, "C++ Identifier Syntax
  using Unicode Standard Annex 31"; P2295R6, "Support for UTF-8 as a portable
  source file encoding"; N2836, "Identifier Syntax using Unicode Standard
  Annex 31".
- **C# language specification**, "Lexical structure":
  https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/language-specification/lexical-structure.
- **Python**, "Lexical analysis", and PEP 3131:
  https://docs.python.org/3/reference/lexical_analysis.html.
- **Zig** 0.15.1 and 0.17.0, "Source Encoding":
  https://ziglang.org/documentation/.
- **Elixir**, "Unicode Syntax": https://hexdocs.pm/elixir/unicode-syntax.html.
- **OCaml** 5.4 manual, "Lexical conventions":
  https://ocaml.org/manual/5.4/lex.html.
- **Haskell 2010 Report**, chapter 2:
  https://www.haskell.org/onlinereport/haskell2010/haskellch2.html.
- **Swift**, "Lexical Structure":
  https://docs.swift.org/swift-book/documentation/the-swift-programming-language/lexicalstructure/.
- **Go**, "The Go Programming Language Specification": https://go.dev/ref/spec.
- **Java Language Specification**, SE 25, chapter 3.
- **Scala** 2.13 specification, chapter 1.
- **Julia** manual, "Variables".
- **PEP 393**, "Flexible String Representation" (for D19).
- jamesgober, *unicode-lang*: https://github.com/jamesgober/unicode-lang
  (the brief's first link).

## Appendix A: what consumes source text, positions and names

Master at `9b327248`. Each line is a place that a source mode, a column or a
Unicode name must reach (E10).

### Reading source

| Where | How it reads | Notes |
|---|---|---|
| `src/util/source.sml:44-54` `readFile` | `TextIO.inputAll`, one string | `overlays` (Serve's editor buffers) come first |
| `src/driver/main.sml:47-53,475-478` | `Source.load` | the inputs; the unit cache's text |
| `src/driver/main.sml:137` | `Source.readFile` | `readMid` |
| `src/driver/main.sml:231-232` | `readText` (build files) | |
| `src/repl/repl.sml:543` | `TextIO.inputLine stdIn`, basic mode | `ReplScan` one char at a time (`src/repl/scan.sml:37-69`) |
| `src/repl/front.sml:305` | `LineEdit.readLine` | UTF-8 aware (`lib/terminal/line_edit_fn.sml`) |
| `src/repl/repl.sml:254,348` | `use`, `:reload` | `Source.readFile` |
| `lib/basis/compiler.sml:13` | `read : unit -> char option` | HOL-rune compiles through this |
| `src/driver/serve.sml:40-67` | JSON `\u` decoded to UTF-8 | encodes lone surrogates (bug) |
| `src/doc/docsource.sml:14` and `docelab`, `dochead`, `docresolve` | `Source.load`/`fromString` | runedoc |
| `src/driver/unitbasis.sml:1333-1342` | re-reads and **re-lexes** a unit's source to rebuild functor bodies | needs the unit's own mode |
| `src/repl/debug.sml:136-160` | registered text or `TextIO.inputLine` | debugger source lines |

### Byte positions

`Source.pos` is a byte offset (`source.sml:4`). Columns are byte columns
(`lineCol`, `source.sml:57-69`; `docs/diagnostics.md:18`).

| Consumer | Where | Unit |
|---|---|---|
| `file:line:col` | `Source.describe`, `error.sml:11-12` | bytes |
| excerpt and carets | `diagnostic.sml:79-122` | display width of graphemes; escapes controls, bidi and bad bytes |
| `--diagnostics-json` | `diagnostic.sml:170-201` (`point`) | UTF-16 columns, plus `startByte`/`endByte` |
| `--serve` | `serve.sml:17,147-155,160-219` | bytes ("Offsets are bytes of the text") |
| engine protocol | `docs/repl-protocol.md:40`; `src/repl/engine.sml:182-191` | bytes |
| Jupyter kernel | `src/kernel/kernel.sml:179-192,297-316` | code points to bytes and back |
| rune-ide | `rune-ide/src/sml/utf8.sml:33-38`, `documents.sml:64` | UTF-16 to bytes |
| bytecode line table | `src/backend/code.sml:124-126`, `src/backend/stack.sml:205-209`, `src/backend/regs.sml:173-177` via `Source.lineColOf` | byte columns, written to `.rbc`/`.rbu` |
| DAP | `src/dap/translate.sml:56` | byte columns, passed through |
| native DWARF | `src/opt/x64.sml:318-324` `.loc` | byte columns |
| unit Mid pickle | `unitmid.sml:91,233-239`; `midtext.sml:216-221` | byte offsets |
| unit basis | `unitbasis.sml:741-761,1161,1335-1349` | functors keyed by byte offset |
| unit cache key | `unitcache.sml:140-142` | hash of the raw bytes |
| runedoc | `docsource.sml:24,27-28,157`; `doccomments.sml:40,73-77` (scans backwards) | bytes |
| highlighter and completion | `highlight.sml:171-207,250-302`; `complete.sml:88-135` | bytes, backward scans |
| `Compiler.compile` | `lib/basis/compiler.sml:13`; errors printed by `src/repl/repl.sml:284-287` | a start line in; errors out as `file:line:col`, byte column |

Every one indexes the UTF-8 text by byte span. None needs code-point
offsets. Only a displayed column might.

### The identifier class, written again

| Where | What |
|---|---|
| `src/frontend/lexer.sml:14-15` | `isIdentStart = Char.isAlpha`, `isIdentChar` |
| `src/frontend/lexer.sml:356,365` | `classOf` (REPL colouring) |
| `src/repl/show.sml:337` | when to print `op`/parens: `val λ` would print as `(op λ)` |
| `src/doc/docanchor.sml:27-31` | anchors: `λ` would become `op-x206-x187` |
| `src/repl/debug.sml:267-268` | `nameable`: which variables a frame prints |
| `src/repl/complete.sml:22-24,113-135` | `isNameChar`, `back` |
| `src/repl/scan.sml:34` | `isWordChar` |
| `src/kernel/kernel.sml:309-310` | `isNameChar` |
| `src/repl/commands.sml:280` | the REPL's commands |
| `src/doc/docresolve.sml:216`, `doclaws.sml:69` and `118-144`, `docclaims.sml:36`, `docannot.sml:170`, `doctests.sml:58-61`, `docpage.sml:509`, `docsite.sml:786` | runedoc: eight places |

Sixteen places in all, besides the lexer's own `isIdentStart` and
`isIdentChar`.

Names are plain `string`s with no interning: `StringMap` (`ordmap.sml:201`)
and `Env` (`env.sml:20`). Equality is byte equality. That stays correct
under NFC only if every name reaching an environment comes through the
lexer, normalised or checked. The REPL tools that re-derive names from raw
spans must do the same.

### Other places that touch text

- `Json.escape` raises `Domain` on invalid UTF-8 (`lib/json/json.sml:181-182`).
  `--diagnostics-json` with a Latin-1 file name or message therefore crashes.
- `Diagnostic.firstLine` prints file names unescaped (`diagnostic.sml:22`).
- `show.sml:62` prints strings with `String.toString`, so non-ASCII prints as
  `\ddd`.
- On Windows, paths go through `CreateFileA` (`runtime/sys/sys_win.c:487,849,1380`)
  and argv is in the ANSI code page. There is no UTF-8 `activeCodePage`
  manifest. Console input is converted from UTF-16 (`runtime/sys/sys_win.c:3499`).
- `source.sml:26` splits lines on LF only, so bare CR gives wrong line
  numbers.
- `repl.sml:137`: "wait for more input" is decided by the lexer's error text.
- About 25 call sites of `Lexer.tokenize`/`scan` (repl, debug, doc*,
  unitbasis, main).

## Appendix B: Rune, the specifications and the other systems

The comparison the brief asks for (line 23), as M11 puts it in
`docs/unicode.md`. The Rune columns after this roadmap assume every
recommendation is taken.
- "Def." is the Definition and the Basis specification.
- "today" is Rune at `9b327248`.
- "+ext" is MLton with `allowExtendedTextConsts`.

| | Def. | Rune today | default | `--unicode=latin1` | `--unicode` | MLton | +ext | SML/NJ | Poly/ML | MLKit | Moscow ML | HaMLet |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| encoding of the file | none | bytes (Latin-1 in literals) | UTF-8 | Latin-1 | UTF-8 | bytes | bytes, UTF-8 shapes in literals | bytes | bytes | bytes | bytes | bytes |
| invalid UTF-8 refused | - | no | yes | - | yes | in literals (all non-ASCII) | in literals | no | in literals (all non-ASCII) | no | no | no |
| non-ASCII in comments | any | any byte | UTF-8 | Latin-1 but C1 controls | UTF-8 | any | any | any | any | any | any | any |
| raw non-ASCII at `string` | no | bytes | no | its byte | no | no | bytes | bytes | no | bytes | bytes | no / cut |
| raw non-ASCII at `WideString` | (no) | a code point per byte | no | code point | code point | no | a code point per byte | - | - | - | - | - |
| raw TAB in a literal | no | no | no | no | no | no | no | no | no | spaces | no | no |
| raw DEL in a literal | no | yes | no | no | no | no | no | yes | no | yes | no | no |
| VT between tokens | allowed | yes | no | no | no | yes | yes | no | yes | no | no | yes |
| FF between tokens | required | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes |
| bare CR | allowed | yes, lines miscounted | no | no | no | yes | yes | yes | yes | yes | yes | yes |
| BOM at the start | - | error | dropped | refused ("looks like UTF-8") | dropped | error | error | error | error | error | error | error |
| bidi controls (the nine) raw | literals no, comments yes | yes | no | no | no | comments only | yes | yes | comments only | yes | yes | comments, literals cut |
| non-ASCII identifiers | ("letters") | no | no | XID profile | XID profile | no | no | no | no | no | no | no |
| identifiers in NFC | - | - | - | required | required | - | - | - | - | - | - | - |
| Unicode symbols in identifiers | no | no | no | no | no | no | no | no | no | no | no | no |
| `\uXXXX` | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes | yes |
| `\U` | no | yes | no (needs `--unicode`) | yes | yes | needs ext | yes | no | no | no | no | no |
| `\x` | no | no | no | no | no | no | no | no | no | no | no | no |
| `\ddd` above 255 at the wide types | yes | no | yes | yes | yes | yes | yes | - | - | - | - | - |
| surrogates in `\u` | in the range | allowed | refused | refused | refused | not probed | not probed | - | - | - | - | - |
| wide types | optional | all | all | all | all | `WideChar` to `WideText` | same | no | no | no | no | no |
| `WideTextIO` | optional, unmatchable | unsealed | sealed with the generic `TEXT_IO` | same | same | no | no | no | no | no | no | no |
| `WideCharVector` admits equality | must, unwritten | `MONO_VECTOR_EQ` | `where type vector = WideString.string` | same | same | yes | yes | - | - | - | - | - |
| `^` on `WideString` | no | `WideString.^` | per D20 | same | same | `WideString.^` | same | - | - | - | - | - |

Notes:
- Each mode of Rune is SML '97 read from a file in that mode's encoding,
  except where it is stricter:
  - Comments may not hold controls, bidi controls, line separators or
    invalid UTF-8. This is a deviation, pinned (D5).
  - VT and a lone CR are refused. The Definition leaves both optional, so
    this is no deviation.
  - A surrogate in `\u` is refused, a deviation pinned (D9).
  
  It is nowhere wider: `\U`, Rune's extension, needs `--unicode` (D7).
- `--unicode` departs from the Definition in two rows: non-ASCII identifiers and
  raw non-ASCII at `WideString`. Each is pinned by a test, with its row in
  `docs/language.md`.
- Unicode in a literal at `WideString` follows the Definition's rule for
  escapes, a character's number in the type's alphabet. It departs from
  MLton, which reads one character per byte.

## Appendix C: the change request

What M9 writes into `docs/unicode.md`, for the maintainers of the Basis
Library specification. E6 type-checked it on Rune, HaMLet, MLton, Poly/ML and
SML/NJ, and built it into a copy of Rune's library, where every configuration
of the Basis suite passed with it (rune; xc1 on MLton, Poly/ML and three
builds of SML/NJ; xc2:mlton). xc1 on MLKit has 175 failures, the same with
master's library.

### What is wrong

1. **`WideTextIO :> TEXT_IO` cannot be met.** `TEXT_STREAM_IO` writes
   `include STREAM_IO where type vector = CharVector.vector where type elem =
   Char.char`. `TEXT_IO` writes its readers and writers as `TextPrimIO`'s.
   No structure of wide characters matches either.
2. **`WideCharVector :> MONO_VECTOR where type elem = WideChar.char` cannot
   admit equality,** but `TEXT` shares its vector type with
   `WideString.string`, which must. `MONO_VECTOR` declares `type vector` so
   that `RealVector` can exist. `CharVector` escapes through `where type
   vector = String.string`; `WideCharVector` was not given the same
   constraint.
3. **`STRING_CVT`'s functions over text exist for 8-bit text only.**

### The change

The text types leave the signatures and go to the declarations, as
`MONO_VECTOR`, `PRIM_IO` and `STREAM_IO` already do it. `TEXT_STREAM_IO` and
`TEXT_IO` gain `type substring`. File names stay `string`, which is
`String.string`. `STRING_CVT` takes its character and string types as its own,
and a `WideStringCvt` joins the optional structures.

```sml
signature TEXT_STREAM_IO =
sig
  include STREAM_IO
  type substring
  val inputLine : instream -> (vector * instream) option
  val outputSubstr : outstream * substring -> unit
end

(* 2. TEXT_IO: the same; file names stay String.string. Written out, since
   `include IMPERATIVE_IO` cannot give StreamIO the larger signature (the
   page's own text is not valid SML here: Rune's erratum
   TEXT_IO/include-rewritten). *)
signature TEXT_IO =
sig
  structure StreamIO : TEXT_STREAM_IO
  type vector = StreamIO.vector
  type elem = StreamIO.elem
  type substring = StreamIO.substring
  type instream
  type outstream
  val input : instream -> vector
  val input1 : instream -> elem option
  val inputN : instream * int -> vector
  val inputAll : instream -> vector
  val canInput : instream * int -> int option
  val lookahead : instream -> elem option
  val closeIn : instream -> unit
  val endOfStream : instream -> bool
  val output : outstream * vector -> unit
  val output1 : outstream * elem -> unit
  val flushOut : outstream -> unit
  val closeOut : outstream -> unit
  val mkInstream : StreamIO.instream -> instream
  val getInstream : instream -> StreamIO.instream
  val setInstream : instream * StreamIO.instream -> unit
  val mkOutstream : StreamIO.outstream -> outstream
  val getOutstream : outstream -> StreamIO.outstream
  val setOutstream : outstream * StreamIO.outstream -> unit
  val getPosOut : outstream -> StreamIO.out_pos
  val setPosOut : outstream * StreamIO.out_pos -> unit
  val inputLine : instream -> vector option
  val outputSubstr : outstream * substring -> unit
  val openIn : string -> instream
  val openOut : string -> outstream
  val openAppend : string -> outstream
  val openString : vector -> instream
  val stdIn : instream
  val stdOut : outstream
  val stdErr : outstream
  val print : vector -> unit
  val scanStream : ((elem, StreamIO.instream) StringCvt.reader
                    -> ('a, StreamIO.instream) StringCvt.reader)
                   -> instream -> 'a option
end

(* 3. STRING_CVT over a character and string pair. *)
signature STRING_CVT =
sig
  eqtype char
  eqtype string
  datatype radix = BIN | OCT | DEC | HEX
  datatype realfmt
    = SCI of int option
    | FIX of int option
    | GEN of int option
    | EXACT
  type ('a, 'b) reader = 'b -> ('a * 'b) option
  val padLeft : char -> int -> string -> string
  val padRight : char -> int -> string -> string
  val splitl : (char -> bool) -> (char, 'a) reader -> 'a -> string * 'a
  val takel : (char -> bool) -> (char, 'a) reader -> 'a -> string
  val dropl : (char -> bool) -> (char, 'a) reader -> 'a -> 'a
  val skipWS : (char, 'a) reader -> 'a -> 'a
  type cs
  val scanString : ((char, cs) reader -> ('a, cs) reader) -> string -> 'a option
end
```

The declarations, with each changed or new line marked:

```sml
structure StringCvt :> STRING_CVT
  where type char = Char.char                                (* new *)
  where type string = String.string                          (* new *)
structure WideStringCvt :> STRING_CVT  (* OPTIONAL *)        (* new *)
  where type char = WideChar.char
  where type string = WideString.string
  where type radix = StringCvt.radix
  where type realfmt = StringCvt.realfmt

structure WideString :> STRING  (* OPTIONAL *)
  where type char = WideChar.char
structure WideChar :> CHAR  (* OPTIONAL *)
  where type string = WideString.string
structure WideCharVector :> MONO_VECTOR  (* OPTIONAL *)
  where type vector = WideString.string                      (* added *)
  where type elem = WideChar.char
structure WideCharVectorSlice :> MONO_VECTOR_SLICE  (* OPTIONAL *)
  where type vector = WideCharVector.vector
  where type elem = WideChar.char
structure WideSubstring :> SUBSTRING  (* OPTIONAL *)
  where type substring = WideCharVectorSlice.slice
  where type string = WideString.string
  where type char = WideChar.char

structure TextIO :> TEXT_IO
  where type StreamIO.vector = CharVector.vector             (* moved from TEXT_STREAM_IO *)
  where type StreamIO.elem = Char.char                       (* moved from TEXT_STREAM_IO *)
  where type StreamIO.substring = Substring.substring        (* new *)
  where type StreamIO.reader = TextPrimIO.reader             (* moved from TEXT_IO *)
  where type StreamIO.writer = TextPrimIO.writer             (* moved from TEXT_IO *)
  where type StreamIO.pos = TextPrimIO.pos                   (* moved from TEXT_IO *)
structure WideTextIO :> TEXT_IO  (* OPTIONAL *)
  where type StreamIO.vector = WideCharVector.vector         (* new: the page has none *)
  where type StreamIO.elem = WideChar.char
  where type StreamIO.substring = WideSubstring.substring
  where type StreamIO.reader = WideTextPrimIO.reader
  where type StreamIO.writer = WideTextPrimIO.writer
  where type StreamIO.pos = WideTextPrimIO.pos
```

Unchanged: `TEXT`, `CHAR`, `STRING`, `SUBSTRING`, `MONO_VECTOR`, `PRIM_IO`,
`STREAM_IO` and `IMPERATIVE_IO`. With `WideCharVector`'s added constraint,
`TEXT`'s sharing holds for `Text` and `WideText` with plain `MONO_VECTOR`.
No other signature is needed.

### What it costs

- **Implementations of 8-bit text** add `type substring` to `TextIO` and
  `TextIO.StreamIO`: two lines. E6 checked that each host's real `TextIO`
  then matches the new `TEXT_IO`, and its real `StringCvt` the new
  `STRING_CVT`.
- **Programs** that name `TEXT_IO`, `TEXT_STREAM_IO` or `STRING_CVT` as a
  functor's parameter lose the knowledge that `vector` is `string`, unless
  they add the `where type`. E6 found none in HOL4, MLton's libraries
  (smlnj-lib, CML, mlyacc-lib and the others) or the SML '97 corpus. The
  only users are implementations of the Basis.
- **Alternatives considered:**
  - a new signature `GEN_TEXT_IO`, with `TEXT_IO` as its 8-bit instance, as
    `BIN_IO` is an instance of `IMPERATIVE_IO`;
  - `IO` as a substructure of `TEXT`.

  The first adds names and keeps the synopsis line `WideTextIO :> TEXT_IO`
  false. The second needs the generic `TEXT_IO` anyway.

## Appendix D: the census

E1 counted every `.sml`, `.sig`, `.fun` and `.ML` file of these sources on this
machine, 17,801 in all (21,543 scans, HOL4's being scanned twice):
- Rune at `9b327248`;
- MLton at `b15e2d289`;
- HOL4 at `3d15b18a8`, raw, and as its quotation filter (`unquote`) gives it
  to the compiler;
- the files HOL-rune compiles without the filter, and those HOL generates;
- SML/NJ 110.99.9, SML/NJ 2026.2 and its regression tests;
- Poly/ML 5.9.2, HaMLet 2.0.1, Moscow ML 2.10.1, MLKit and Manticore from
  git;
- the SML '97 corpus repository.

The scanner follows Rune's lexer (nested comments, escapes, gaps). It agrees
with `rune --dump-tokens` on the place and kind of every literal in all
20,149 files that Rune can lex. Character classes come from UCD 18.0.0; NFC
from Python's `unicodedata` (Unicode 15.0). The scripts are in the drafts
(`scripts/E1`).

### The sources

| corpus | files | MB | invalid UTF-8 (Latin-1 text) | CRLF / bare-CR / mixed | BOM start / inner | files with non-ASCII in code / comment / string / char |
|---|---|---|---|---|---|---|
| rune | 2152 | 19.5 | 1 (1) | 1 / 0 / 0 | 0 / 0 | 0 / 3 / 5 / 0 |
| mlton | 1787 | 14.1 | 0 (0) | 9 / 0 / 0 | 0 / 0 | 0 / 2 / 0 / 0 |
| hol-raw | 3742 | 92.5 | 0 (0) | 0 / 0 / 1 | 0 / 0 | 729 / 261 / 79 / 0 |
| hol-unquoted | 3742 | 104.6 | 0 (0) | 0 / 0 / 1 | 0 / 0 | 0 / 258 / 0 / 0 |
| hol-rune-unfiltered | 174 | 2.8 | 0 (0) | 0 / 0 / 0 | 0 / 0 | 0 / 2 / 0 / 0 |
| hol-rune-generated | 410 | 9.6 | 0 (0) | 0 / 0 / 0 | 0 / 0 | 0 / 165 / 0 / 0 |
| corpus-sml97-own | 31 | 0.2 | 0 (0) | 0 / 0 / 0 | 0 / 0 | 0 / 0 / 0 / 0 |
| corpus-packages | 24 | 0.0 | 0 (0) | 0 / 0 / 0 | 0 / 0 | 0 / 0 / 0 / 0 |
| corpus-programs | 66 | 0.1 | 0 (0) | 0 / 0 / 0 | 0 / 0 | 0 / 0 / 0 / 0 |
| smlnj-110.99.9 | 2272 | 13.4 | 0 (0) | 0 / 0 / 0 | 0 / 0 | 0 / 13 / 0 / 0 |
| smlnj-2026.2 | 2537 | 15.3 | 0 (0) | 0 / 0 / 0 | 0 / 0 | 0 / 14 / 0 / 0 |
| smlnj-regressions | 1514 | 0.8 | 1 (0) | 0 / 0 / 0 | 0 / 0 | 0 / 1 / 0 / 0 |
| polyml-5.9.2 | 594 | 6.5 | 0 (0) | 1 / 0 / 0 | 0 / 0 | 0 / 0 / 0 / 0 |
| hamlet-2.0.1 | 352 | 1.6 | 0 (0) | 0 / 0 / 0 | 0 / 0 | 0 / 0 / 0 / 0 |
| mosml-2.10.1 | 203 | 1.0 | 1 (1) | 0 / 0 / 0 | 0 / 0 | 0 / 1 / 0 / 0 |
| mlkit-git | 1602 | 12.1 | 16 (16) | 0 / 0 / 0 | 0 / 0 | 0 / 13 / 3 / 0 |
| manticore-git | 341 | 2.4 | 0 (0) | 0 / 0 / 0 | 0 / 0 | 0 / 5 / 0 / 0 |

### Non-ASCII code points, by context and class

Code points (files). L letter, M mark, N number, P punctuation, S symbol, C other, inv a byte that is not UTF-8.

| corpus | context | total | L | M | N | P | S | Z | C | inv |
|---|---|---|---|---|---|---|---|---|---|---|
| rune | comment | 14 (3) | 8 (1) |  |  |  | 6 (2) |  |  |  |
| rune | string | 14 (5) | 3 (2) | 1 (1) |  |  | 4 (1) |  | 5 (2) | 1 (1) |
| mlton | comment | 3 (2) | 1 (1) |  |  | 2 (1) |  |  |  |  |
| hol-raw | code | 186745 (729) | 11496 (319) |  | 794 (40) | 125463 (593) | 48992 (367) |  |  |  |
| hol-raw | comment | 7260 (261) | 307 (87) | 1 (1) | 53 (7) | 4153 (157) | 2744 (100) |  | 2 (1) |  |
| hol-raw | string | 499 (79) | 137 (26) |  | 28 (10) | 184 (30) | 150 (45) |  |  |  |
| hol-unquoted | comment | 7216 (258) | 306 (87) | 1 (1) | 53 (7) | 4125 (157) | 2729 (97) |  | 2 (1) |  |
| hol-rune-unfiltered | comment | 10 (2) | 1 (1) |  |  | 4 (1) | 5 (1) |  |  |  |
| hol-rune-generated | comment | 152845 (165) | 7264 (133) |  | 792 (39) | 956 (29) | 143833 (165) |  |  |  |
| smlnj-110.99.9 | comment | 101 (13) | 6 (4) |  | 8 (2) | 9 (3) | 78 (9) |  |  |  |
| smlnj-2026.2 | comment | 78 (14) | 3 (2) |  | 4 (1) | 11 (5) | 60 (8) |  |  |  |
| smlnj-regressions | comment | 2 (1) |  |  |  |  |  |  |  | 2 (1) |
| mosml-2.10.1 | comment | 3 (1) |  |  |  |  |  |  |  | 3 (1) |
| mlkit-git | comment | 52 (13) |  |  |  |  |  |  |  | 52 (13) |
| mlkit-git | string | 26 (3) |  |  |  |  |  |  |  | 26 (3) |
| manticore-git | comment | 11 (5) |  |  |  | 9 (3) | 2 (2) |  |  |  |

### The files each rule refuses

The census named the modes as the brief does: its `--ascii` with UTF-8
comments is the default, and its `--utf8` is `--unicode`.

| policy | rune | mlton | hol-raw | hol-unquoted | hol-rune-unfiltered | hol-rune-generated | corpus-sml97-own | corpus-packages | corpus-programs | smlnj-110.99.9 | smlnj-2026.2 | smlnj-regressions | polyml-5.9.2 | hamlet-2.0.1 | mosml-2.10.1 | mlkit-git | manticore-git |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Comments (a): well-formed UTF-8 (invalid bytes in a comment) | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 0 | 0 | 1 | 13 | 0 |
| Comments (b): ASCII only (any non-ASCII in a comment) | 3 | 2 | 261 | 258 | 2 | 165 | 0 | 0 | 0 | 13 | 14 | 1 | 0 | 0 | 1 | 13 | 5 |
| Literals (a): raw non-ASCII rejected | 5 | 0 | 79 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 3 | 0 |
| Literals (b): raw UTF-8 allowed (invalid bytes in a literal) | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 3 | 0 |
| Controls outside literals, the brief as written: HT LF CR only (FF also rejected) | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 2 | 2 | 0 | 0 | 0 | 0 | 0 | 0 |
| Controls outside literals: HT LF FF + CRLF only (bare CR, VT, NUL, other C0, DEL, C1 rejected) | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| Controls outside literals: as above, bare CR also allowed | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| Controls inside literals: none (raw HT, DEL, C1 ... rejected) | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| Bidi controls and default-ignorables (SHY, ZW*, VS, inner BOM...) anywhere | 2 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| ... and a leading BOM too | 2 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| MODE --ascii as the brief writes it: 32-126 plus HT LF CR outside literals, anywhere incl. comments | 7 | 2 | 787 | 258 | 2 | 165 | 0 | 0 | 0 | 15 | 16 | 1 | 0 | 0 | 1 | 16 | 5 |
| MODE --ascii with UTF-8 comments: C(a)+L(a)+ASCII code+controls(CRLF only)+bidi/DI | 5 | 0 | 742 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 0 | 0 | 1 | 16 | 0 |
| MODE --utf8 (strict): valid UTF-8 + controls(CRLF only) + bidi/DI; non-ASCII literal bytes allowed | 3 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 0 | 0 | 1 | 16 | 0 |
| (info) non-ASCII in code: needs Unicode identifiers/symbols | 0 | 0 | 729 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| (info) file not valid UTF-8 | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 0 | 0 | 1 | 16 | 0 |
| (info) NEL, LS or PS anywhere | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |

## Appendix E: the host probes

E2's probes, byte for byte, are in the drafts (`results/E2/probes`), with
every host's raw output. The invocations:

| System | How it was run |
|---|---|
| Rune (snapshot of `9b327248`) | `bin/rune -o p.rbc p.sml && bin/runevm p.rbc` |
| Poly/ML 5.9.2 | `echo 'use "p.sml";' \| poly -q` |
| MLKit 4.7.25 | `mlkit -o p.exe p.sml && ./p.exe` |
| Moscow ML 2.10.1 | `mosml -quietdec pre.sml p.sml` |
| HaMLet 2.0.1 | `hamlet p.sml` |
| SML/NJ 110.99.9 | `sml p.sml` |
| MLton 20241230 | `mlton -output p.exe p.sml && ./p.exe`, and the same with `-default-ann 'allowExtendedTextConsts true'` ("MLton+ext") |

"2 bytes" means the program ran and printed `size=2 bytes=195 169`.
"error" is a compile-time refusal, with its message shortened. **Bold** marks
a silently different meaning.

| # | probe | Rune | Poly/ML 5.9.2 | MLKit 4.7.25 | Moscow ML 2.10.1 | HaMLet 2.0.1 | SML/NJ 110.99.9 | MLton 20241230 | MLton+ext |
|---|---|---|---|---|---|---|---|---|---|
| 1 | `"é"` raw, size and bytes | 2 bytes C3 A9 | error: unprintable character \195 | 2 bytes | 2 bytes | error: special constant out of range | 2 bytes | error: Extended text constants ... disallowed | 2 bytes |
| 2 | `#"é"` | error: character literal must contain exactly one character | error: unprintable character | error: string must have length 1 | error: ill-formed character constant | error: syntax error | error: character constant not length 1 | error: extended ... disallowed; not of size 1 | error: Character constant not of size 1 |
| 3 | `é` in a comment | ok | ok | ok | ok | ok | ok | ok | ok |
| 4 | `val café = 1` | error: unexpected character '\195' | error: unknown character "\195" | error: cannot lex | error: ill-formed token | error: invalid character | error: non-Ascii character (ord 195) | error: Illegal token | error: Illegal token |
| 5 | `val λ = 1` | error: unexpected character '\206' | error: unknown character | error: cannot lex | error: ill-formed token | error: invalid character | error: non-Ascii character | error: Illegal token | error: Illegal token |
| 6 | raw TAB in a string | error: control character in string literal | error: unprintable character \t | **ok, size 8: the TAB became 6 spaces** | error: invalid character in string | error: invalid string | error: illegal non-printing character | error: Illegal character in text constant | same |
| 7 | raw DEL in a string | **ok, 3 bytes 97 127 98** | error: unprintable character \127 | ok, 3 bytes | error: invalid character in string | error: invalid string | ok, 3 bytes | error: Illegal character | same |
| 8a | NUL in a comment | ok | ok | ok | **error: comment not terminated (NUL ends the input)** | ok | ok | ok | ok |
| 8b | NUL between tokens | error: unexpected character '\^@' | error: unknown character | error: cannot lex | error: Syntax error | error: invalid character | error: illegal token | error: Illegal token | same |
| 9a | FF between tokens | ok | ok | ok | ok | ok | ok | ok | ok |
| 9b | VT between tokens | ok | ok | error: cannot lex | error: ill-formed token | ok | error: illegal token | ok | ok |
| 10a | bare CR line ends | ok (but lines counted by LF: an error on line 3 is reported at 1:29, `extra/crline.sml`) | ok (error also reported on line 1) | ok | ok | ok | ok (error on line 3.5) | ok | ok |
| 10b | CRLF line ends | ok | ok | ok | ok | ok | ok | ok | ok |
| 10c | gap across CRLF `"a\<CR><LF>  \b"` | 2 bytes "ab" | "ab" | "ab" | "ab" | "ab" | "ab" | "ab" | "ab" |
| 11 | UTF-8 BOM at the start | error: 1:1 unexpected character '\239' | error: unknown character | error: LEXICAL_ERROR | error: ill-formed token | error: invalid character | error: non-Ascii character (ord 239) | error: Illegal token | same |
| 12a | `"\u00E9"` at string | 1 byte 233 | 1 byte | 1 byte | 1 byte | 1 byte | 1 byte | 1 byte | 1 byte |
| 12b | `"\u0100"` at string | error: out of range for the type string | error: Conversion exception | error: ASCII escape must be <= 255 | error: character code is too large | error: special constant out of range | error: is too large | error: character too large for type | same |
| 12c | `"\u0100"` at WideString | size 1, ord 256 | no WideString | error: must be <= 255 (no WideString) | error: too large (no WideString) | no WideString | error: too large (no WideString) | size 1, ord 256 | size 1, ord 256 |
| 13 | `"\U0001F600"` at string | error: out of range for the type string | error: Conversion exception | error: illegal string escape | error: ill-formed escape | error: invalid string | error: illegal string escape | error: \U disallowed; too large | error: too large for type |
| 13b | `"\U0001F600"` at WideString | size 1, ord 128512 | no WideString | error: illegal string escape | error: ill-formed escape | error: invalid string | error: illegal string escape | error: \U disallowed | size 1, ord 128512 |
| 14 | `"\x41"` | error: invalid escape sequence | error: Conversion exception | error: illegal string escape | error: ill-formed escape | error: invalid string | error: illegal string escape | error: Illegal escape | same |
| 15a | `"\999"` at string | error: \ddd escape out of range | error: Conversion exception | error: must be <= 255 | error: too large | error: out of range | error: is too large | error: too large for type | same |
| 15b | `"\999"` at WideString | **error: \ddd escape out of range (lexer)** | no WideString | error | error | no WideString | error | **size 1, ord 999** | size 1, ord 999 |
| 16a | Latin-1 byte E9 in a string | ok, 4 bytes 99 97 102 233 | error: unprintable character \233 | 4 bytes | 4 bytes | **ok, "caf": 3 bytes, E9 dropped** | 4 bytes | error: Illegal character in text constant | same |
| 16b | Latin-1 byte E9 in a comment | ok | ok | ok | ok | ok | ok | ok | ok |
| 17a | U+202E in a comment | ok | ok | ok | ok | ok | ok | ok | ok |
| 17b | U+202E in a string | ok, 5 bytes | error: unprintable character | ok, 5 bytes | ok, 5 bytes | **ok, size 1: "a", the rest dropped** | ok, 5 bytes | error: extended disallowed | ok, 5 bytes |
| 18a | `val ∘ = 1` | error: unexpected character '\226' | error: unknown character | error: cannot lex | error: ill-formed token | error: invalid character | error: non-Ascii character | error: Illegal token | same |
| 18b | `infix ∘ ... x∘y` | error: unexpected character | error | error | error | error | error | error | error |
| 19 | `"é"` at WideString | **size 2, ords 195 169** | no WideString | no WideString | no WideString | no WideString | no WideString | error: extended disallowed | **size 2, ords 195 169** |
| 20 | `String.toString "é"`, `Char.toString #"\233"` | `\195\169`, `\233` | error: unprintable character | `\195\169`, `\233` | same | error: out of range | same | error: extended disallowed | `\195\169`, `\233` |
| 21a | raw U+0301 alone in a string | 2 bytes 204 129 | error: unprintable | 2 bytes | 2 bytes | error: out of range | 2 bytes | error: extended disallowed | 2 bytes |
| 21b | raw `e` + U+0301 in a string | 3 bytes 101 204 129 (not normalised) | error: unprintable | 3 bytes | 3 bytes | **size 1: "e", the mark dropped** | 3 bytes | error: extended disallowed | 3 bytes |

What the table shows:
- No host normalises (21b: every host that accepts it keeps 101 204 129).
- No host accepts a BOM, a non-ASCII identifier or a non-ASCII symbol.
- Every host accepts any byte in a comment, except Moscow ML, whose lexer
  takes NUL for the end of the input (8a; also "string not terminated" for a
  NUL in a string, `extra/mosmlnul`).
- Raw TAB in a literal: rejected by all but MLKit, which silently turns it
  into spaces (`src/Parsing/LexBasics.sml:43-50`).
- Raw DEL in a literal: accepted by Rune, MLKit and SML/NJ; rejected by
  Poly/ML, Moscow ML, HaMLet and MLton.
- Raw non-ASCII bytes in a literal: kept as bytes by Rune, MLKit, Moscow ML,
  SML/NJ, and MLton with the annotation (well-formed UTF-8 only); rejected by
  Poly/ML and MLton without it; HaMLet rejects or truncates.
- The sml97-extensions table (branch `sml97-extensions`,
  `docs/plans/sml97-extensions.md`, "Successor ML: text beyond ASCII") is
  confirmed for `"é"` on every host, with MLKit now 4.7.25 (it was 4.7.23).
- Poly/ML, SML/NJ, MLKit, Moscow ML and HaMLet have no WideString; only Rune
  and MLton can run 12c, 13b, 15b and 19.
