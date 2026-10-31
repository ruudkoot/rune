# Research notes by an agent

**There have been quite a few Haskell implementations, but GHC is the main practical choice today.** For Haskell 98, the classic implementations to know are **GHC, Hugs 98 and nhc98**; alternatives include **UHC, Jhc, Ajhc, Yhc and HBC**. **MicroHs** is a significant contemporary independent implementation, although it implements an extended subset rather than precisely Haskell 98. [The Glasgow Haskell Compiler](https://www.haskell.org/ghc/?utm_source=chatgpt.com)

The important qualification is that **“supports Haskell 98” does not necessarily mean “implements every detail of the Haskell 98 Report.”** You need to distinguish:

- **Language compatibility:** syntax, type inference, modules and evaluation semantics.
- **Prelude and library compatibility:** the specified classes, functions and module names.
- **Ecosystem compatibility:** whether contemporary packages and build tools work.

The [Haskell 98 Revised Report](https://www.haskell.org/onlinereport/) specifies both the language and its libraries. That is the baseline I use below. [haskell.org](https://www.haskell.org/onlinereport/?utm_source=chatgpt.com)

## 1. The main implementations

These assessments summarize project documentation and known limitations; they are not scores from a common conformance test suite.

| Implementation | Position | Compatibility with Haskell 98 |
|---|---|---|
| **GHC — Glasgow Haskell Compiler** | Actively developed; native compiler and GHCi interactive environment. | **Broad support**, selected with `-XHaskell98`, but documented deviations remain. Its modern Prelude and libraries are particularly relevant to old source compatibility. [The Glasgow Haskell Compiler](https://www.haskell.org/ghc/?utm_source=chatgpt.com) |
| **Hugs 98** | Historical **interpreter**, included because it is an important independent implementation. No longer developed. | **Nearly complete.** Use `+98` mode. Limitations include no mutually recursive modules, restricted identifier characters and some differences in inference/defaulting and numeric literals. [haskell.org](https://www.haskell.org/hugs/?utm_source=chatgpt.com) |
| **nhc98** | Small historical compiler; official release 1.22 dates from July 2010. Requires a 32-bit environment or compatibility mode. | **Designed specifically for Haskell 98 and close to complete.** Has a `-98` option and a documented conformance-gap list, although that list predates the final release. [haskell.org](https://www.haskell.org/nhc98/?utm_source=chatgpt.com) |
| **UHC — Utrecht Haskell Compiler**, associated with **EHC** | Research implementation organized as a series of increasingly sophisticated compilers. Its published build instructions are now old. | **Almost all Haskell 98**, according to its authors, plus much of Haskell 2010 and experimental extensions. It does not claim exact completeness. [haskell.org](https://www.haskell.org/communities/05-2016/html/report.html?utm_source=chatgpt.com) |
| **Jhc** | Independent optimizing compiler producing C, with an emphasis on whole-program compilation. | **Haskell 98 focused**, with extensions. Its original support claim explicitly qualified this with bugs and incomplete libraries; it should not be treated as a proven exact implementation. [Haskell.org](https://mailman.haskell.org/archives/list/haskell%40haskell.org/thread/DZYGEXM2PG4BOAXZA75BWIY35KLTI4WY/?utm_source=chatgpt.com) |
| **Ajhc** | Jhc fork aimed at portable and embedded use. The project announces its closure and directs users back to Jhc. | **Broad Haskell support, with significant documented deviations.** Its manual specifies fixed-width `Integer` and ignores datatype contexts. [ajhc.metasepi.org](https://ajhc.metasepi.org/manual.html?utm_source=chatgpt.com) |
| **Yhc — York Haskell Compiler** | nhc98-derived compiler with portable bytecode. Discontinued; its author declared the project dead in 2011. | **Almost all Haskell 98 programs**, according to the developers. Integration with the wider shared `base` library ecosystem remained incomplete. [haskell.org](https://www.haskell.org/communities/11-2008/html/report.html?utm_source=chatgpt.com) |
| **MicroHs**, executable **`mhs`** | Contemporary independent compiler using combinators and a small portable C runtime; can compile itself. | **Substantial overlap, but not full Haskell 98.** It describes its language as an extended subset of Haskell 2010 and documents language and library gaps. [GitHub](https://github.com/augustss/MicroHs?utm_source=chatgpt.com) |
| **HBC — Chalmers Haskell-B compiler** | Historical compiler. | **Version-dependent.** Older releases implemented Haskell 1.4, but later Haskell 98-targeted releases existed, including 0.9999.5c. I would leave exact final conformance ungraded rather than assume completeness. [GitHub](https://github.com/haskell-implementations/hbc/blob/master/blurb-0.9999.4?utm_source=chatgpt.com) |
| **Helium** | Educational/research compiler emphasizing helpful type errors. | **A deliberate subset.** Its published implementation supports built-in classes but does not let users define arbitrary new type classes and instances, so it cannot compile general Haskell 98 programs. [hackage-content.haskell.org](https://hackage-content.haskell.org/package/helium-1.8.1?utm_source=chatgpt.com) |

**Hugs and nhc98 are especially relevant if your interest is the original standardized language. GHC is especially relevant if your interest is running and maintaining programs today.** Those goals overlap, but their practical requirements differ.

## 2. GHC’s Haskell 98 compatibility deserves particular care

You can select the language edition explicitly:

```sh
ghc -XHaskell98 Main.hs
```

Or, in a Cabal component:

```cabal
default-language: Haskell98
```

GHC still permits additional extensions to be enabled through flags, Cabal settings or module pragmas. Selecting the edition therefore establishes a language baseline; it does not prevent a project from adding extensions. [Glasgow Haskell Compiler 9.14.1 User's Guide](https://downloads.haskell.org/ghc/latest/docs/users_guide/exts/control.html?utm_source=chatgpt.com)

### The modern Prelude can reject valid Haskell 98 code

For example:

```haskell
sameNumber :: Num a => a -> a -> Bool
sameNumber x y = x == y
```

Under Haskell 98, this is valid because `Num` has `Eq` and `Show` as superclasses. Modern GHC’s `Num` has neither, so the signature needs an explicit `Eq a` constraint. This remains true with `-XHaskell98`. [haskell.org](https://www.haskell.org/onlinereport/standard-prelude.html?utm_source=chatgpt.com)

Similarly:

| Area | Haskell 98 | Modern GHC |
|---|---|---|
| `Monad` superclass | No `Applicative` superclass | Requires `Applicative`, which in turn requires `Functor` |
| Pattern failure in `do` notation | Uses the `fail` method of `Monad` | Uses `MonadFail`; `fail` is no longer a `Monad` method |

Consequently, an old custom `Monad` instance or polymorphic `do` expression may require changes. [haskell.org](https://www.haskell.org/onlinereport/standard-prelude.html?utm_source=chatgpt.com)

### Historical library names are another issue

The Haskell 98 library report uses names such as:

```haskell
import List
import Monad
import System
```

Modern code generally uses hierarchical modules such as `Data.List`, `Control.Monad` and `System.Environment`, with functionality sometimes split between modules and packages. The old `haskell98` compatibility package provided wrappers, but its published latest release dates from 2014 and depends on the `base` 4.7 series. It is not a general solution for current GHC installations. [haskell.org](https://www.haskell.org/onlinereport/?utm_source=chatgpt.com)

GHC also documents lexical, layout and strictness-related deviations. **`-XHaskell98` is useful, but it does not recreate an exact historical Haskell 98 implementation.** [Glasgow Haskell Compiler 9.14.1 User's Guide](https://www.haskell.org/ghc/docs/latest/html/users_guide/bugs.html?utm_source=chatgpt.com)

## 3. How close are the independent implementations?

### Hugs: a useful historical comparison, with real gaps

Hugs implements the characteristic Haskell 98 facilities: lazy evaluation, algebraic datatypes, higher-kinded type classes, modules and monadic I/O. Its dedicated compatibility mode makes it useful for studying older Haskell code. [haskell.org](https://www.haskell.org/hugs/?utm_source=chatgpt.com)

Its limitations are not exclusively obscure syntax issues:

- **Mutually recursive modules are unsupported.**
- Its top-level defaulting behavior can reject programs accepted by the Report.
- Decimal literals are initially represented using floating-point values, which can lose precision when interpreted as exact rationals.
- Identifiers are restricted to Latin-1, although strings and comments have broader Unicode support. [haskell.org](https://www.haskell.org/hugs/pages/users_guide/haskell98.html?utm_source=chatgpt.com)

Thus, Hugs is a valuable second implementation, but not an unquestionable reference oracle.

### nhc98: closely tied to the standard, but historically documented

nhc98’s own conformance page records differences involving the monomorphism restriction, contexts, a grammar form, Unicode I/O and some library functions. It also explains that `-98` enables the expected treatment of `n+k` patterns and identifiers beginning with underscores. [haskell.org](https://www.haskell.org/nhc98/98.html?utm_source=chatgpt.com)

However, that page is dated **2001**, and subsequent releases fixed some library deficiencies and incorporated Report revisions. The defensible assessment is **“close to Haskell 98, with documented deviations”**, rather than treating every old limitation as a verified defect in the final 2010 release. [haskell.org](https://www.haskell.org/nhc98/history98.html?utm_source=chatgpt.com)

Its 32-bit restriction also makes it less convenient to use on a current machine. [haskell.org](https://www.haskell.org/nhc98/install.html?utm_source=chatgpt.com)

### MicroHs: a current alternative with a different compatibility target

MicroHs is interesting because it combines a self-compiling implementation with a small runtime that can operate on microcontrollers. It can be bootstrapped using a C compiler and the supplied generated representation, without an existing Haskell compiler. [GitHub](https://github.com/augustss/MicroHs?utm_source=chatgpt.com)

For Haskell 98 conformance, its current documentation identifies several obstacles:

- Datatype contexts are unsupported.
- Record updates cannot change the types of polymorphic fields.
- Extensions are generally always enabled.
- Some standard-library operations are absent, including several handle and file-position operations.

It also follows some modern GHC library choices, such as removing `fail` from `Monad`. **It is a substantial independent Haskell implementation, but not a strict Haskell 98 checker.** Older descriptions claiming that it lacks records or ordinary inference should not be used as a current feature list. [GitHub](https://github.com/augustss/MicroHs/wiki/Language?utm_source=chatgpt.com)

### Jhc and Ajhc: attractive implementation ideas, but check semantics

The most conspicuous documented issue is in **Ajhc’s published manual**: `Integer` is represented by fixed-width `IntMax`, rather than an arbitrary-precision integer type. It also documents ignored datatype contexts and eta-expansion of class methods. [ajhc.metasepi.org](https://ajhc.metasepi.org/manual.html?utm_source=chatgpt.com)

That means compatibility can fail at runtime, even when a program parses and typechecks. For example:

```haskell
large :: Integer
large = 10 ^ 100
```

Haskell 98 specifies an arbitrary-precision `Integer`; a fixed-width representation cannot preserve that contract. [haskell.org](https://www.haskell.org/onlinereport/basic.html?utm_source=chatgpt.com)

I would attach that specific limitation to the documented Ajhc implementation, rather than assume it necessarily describes every later Jhc fork or revision.

## 4. Other names you will encounter

Some projects reuse GHC’s frontend, while others implement a subset or a related language. That distinction matters when counting independent implementations.

| Project | What it is | Meaning for Haskell 98 compatibility |
|---|---|---|
| **GHCJS** | Haskell-to-JavaScript compiler using the GHC API and a customized GHC library. | Language support largely follows its GHC generation; runtime, foreign interfaces and available libraries depend on the JavaScript target. It is not an independently implemented Haskell 98 frontend. [GitHub](https://github.com/ghcjs/ghcjs?utm_source=chatgpt.com) |
| **Haste** | Another GHC-based Haskell-to-JavaScript compiler. | Broad GHC language support, with its own target/runtime constraints. Its package documentation supports most GHC extensions rather than making an exact Haskell 98 conformance claim. [hackage-content.haskell.org](https://hackage-content.haskell.org/package/haste-compiler?utm_source=chatgpt.com) |
| **Eta** | Haskell dialect for the JVM, targeting compatibility with GHC 7.10.3’s Haskell. | Broad Haskell source compatibility from that compiler generation, with a different runtime and interoperability model. [GitHub](https://github.com/typelead/eta?utm_source=chatgpt.com) |
| **LHC** | Experimental compiler/backend using GRIN and whole-program optimization; the documented 2010 version used GHC as its frontend. | Haskell 98 coverage was explicitly incomplete. LHC is a separate project from GHC’s ordinary LLVM backend. [haskell.org](https://www.haskell.org/communities/11-2010/html/report.html?utm_source=chatgpt.com) |
| **Haskell frontend for Clean / Haskell\*** | Research work allowing Haskell and Clean to share an implementation and language facilities. | Supported a large part of Haskell 98, with additional cross-language features; not an exact standard implementation. [haskell.org](https://www.haskell.org/communities/11-2010/html/report.html?utm_source=chatgpt.com) |
| **Fay** | A Haskell subset, typechecked using GHC and compiled to JavaScript. | Explicitly a proper subset, so not generally Haskell 98 compatible. [hackage-content.haskell.org](https://hackage-content.haskell.org/package/fay?utm_source=chatgpt.com) |
| **Frege** | A Haskell-like language compiling to Java and running on the JVM. | Aims for considerable source similarity, but has intentional language and library differences. It is not an exact Haskell 98 implementation. [GitHub](https://github.com/frege/frege?utm_source=chatgpt.com) |
| **Mu** | Standard Chartered’s proprietary Haskell dialect and compiler. | Uses strict evaluation, which is a fundamental semantic departure from Haskell 98. It is an industrial Haskell-family implementation, but not a standard-conforming replacement. [ICFP 2022](https://icfp22.sigplan.org/details/hiw-2022/8/Compiling-Mu-with-GHC-Halfway-Down-the-Rabbit-Hole?utm_source=chatgpt.com) |

Current GHC itself also has **JavaScript and WebAssembly targets**. These broaden GHC’s deployment options; they do not constitute independent implementations of the source language. [Glasgow Haskell Compiler 9.14.1 User's Guide](https://downloads.haskell.org/ghc/latest/docs/users_guide/javascript.html?utm_source=chatgpt.com)

For older history, **Yale Haskell** compiled through Common Lisp and was abandoned around 1995, before Haskell 98. **Gofer** was a deliberately Haskell-like system with type-system differences, and was the predecessor of Hugs. Neither should be counted as a Haskell 98 implementation. [simon.peytonjones.org](https://simon.peytonjones.org/assets/pdfs/haskell-being-lazy-with-class.pdf?utm_source=chatgpt.com)

## 5. Which are worth investigating?

My recommendations depend on what you want to learn or run:

| Your purpose | Where I would start |
|---|---|
| **Run and maintain Haskell programs today** | **GHC**, selecting `Haskell98` explicitly where appropriate and checking library assumptions. |
| **Study the original Haskell 98 language and older examples** | **Hugs 98**, supplemented by **nhc98** and the Report. |
| **Explore a contemporary independent compiler** | **MicroHs**, while keeping its documented language differences in view. |
| **Study compiler construction and language experimentation** | **UHC/EHC**, especially its incremental organization and use of attribute grammars. |
| **Study whole-program optimization and portable C generation** | **Jhc/Ajhc**, with particular attention to their runtime and semantic tradeoffs. |

There is also a useful distinction for **compiler testing**: agreement between several implementations is evidence, not proof of conformance. They can share the same deviation, and two compilers can accept the same program while giving different results. A serious Haskell 98 comparison should therefore test **acceptance of valid programs, rejection of invalid programs, inferred types, runtime behavior and library behavior separately**.

Finally, being able to compile Haskell 98 does not imply being able to compile arbitrary Hackage packages. Neil Mitchell’s account of Yhc’s demise explicitly identifies dependencies on GHC-specific language and runtime features as a major obstacle for alternative implementations. That is an important reason the list of Haskell compilers is much longer than the list of interchangeable choices for a current Haskell project. [yhc06.blogspot.com](https://yhc06.blogspot.com/?utm_source=chatgpt.com)

Yes—**`haskell-src-exts`**, usually abbreviated **HSE**, belongs in this survey. Once you include parsers and source-analysis libraries, there are several useful Haskell implementations beyond the compilers.

For your Haskell 98 question, the key distinction is **how much of the language a tool implements**:

- A **parser** recognizes syntax and produces a syntax tree.
- A **name resolver** determines which declaration each identifier refers to, including across modules.
- A **typechecker** checks the program’s static semantics.
- A **source-editing library** helps preserve comments and formatting when modifying a program.

For example, this is syntactically valid Haskell 98, although it fails typechecking:

```haskell
f :: Int
f = True
```

Consequently, “supports Haskell 98” means something narrower for a parser than for a compiler.

## 1. The main parsers and frontends

| Project | What it provides | Relationship to Haskell 98 |
|---|---|---|
| **`haskell-src`** | An independent lexer, parser, AST and prettyprinter. | Explicitly centered on Haskell 98, although its syntax representation includes a few extensions, such as multiparameter classes. It is therefore not automatically a strict H98 validator. |
| **`haskell-src-exts`** | An independent parser, annotated AST, prettyprinting and source-manipulation utilities. | Explicit `Haskell98` and `Haskell2010` modes, plus many individually selectable extensions. A useful option for independent H98 syntax processing. |
| **GHC’s parser**, through `ghc` or `ghc-lib-parser` | GHC’s actual parser and syntax tree. | Supports the `Haskell98` language setting. Its behavior follows the particular GHC version; GHC documents some deviations from the standard. |
| **`tree-sitter-haskell`** | A grammar for an incremental, error-tolerant parsing engine. | Targets Haskell 2010 and many GHC extensions. Useful for editor syntax processing, but not a strict H98 checker. |
| **Programatica** | A historical independent frontend with parsing, scoping, module analysis and typechecking. | Explicitly targets the revised Haskell 98 Report. Particularly relevant if you want more than syntax recognition. |
| **`language-haskell`** | An experimental parser/frontend with modular syntax extensions and alternative AST machinery. | Its documented target is Haskell 2010 plus extensions. I would not infer complete H98 compatibility from that claim. |

Sources for the respective implementations: `haskell-src`, HSE, GHC, Tree-sitter, Programatica and `language-haskell`. [hackage-content.haskell.org](https://hackage-content.haskell.org/package/haskell-src-1.0.4.2/docs/Language-Haskell-Syntax.html?utm_source=chatgpt.com)

## 2. `haskell-src-exts`: still useful, especially for an independent AST

HSE gives you a standalone implementation of Haskell source syntax. Its public modules cover parsing, syntax construction, source locations, comments, prettyprinting and other source operations. Its AST is separate from GHC’s internal representation. [hackage-content.haskell.org](https://hackage-content.haskell.org/package/haskell-src-exts-1.24.0?utm_source=chatgpt.com)

### Haskell 98 mode

You can select the language explicitly:

```haskell
import qualified Language.Haskell.Exts as H

parseHaskell98 :: String -> H.ParseResult (H.Module H.SrcSpanInfo)
parseHaskell98 =
  H.parseModuleWithMode
    (H.defaultParseMode
      { H.baseLanguage = H.Haskell98
      , H.extensions   = []
      })
```

HSE’s documented default mode already uses Haskell 98 with no additional extensions, but writing the choice explicitly makes a tool’s policy clearer. The parser also exposes entry points for individual expressions, patterns, declarations, types and imports. [hackage-content.haskell.org](https://hackage-content.haskell.org/package/haskell-src-exts-1.24.0/docs/Language-Haskell-Exts-Parser.html?utm_source=chatgpt.com)

There is an API detail to watch: **the functions in `Language.Haskell.Exts.Parser` do not use `LANGUAGE` pragmas to change their parsing mode**. Higher-level file-parsing helpers handle those pragmas. A tool enforcing H98 should make its pragma policy explicit instead of assuming every parsing entry point treats them identically. [hackage-content.haskell.org](https://hackage-content.haskell.org/package/haskell-src-exts-1.24.0/docs/Language-Haskell-Exts-Parser.html?utm_source=chatgpt.com)

### Source locations, comments and exact printing

HSE’s annotated syntax trees can retain detailed source-position information. Comments can be returned alongside the AST, and its exact-printing interface consumes both:

```haskell
exactPrint :: ExactP ast => ast SrcSpanInfo -> [Comment] -> String
```

So HSE is capable of more than “parse, discard the presentation, then prettyprint.” It has machinery for reproducing source according to its annotations. If you transform the tree, however, you must also manage the annotations needed for the intended output. [hackage-content.haskell.org](https://hackage-content.haskell.org/package/haskell-src-exts-1.24.0/docs/Language-Haskell-Exts-ExactPrint.html?utm_source=chatgpt.com)

### Operator fixities require special care

Consider:

```haskell
a <+> b <.> c
```

The intended grouping depends on the operators’ precedence and associativity. If those operators come from imported modules, processing the current file alone does not supply all the relevant information.

HSE provides fixity application functions and predefined fixity tables, including Prelude fixities. That is useful machinery, but a flat fixity table is not the same thing as resolving imports and determining precisely which operator each occurrence denotes. Its own broader fixity table documents a name collision between operators from different modules. [hackage-content.haskell.org](https://hackage-content.haskell.org/package/haskell-src-exts-1.24.0/docs/Language-Haskell-Exts-Fixity.html?utm_source=chatgpt.com)

This matters for transformations: an AST with the wrong operator grouping can lead to a rewrite that changes the program’s meaning.

### Maintenance and modern syntax

HSE should **not simply be described as abandoned**. Version **1.24.0 was uploaded on 4 July 2026**, and the package lists testing with GHC 9.14.1. Nevertheless, its maintainer describes the maintenance level as “on life support” and points users toward `ghc-lib-parser`. [hackage-content.haskell.org](https://hackage-content.haskell.org/package/haskell-src-exts-1.24.0?utm_source=chatgpt.com)

Also distinguish these two claims:

- The library **builds using** a recent GHC.
- The library **parses all syntax accepted by** that GHC.

The first does not establish the second. HSE’s extension coverage evolves separately; for example, its 1.24 release added `ImportQualifiedPost`. I would check specific extensions rather than rely on the package’s broad historical description of GHC-extension support. [Hackage](https://hackage-content.haskell.org/package/haskell-src-exts-1.24.0/changelog?utm_source=chatgpt.com)

**My assessment:** HSE remains reasonable for Haskell 98, controlled subsets and tools that benefit from an independent source AST. For tools expected to follow current GHC syntax closely, I would usually choose the GHC parser family.

## 3. `haskell-src`: the smaller Haskell 98-oriented option

The older **`haskell-src`** package is also worth considering. It provides parsing and generation of Haskell source through modules such as `Language.Haskell.Parser`, `Language.Haskell.Syntax` and `Language.Haskell.Pretty`. It still receives maintenance: version **1.0.4.2 was uploaded in August 2025**. [hackage.haskell.org](https://hackage.haskell.org/package/haskell-src?utm_source=chatgpt.com)

Its documented AST covers **Haskell 98 plus a few extensions**, including multiparameter classes and less restricted class assertions. That makes it useful for studying or manipulating relatively small Haskell syntax trees, but accepting a tree through this API does not prove that the input obeys every H98 restriction. [hackage-content.haskell.org](https://hackage-content.haskell.org/package/haskell-src-1.0.4.2/docs/Language-Haskell-Syntax.html?utm_source=chatgpt.com)

I would investigate it when simplicity matters more than broad extension coverage—for example, a small teaching tool or a prototype over a deliberately restricted source language. HSE offers a broader set of source-handling facilities.

## 4. The GHC parser ecosystem: several similarly named packages

These names are easy to confuse:

| Package | Role |
|---|---|
| **`ghc`** | The compiler’s own API: parsing, renaming, typechecking, desugaring and more. Its version accompanies the GHC installation. |
| **`ghc-lib-parser`** | The GHC API subset needed for parsing, packaged so that the parser version can be decoupled from the compiler used to build your tool. |
| **`ghc-lib`** | A larger extraction of the GHC API, extending the parser package with facilities such as renaming, typechecking and desugaring. |
| **`ghc-lib-parser-ex`** | Convenience functions around GHC parsing, AST inspection, fixities and output. It is an additional utility layer. |
| **`ghc-parser`** | A separate parsing-helper package associated with IHaskell, using the installed GHC API. It is not another name for `ghc-lib-parser`. |

The package documentation distinguishes these roles. [hackage-content.haskell.org](https://hackage-content.haskell.org/package/ghc-9.2.1/docs/GHC.html?utm_source=chatgpt.com)

### Why use `ghc-lib-parser`?

Its main advantage is that you are using **GHC’s own syntax implementation**. You can select a particular parser/API version without necessarily building the application with that same compiler version, within the package’s supported build ranges. This does **not** make GHC’s AST stable between releases; upgrading the embedded parser can still require changes to your code. [GitHub](https://github.com/digital-asset/ghc-lib?utm_source=chatgpt.com)

For H98-oriented use, explicitly select `Haskell98`. Current GHC supports multiple language editions, and its default is not Haskell 98. The user guide also explicitly qualifies its H98 implementation as having known deviations. [Glasgow Haskell Compiler 9.14.1 User's Guide](https://downloads.haskell.org/ghc/latest/docs/users_guide/exts/control.html?utm_source=chatgpt.com)

### Parsing is only the first GHC frontend stage

GHC distinguishes syntax trees at different stages:

| Stage | Information available |
|---|---|
| **`GhcPs`** — parsed | Source structure and names as written. |
| **`GhcRn`** — renamed | Names resolved to their bindings. |
| **`GhcTc`** — typechecked | The result of typechecking and elaboration. |

These are explicit phases of GHC’s AST representation. The high-level API’s `typecheckModule` performs both renaming and typechecking, and its result retains access to the preceding representations. [downloads.haskell.org](https://downloads.haskell.org/ghc/9.14.2-rc1/docs/libraries/ghc-9.14.1.20260728/src/GHC.Hs.Extension.html?utm_source=chatgpt.com)

That distinction is essential for questions such as:

- Does this `map` refer to `Prelude.map` or a local function?
- Which imported operator supplies this fixity?
- Would this rename capture another variable?
- Which typeclass instance is involved?

A syntactic identifier match cannot answer all those questions.

One practical qualification: `ghc-lib` does not bundle GHC’s runtime or a package database, and interface-file compatibility remains version-dependent. It therefore needs more setup than adding a parser dependency, and cannot by itself provide facilities such as executing Template Haskell splices. [GitHub](https://github.com/digital-asset/ghc-lib?utm_source=chatgpt.com)

## 5. Libraries around HSE

Several related packages add another layer without replacing HSE’s parser:

| Package | What it adds | What that means for compatibility |
|---|---|---|
| **`haskell-names`** | Name resolution, module export calculation and annotations connecting references to local or imported definitions. | Moves beyond parsing into binding and module analysis; it does not provide a complete typechecker. |
| **`haskell-src-meta`** | Conversion from HSE syntax to Template Haskell syntax, plus parsing conveniences. | Useful for metaprogramming. The translation is documented as incomplete. |
| **`haskell-src-exts-util`** | Helpers including free/bound-variable calculations and expression rebracketing. | Useful AST utilities; they are not a substitute for a full semantic frontend. |

These capabilities are described in the respective project documentation. [hackage-content.haskell.org](https://hackage-content.haskell.org/package/haskell-names?utm_source=chatgpt.com)

There is a concrete dependency issue if you combine current releases: the published **`haskell-names` 0.9.9.1** bounds require **`haskell-src-exts < 1.24`**. Thus, “latest HSE plus latest `haskell-names`” is not currently a combination you can assume will resolve without additional work. [hackage-content.haskell.org](https://hackage-content.haskell.org/package/haskell-names?utm_source=chatgpt.com)

Also, **Template Haskell’s AST is a separate representation**. Converting a parsed expression into a TH expression does not mean that it has already been renamed or typechecked by GHC.

## 6. Formatting, refactoring and analysis tools

These projects show what can be built on top of the parsers.

### `ghc-exactprint`

This is a key library for changing Haskell source while retaining comments and presentation around the changes. It works with GHC’s syntax and exact-print annotations. Those annotations were integrated into GHC beginning with GHC 9.2, while the companion library supplies additional printing and transformation machinery. Its documentation also identifies complications around CPP and literate Haskell. [GitHub](https://github.com/alanz/ghc-exactprint?utm_source=chatgpt.com)

An ordinary prettyprinter is appropriate when you want a consistently rendered program. Exact printing is useful when you want a small edit to produce a small source diff.

### Retrie

**Retrie** offers higher-level, equation-driven rewriting of expressions, types and patterns. It handles issues such as alpha-equivalent matching, local binding structure and capture avoidance, while preserving surrounding whitespace and comments. It uses GHC’s parser. This makes it worth investigating before implementing a refactoring system directly over raw AST constructors. [GitHub](https://github.com/facebookincubator/retrie?utm_source=chatgpt.com)

The rewrite you supply still needs to be appropriate for the program; a rewriting framework cannot make an arbitrary equation semantically valid.

### HLint

**HLint historically used HSE, but migrated to the GHC parser ecosystem.** Current package dependencies include `ghc-lib-parser` and `ghc-lib-parser-ex`. It is a useful example of syntax-oriented analysis and suggestions built on a compiler-derived parser. [hackage-content.haskell.org](https://hackage-content.haskell.org/package/hlint?utm_source=chatgpt.com)

### Ormolu and Fourmolu

**Ormolu** uses the GHC parser for formatting; **Fourmolu** is a configurable fork. Ormolu also consults project information for extensions and operator fixities, illustrating that even formatting sometimes requires information beyond the text of a single module. [GitHub](https://github.com/tweag/ormolu?utm_source=chatgpt.com)

These are useful architectural references if your interest is source tools rather than compilation itself.

## 7. Tree-sitter: a different set of priorities

**`tree-sitter-haskell`** is particularly relevant for editors, navigation, highlighting and structural queries.

The Tree-sitter engine builds concrete syntax trees, updates them incrementally after edits and remains useful when the source contains syntax errors. Those capabilities suit an editor buffer that is frequently incomplete. [Tree-sitter](https://tree-sitter.github.io/tree-sitter/?utm_source=chatgpt.com)

The Haskell grammar targets Haskell 2010 and many GHC extensions, but documents omissions and preprocessing limitations. It also needs a custom scanner to handle Haskell’s layout-sensitive syntax. [GitHub](https://github.com/tree-sitter/tree-sitter-haskell?utm_source=chatgpt.com)

For your compatibility question, I would treat it as an **editor syntax implementation**, rather than evidence that a program conforms to Haskell 98. In particular:

- Obtaining a recovery tree is different from accepting a valid program.
- A syntax tree does not resolve imports or typecheck declarations.
- Preserving source text through ranges and the original buffer is different from having a complete source-transformation and exact-printing API.

Its strengths are valuable, but they address a different problem from a Report-oriented compiler frontend.

## 8. Two independent frontends worth looking at

### Programatica: especially relevant to Haskell 98

**Programatica** deserves attention if your interest is the implementation of H98 itself.

Its documented frontend includes:

- Lexing and parsing, including fixity handling.
- Scope analysis and module-dependency analysis.
- Typechecking.
- Dictionary translation and derived-instance generation.
- Source transformations and a cross-referenced source browser.

It explicitly targets the **revised Haskell 98 Report**, including recursive modules without GHC-style `hi-boot` files. [Features](https://ogi.altocumulus.org/~hallgren/Programatica/tools/features.html?utm_source=chatgpt.com)

I would approach it as a historical implementation and research reference, with a separate investigation of how much work is needed to build or reuse it today. It offers considerably more evidence about independent H98 frontend design than a parser-only package does.

### `language-haskell`: interesting frontend architecture

The **`language-haskell` 0.1 candidate** takes an unusual approach:

- Syntax extensions are implemented through modular grammar additions.
- The AST uses a finally-tagless representation.
- Node wrappers can retain source positions and tokens.
- Binding information and fixity correction form additional processing stages.

Its documented target is Haskell 2010 with extensions. The version I found is explicitly a **candidate release**, so I would regard it as an experimental project rather than assume established production maturity or full H98 conformance. [hackage-content.haskell.org](https://hackage-content.haskell.org/package/language-haskell-0.1/candidate?utm_source=chatgpt.com)

If you are studying how to structure an extensible frontend, that design is worth comparing with HSE’s conventional annotated AST and GHC’s phase-indexed AST.

## 9. Alex, Happy, Parsec and Megaparsec are another category

These names often appear in the same discussions, but they are tools for **building parsers**:

| Tool | Purpose |
|---|---|
| **Alex** | Generates lexical analyzers from lexer specifications. |
| **Happy** | Generates parsers from grammar specifications; GHC uses it. |
| **Parsec** | A general parser-combinator library. |
| **Megaparsec** | A general parser-combinator library with substantial error-reporting, recovery and indentation support. |

Their documentation describes these general-purpose roles. [hackage-content.haskell.org](https://hackage-content.haskell.org/package/alex?utm_source=chatgpt.com)

Using one of them does not by itself give you Haskell 98 support. You still need to implement the language’s lexical rules, layout, grammar, fixity treatment and subsequent semantic checks.

## What I would choose

For the uses suggested by your Haskell 98 question, my shortlist would be:

| Your objective | Starting point I would investigate |
|---|---|
| **Parse Haskell 98 into an independent, inspectable AST** | **`haskell-src-exts`**; also inspect `haskell-src` if you want a smaller representation. |
| **Parse contemporary GHC source** | **`ghc-lib-parser`**, with `ghc-lib-parser-ex` for conveniences. |
| **Resolve names and types in real GHC projects** | **The GHC API**, with the project’s actual compiler settings and dependency environment. |
| **Make source edits while preserving presentation** | **`ghc-exactprint`**; consider **Retrie** for supported rewriting tasks. |
| **Build editor highlighting or incremental syntax features** | **`tree-sitter-haskell`**. |
| **Study an independent Haskell 98 semantic frontend** | **Programatica**. |
| **Study modular syntax extensions and alternative AST designs** | **`language-haskell`**, as an experimental reference. |

For an independent compiler project, I would evaluate **syntax coverage, binding/module resolution, typechecking and source preservation separately**. HSE is a substantial answer to the first and part of the fourth; the remaining stages determine how far it takes you toward a complete Haskell 98 implementation.