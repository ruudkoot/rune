sml97 has first order modules. i heard this was becuase the higher-order was not fully understood. but that it is now and that it is clean. is this true? give the a  detailed overview of the research.

---

Yes, with an important qualification: **higher-order modules are now theoretically well understood, and there are several clean formal accounts of them. But it is not quite true that SML’97 omitted them simply because nobody understood higher-order modules yet.** Much of the key theory already existed by the early-to-mid 1990s. What had not yet emerged was a single design that was simultaneously simple, compatible with Standard ML’s existing semantics, implementable, amenable to separate compilation, and accepted as the obvious thing to standardize.

The subsequent research is particularly relevant to Rune because it shows that you can extend an SML-like module language to higher order without turning it into an ad-hoc mess.

## 1. What “first-order modules” means in SML’97

SML’97 already has functions at the module level:

```sml
signature ORD =
sig
    type t
    val compare : t * t -> order
end

functor SetFn (Key : ORD) =
struct
    type elem = Key.t
    ...
end
```

A functor is a function:

\[
\text{SetFn} : \text{ORD} \to \text{SET}
\]

but only in a restricted, first-order sense.

You cannot abstract over a functor:

```sml
functor Transform (F : ??? functor type ???) = ...
```

or naturally return one:

```sml
functor MakeSomething (X : S) =
    functor F (Y : T) = ...
```

or put functors inside ordinary structures:

```sml
structure Algorithms =
struct
    functor Make = ...
end
```

in Standard ML proper.

So SML's module language resembles a first-order functional language:

\[
\text{Structure} \rightarrow \text{Structure}
\]

but not:

\[
(\text{Structure} \rightarrow \text{Structure})
\rightarrow
(\text{Structure} \rightarrow \text{Structure})
\]

Higher-order modules allow those latter constructions.

And there is another distinction worth keeping clear:

**higher-order modules ≠ first-class modules.**

A language may permit functors to accept/return functors while modules remain a statically separated second-class language.

First-class modules go further:

```ml
if condition then module A else module B
```

and allow modules to participate in ordinary core-language computation.

The research path eventually reaches that point too.

---

# 2. Why higher-order ML modules are surprisingly difficult

If modules were merely records, this would be trivial.

Suppose:

```sml
structure X =
struct
    type t = int
    val x = 1
end
```

A structure is not just a record containing `x`. It also contains a **type component**.

Conceptually:

\[
X =
\{
   t : \mathrm{Type},
   x : t
\}
\]

A functor such as:

```sml
functor F (X : S) =
struct
    type t = X.t list
    ...
end
```

therefore has a type resembling a dependent function:

\[
\Pi X:S.\;T(X)
\]

because the result signature can depend on the argument's type components.

That is already more sophisticated than:

\[
S \rightarrow T.
\]

Once functors themselves become functor arguments, you get dependent functions over dependent functions.

That brings several difficult questions together.

---

# 3. The four fundamental problems

The later literature becomes much easier to understand if you separate four issues.

### Dependency

Functor results can depend on argument types.

```sml
functor F (X : S) =
struct
    type t = X.t list
end
```

The result isn't simply some fixed signature `T`; its type structure depends on `X`.

---

### Transparency and abstraction

Sometimes you want the type relationship exposed:

```sml
type t = X.t list
```

Sometimes hidden:

```sml
:> S
```

The module type system must distinguish:

\[
t = X.t\;\text{list}
\]

from merely:

\[
t : \mathrm{Type}.
\]

This is the transparency problem.

---

### Generativity

Consider:

```sml
functor F (X : S) =
struct
    datatype t = C
end
```

Now:

```sml
structure A = F(X)
structure B = F(X)
```

Should:

```sml
A.t = B.t
```

hold?

Traditional Standard ML intuition says no: creation of the datatype produces a fresh type identity.

So module application can have an effect at the type level:

\[
\text{newtype}()
\]

This becomes especially awkward once functors can be passed around.

---

### Higher-orderness

Now imagine:

```text
H(F)(X)
```

where `F` is itself a functor.

What is the static identity of:

```text
F(X).t
```

?

Is another occurrence of `F(X).t` the same type?

That depends on whether `F` is generative or applicative and whether the compiler can determine the identity of `F` and `X`.

This is one of the central questions in the literature.

---

# 4. MacQueen: modules as dependent types

The intellectual starting point is David MacQueen's work designing the Standard ML module system in the 1980s.

Two particularly important ideas emerged very early:

- modules contain types as well as values;
- therefore functor signatures naturally resemble **dependent function types**.

MacQueen's work, including *Modules for Standard ML* and *Using Dependent Types to Express Modular Structure*, made this connection explicit.

A module:

```sml
sig
    type t
    val x : t
end
```

resembles a dependent pair:

\[
\Sigma t:\mathrm{Type}.\;t
\]

and a functor resembles:

\[
\Pi X:S.\;T(X).
\]

This observation is enormously important.

It means that ML modules aren't fundamentally a mysterious programming-language construct. They are closely related to familiar type-theoretic objects:

- structures → dependent records / Σ-types;
- functors → dependent functions / Π-types;
- abstract types → existential types;
- signature matching → subtyping/refinement;
- sharing constraints → type equations.

But directly exposing full dependent type theory would have been far too complicated for Standard ML.

The challenge became finding a restricted module calculus with ML-like decidable elaboration.

---

# 5. Harper, Mitchell and Moggi: the phase distinction

One of the decisive papers was:

**Robert Harper, John Mitchell, Eugenio Moggi — _Higher-Order Modules and the Phase Distinction_ (1990).**

This is probably the single most important paper for understanding why higher-order modules are possible at all.

The insight is that a module has two fundamentally different kinds of information.

A module like:

```sml
structure M =
struct
    type t = int
    val x = expensive_computation ()
end
```

contains:

### Static information

```text
t = int
```

known during compilation.

### Dynamic information

```text
x = expensive_computation ()
```

computed at runtime.

They formalized a **phase distinction**:

\[
M =
(M_{\text{static}}, M_{\text{dynamic}})
\]

The type checker should only depend upon the static component.

This sounds obvious now, but it is crucial when modules become higher-order.

Suppose:

```text
F : Module -> Module
```

and `F` gets passed around.

The compiler must be able to determine all type-level behavior of `F` without evaluating arbitrary runtime behavior.

The phase distinction guarantees precisely that.

It turns the higher-order module problem into a much cleaner question:

> What is the static type-level function represented by this functor?

while its runtime component becomes relatively conventional code.

This work demonstrated that higher-order modules could have a principled semantics.

So already by **1990**, it would be wrong to say higher-order modules were completely uncharted territory.

---

# 6. The 1994 breakthrough: translucent types

Another major step was:

**Robert Harper and Mark Lillibridge — _A Type-Theoretic Approach to Higher-Order Modules with Sharing_ (1994).**

Their crucial concept is usually associated with **translucent sums/types**.

Consider these two signatures:

```sml
sig
    type t
end
```

and:

```sml
sig
    type t = int
end
```

The first says:

\[
t:\mathrm{Type}
\]

The second says:

\[
t:\mathrm{Type}
\quad\text{and}\quad
t=int.
\]

An ML module system needs both.

More importantly, it frequently needs something in between: a module type that abstracts some components while preserving other type equalities.

This property was called **translucency**.

Instead of thinking only in terms of completely transparent records or completely opaque existential packages, signatures can carry controlled type information.

This makes expressions like:

\[
X.t = Y.t
\]

first-class information in the static semantics.

That dramatically improves treatment of sharing.

---

# 7. Leroy: manifest types

At almost exactly the same time, Xavier Leroy developed another extremely influential approach.

The key paper is:

**Xavier Leroy — _Manifest Types, Modules, and Separate Compilation_ (1994).**

A manifest type is essentially this:

```ml
sig
    type t = int
end
```

rather than merely:

```ml
sig
    type t
end
```

The important insight is that **type equations belong directly in signatures**.

You can therefore say:

```text
type t = X.t
```

rather than relying on a separate and increasingly complicated sharing mechanism.

This idea became foundational to OCaml's module system.

It also gives a particularly clean treatment of separate compilation.

If an imported module's signature says:

```text
type t = M.u
```

the compiler does not need access to its implementation to know that equality.

That is exactly the sort of information higher-order functors require.

---

# 8. Leroy's applicative functors

The next major step is especially important:

**Xavier Leroy — _Applicative Functors and Fully Transparent Higher-Order Modules_ (1995).**

This deals directly with the question:

```text
F(X).t
```

versus:

```text
F(X).t
```

Should those names mean the same type?

There are two fundamentally different answers.

## Generative semantics

Each application produces fresh abstract type identities:

\[
F(X)_1.t \neq F(X)_2.t.
\]

That is close to traditional SML behavior.

Conceptually:

```text
functor application = allocate fresh type names
```

---

## Applicative semantics

The type identity is determined by the functor and argument:

\[
F(X).t = F(X).t.
\]

You can think of `F(X).t` as a genuine type-level function application.

Therefore:

\[
F : S \rightarrow T
\]

has an associated static function:

\[
F_{\text{type}}(X_{\text{type}}).
\]

This makes higher-order modules dramatically easier to reason about.

For example:

```text
structure A = F(X)
structure B = F(X)
```

can have:

```text
A.t = B.t
```

because both identities come from:

\[
F(X).t.
\]

This became an important part of the intellectual foundation of the OCaml module system.

---

# 9. Why applicativity is such a big deal

Consider a higher-order functor:

```text
functor Twice
    (functor F (X : S) : S)
    (X : S)
=
    F(F(X))
```

At the type level you're effectively constructing:

\[
F_{\text{type}}
  (F_{\text{type}}(X)).
\]

Under applicative semantics, that's ordinary static functional composition.

Higher-order functors become much more nearly what one initially expects:

\[
(S\rightarrow S)\rightarrow(S\rightarrow S).
\]

Under generative semantics, however, every application might manufacture new type identities.

Then:

\[
F(X)
\]

doesn't behave like an ordinary mathematical function.

It behaves more like:

\[
F : S \rightarrow \mathrm{Fresh}(T).
\]

In modern terminology, one might say that type generation is an **effect**.

That distinction turns out to be deeply illuminating.

---

# 10. Generativity did not disappear

An important misconception is that applicative functors “solved” generativity by removing it.

They don't.

Generativity is useful.

Consider:

```sml
functor MakeId () =
struct
    datatype id = ID of int
end
```

You might deliberately want:

```text
A.id ≠ B.id
```

for:

```sml
structure A = MakeId()
structure B = MakeId()
```

because this statically prevents identifiers belonging to two domains from getting mixed up.

The later theory instead makes a conceptual distinction:

> Function application itself does not inherently have to create types.

versus:

> Explicit abstraction/generative constructs can create types.

That is much cleaner.

In a contemporary design you might make generativity explicit through:

- datatype creation;
- opaque sealing;
- existential unpacking;
- an explicitly generative functor.

This separation is one reason newer systems are easier to explain.

---

# 11. Leroy's later work on generativity and sharing

Leroy subsequently developed a more syntactic treatment of type generation and sharing, notably in work such as:

**_A Syntactic Theory of Type Generativity and Sharing_.**

The significance is methodological.

Earlier semantic descriptions frequently involved things resembling:

- stamps;
- semantic type identities;
- environments containing abstract objects;
- side conditions concerning freshness.

Leroy showed that much of this behavior could be explained syntactically using type paths and equations.

That matters for both:

- formal metatheory;
- compiler implementation.

It helped move the subject away from “special ML magic.”

---

# 12. Shao and fully syntactic signatures

Zhong Shao and collaborators pursued another important line in the late 1990s: making module signatures themselves have a thoroughly syntactic representation.

A representative work is:

**Zhong Shao — _Transparent Modules with Fully Syntactic Signatures_.**

The broader goal was important for compilers such as SML/NJ:

> Can all the static information necessary for sophisticated modules be represented explicitly in an intermediate type language?

The answer increasingly became yes.

This work interacts with:

- singleton kinds;
- type constructors;
- intensional type analysis;
- typed intermediate languages.

Instead of a compiler carrying mysterious semantic stamps around, it can encode identities and equalities in a rich type language.

This is especially attractive for typed compiler IRs.

---

# 13. Singleton kinds

Singleton kinds are one of the elegant ideas that emerged from this line of research.

Ordinarily:

\[
t : \mathrm{Type}
\]

means "`t` is some type."

A singleton kind can express:

\[
t : S(\mathrm{int})
\]

meaning:

> `t` is a type, and it is specifically equal to `int`.

Similarly, if:

```text
X.t
```

is known, you can express that another component has exactly that identity.

A manifest specification:

```sml
type t = X.t
```

can therefore be given a type-theoretic interpretation rather than needing a module-specific equality mechanism.

This helps collapse several seemingly separate ML mechanisms into ordinary type theory.

---

# 14. Dreyer, Crary and Harper: higher-order modules as a mature calculus

A major milestone came with:

**Derek Dreyer, Karl Crary, Robert Harper — _A Type System for Higher-Order Modules_ (2003).**

By this stage, the subject had become much more mature.

The goal was no longer merely:

> “Can we somehow have higher-order functors?”

but to give a systematic account combining things like:

- higher-order functors;
- abstraction;
- transparency;
- generative type creation;
- type sharing;
- phase separation;
- decidable static semantics.

This line of work is particularly relevant to the claim you've heard.

Around this period it becomes quite reasonable to say:

> There is no longer a fundamental theoretical obstacle to adding higher-order modules to an ML-like language.

There are still **language-design choices**, but not a mystery about whether coherent semantics can exist.

---

# 15. Dreyer's thesis: generativity as an effect

Derek Dreyer's 2005 thesis,

**_Understanding and Evolving the ML Module System_**,

is probably one of the best single sources if you want the intellectual story rather than just individual calculi.

One particularly powerful perspective is to treat type generation somewhat like a computational effect.

Suppose:

```text
F : S -> T
```

contains no generative operation.

Then `F` can behave applicatively:

\[
F(X).t = F(X).t.
\]

But if it allocates a fresh abstract type, its behavior is generative.

This is analogous to the difference between:

```text
f x
```

as a pure computation and:

```text
newRef()
```

as an effectful computation.

The analogy isn't literally identical, but it's conceptually useful.

It tells you that **higher-order functions were never the real problem**.

The difficult interaction was:

\[
\text{higher order}
+
\text{fresh type names}.
\]

Once type generation is modeled explicitly, the system becomes much cleaner.

---

# 16. A deeper reinterpretation: modules compile into ordinary type theory

The research then takes another significant turn.

Rather than constructing ever more specialized module calculi, ask:

> Can ML modules simply be elaborated into an existing typed lambda calculus?

That leads to work involving:

- System F;
- System Fω;
- existential types;
- records;
- type constructors;
- singleton types/kinds.

The general translation looks roughly like this.

An abstract module:

```sml
sig
    type t
    val x : t
end
```

resembles:

\[
\exists \alpha.\{\;x:\alpha\;\}
\]

A transparent module:

```sml
sig
    type t = int
    val x : t
end
```

resembles:

\[
\{x:\mathrm{int}\}.
\]

A functor resembles a function over such packages.

Higher-order functors become ordinary higher-order functions.

That is an enormous conceptual simplification.

---

# 17. F-ing Modules

A major culmination of this approach is:

**Andreas Rossberg, Claudio Russo, Derek Dreyer — _F-ing Modules_ (2014).**

The deliberately silly title refers to **System F**.

The central message is profound:

> A surprisingly rich ML module system can be explained by translation into fairly conventional polymorphic type theory.

The source language may contain:

- structures;
- signatures;
- functors;
- abstract types;
- transparent types;
- higher-order modules.

But these don't require an entirely independent semantic universe.

They can be elaborated into combinations of:

\[
\forall,\quad
\exists,\quad
\rightarrow,\quad
\times,\quad
F_\omega\text{-style type operators}.
\]

That substantially strengthens the claim that higher-order modules are now understood.

Rather than merely possessing one complicated semantic definition, we know how to reduce them to more foundational constructs whose metatheory is already understood.

---

# 18. 1ML: erase the core/module distinction

Andreas Rossberg then pushed the idea significantly further with:

**_1ML — Core and Modules United_**.

This is particularly relevant to the discussion you were having about letting the **core language manipulate modules**.

Traditional ML has two languages:

```text
Core language
-------------
values
functions
datatypes

Module language
---------------
structures
signatures
functors
```

1ML asks:

> Why have two languages at all?

Under 1ML, ordinary functions and functors become instances of essentially the same mechanism.

Instead of:

```text
core function:
    value -> value

module functor:
    module -> module
```

you move toward one language in which modules are just sufficiently rich records/packages.

This gives you:

\[
\text{functions}
=
\text{functors}
\]

at the conceptual level.

That naturally permits:

- higher-order modules;
- first-class modules;
- module-returning functions;
- structures containing module-level abstractions;
- ordinary combinators over modules.

This is perhaps the strongest evidence for the “it is now clean” interpretation.

The price is that 1ML is considerably further from SML’97.

---

# 19. So why didn't SML’97 have higher-order functors?

The chronology makes the historical answer interesting.

SML’97 was published **after**:

- the phase-distinction work;
- translucent-type research;
- manifest types;
- Leroy's applicative-functor work.

So:

> “SML’97 has first-order functors because higher-order functors had not yet been invented.”

is false.

A more accurate statement is:

> The original Standard ML module system was designed before there was a settled, simple theory of higher-order ML modules, and SML’97 deliberately remained conservative rather than replacing the established module semantics with one of several relatively new research designs.

Standardization matters here.

SML’97 was not intended to be “take every promising PL research result from 1994–1996 and incorporate it.”

There were significant unresolved design choices.

Most importantly:

### Generative or applicative functors?

This changes observable type equality.

### How much transparency?

Manifest types and translucent signatures alter how abstraction is represented.

### How are functor types written?

You need another substantial layer of signature syntax.

### Do higher-order functors remain second class?

Or should modules and the core language interact?

### How does signature inference work?

The more dependent information you expose, the harder reconstruction becomes.

### How much of the existing Definition changes?

Standard ML had already committed to a carefully specified static semantics based substantially around generative type identities.

A conservative standard had good reasons not to replace it wholesale.

So “not fully understood” is defensible if interpreted as:

> there was no sufficiently mature, agreed-upon engineering and language-design story.

It is misleading if interpreted as:

> the PL community didn't know how to formalize higher-order modules.

They did.

---

# 20. OCaml became the important practical experiment

OCaml is significant because it adopted several ideas from this research tradition, especially:

- manifest type equations;
- applicative behavior;
- path-dependent module types;
- higher-order functors.

You can effectively express types such as:

```text
functor (X : S) -> T
```

and therefore functors taking functors.

This provided decades of practical evidence that higher-order ML modules are usable rather than merely theoretically elegant.

OCaml nevertheless retains an important distinction between:

- its core language;
- its module language.

So it is not 1ML.

That middle position has turned out to be quite effective.

---

# 21. Higher-order versus first-class is still an important design choice

For Rune, I would treat these as separate extensions.

### SML’97

Approximately:

\[
\text{Structure}
\rightarrow
\text{Structure}
\]

---

### Higher-order SML

Add:

\[
(\text{Structure}\rightarrow\text{Structure})
\rightarrow
\text{Structure}
\]

and:

\[
\text{Structure}
\rightarrow
(\text{Structure}\rightarrow\text{Structure}).
\]

Modules still exist in a separate compile-time language.

---

### First-class modules

Allow module packages to flow through the core language:

\[
\text{value containing module}
\]

and perhaps:

```sml
fun choose b =
    if b then module Linux
    else module Windows
```

This requires existential packaging or an equivalent mechanism.

---

### 1ML-style language

Eliminate much of the distinction:

\[
\text{module function}
\approx
\text{ordinary function}.
\]

That is a much bigger language change.

---

# 22. What is actually considered “solved” now?

There are several things for which we now have quite satisfying theories.

**Dependency:** handled with dependent module signatures, type paths, singleton kinds, or equivalent encodings.

**Transparency:** handled with manifest types, translucent types, refinements, and strengthening.

**Abstraction:** modeled through existential quantification/sealing.

**Higher-order functors:** modeled as higher-order dependent functions or translated to polymorphic functions.

**Applicative functors:** have a clear semantics based on stable module paths/type-level application.

**Generativity:** can be given an explicit account based on existential introduction/fresh type identity.

**Separate compilation:** manifest signatures and explicit type equations make this tractable.

**Compilation:** sophisticated module languages can be elaborated into typed intermediate languages such as variants of System Fω.

These are no longer open foundational questions.

---

# 23. What is *not* magically solved

There are nevertheless real design tradeoffs.

If you combine absolutely everything:

\[
\begin{aligned}
&\text{first-class modules}\\
+&\text{higher-order modules}\\
+&\text{generativity}\\
+&\text{recursive modules}\\
+&\text{impredicative polymorphism}\\
+&\text{dependent typing}\\
+&\text{type inference}
\end{aligned}
\]

you can quickly reach serious decidability and inference problems.

So modern systems deliberately restrict some dimension.

This is why OCaml, 1ML, SML/NJ extensions, Haskell Backpack and dependent languages don't all converge on exactly the same design.

The underlying theory is mature; the **design space remains real**.

---

# 24. The main research lineage

If I were reading this literature specifically for your compiler work, I'd use roughly this order:

| Period | Work | Main idea |
|---|---|---|
| 1980s | MacQueen, *Modules for Standard ML* | Original ML module architecture |
| 1980s | MacQueen, *Using Dependent Types to Express Modular Structure* | Module signatures as dependent types |
| 1990 | Harper, Mitchell, Moggi, *Higher-Order Modules and the Phase Distinction* | Separate static and dynamic module components |
| 1994 | Harper & Lillibridge, *A Type-Theoretic Approach to Higher-Order Modules with Sharing* | Translucent types and higher-order sharing |
| 1994 | Leroy, *Manifest Types, Modules, and Separate Compilation* | Type equations directly in signatures |
| 1995 | Leroy, *Applicative Functors and Fully Transparent Higher-Order Modules* | Stable type identity through functor application |
| mid-1990s | Leroy, *A Syntactic Theory of Type Generativity and Sharing* | Syntactic account of freshness/sharing |
| late 1990s | Shao, *Transparent Modules with Fully Syntactic Signatures* | Explicit type-theoretic static representation |
| ~2000 | Harper & Stone, *A Type-Theoretic Interpretation of Standard ML* | Relate SML semantics systematically to type theory |
| 2000s | Russo, work on first-class structures | Modules crossing into core language |
| 2003 | Dreyer, Crary, Harper, *A Type System for Higher-Order Modules* | Mature treatment of HO modules + abstraction/generativity |
| 2005 | Dreyer, *Understanding and Evolving the ML Module System* | Unified analysis, generativity and advanced modules |
| 2014 | Rossberg, Russo, Dreyer, *F-ing Modules* | Elaborate ML modules into System F-style calculi |
| 2015+ | Rossberg, *1ML — Core and Modules United* | Collapse core/module distinction |

There is a fairly clear progression:

\[
\boxed{
\begin{array}{c}
\text{special-purpose ML module machinery}\\
\downarrow\\
\text{dependent module calculus}\\
\downarrow\\
\text{manifest/translucent types}\\
\downarrow\\
\text{higher-order + applicative modules}\\
\downarrow\\
\text{typed elaboration into System F}_\omega\\
\downarrow\\
\text{core/module unification}
\end{array}}
\]

That progression is more significant than any single paper.

---

# 25. What I would take from this for Rune

For an **SML’97-compatible language with modern improvements**, I would not immediately jump all the way to 1ML.

There is a particularly attractive middle point:

\[
\boxed{
\text{SML structures}
+
\text{manifest type equations}
+
\text{higher-order functors}
+
\text{explicit generativity}
}
\]

Conceptually, give functors genuine module types:

```sml
functor type MAP =
    functor (X : S) -> T
```

so that:

```sml
functor Compose
    (F : functor (X : B) -> C)
    (G : functor (X : A) -> B)
    (X : A) =
F(G(X))
```

is completely ordinary.

Then separate:

```text
pure/applicative module computation
```

from:

```text
fresh abstract-type creation
```

rather than making every functor invocation implicitly responsible for both.

Internally, your compiler can make the phase distinction extremely explicit:

```text
Module
  ├── Static component
  │     types
  │     type constructors
  │     equality information
  │     signatures
  │
  └── Dynamic component
        values
        functions
        runtime initialization
```

A higher-order functor consequently becomes two related functions:

\[
F_s : S_s \rightarrow T_s
\]

and

\[
F_d : S_d \rightarrow T_d
\]

subject to the dependencies recorded by the static component.

That is a much cleaner compiler architecture than treating functors as special elaborator macros.

And it connects directly with the idea you raised earlier about the **core language manipulating modules**. The 1ML/F-ing-Modules research effectively says that this isn't an absurd direction at all: taken far enough, there is a rigorous sense in which the separation between “function” and “functor” is largely an artifact of traditional ML language design rather than a deep semantic necessity.

So I would characterize the claim you heard as:

> **Historically directionally correct, but chronologically exaggerated.** Early Standard ML intentionally used a comparatively simple first-order module system while the interaction of higher-order modules, sharing, abstraction and generativity was still an active research problem. By the mid-1990s strong solutions existed; by the early 2000s the theory was mature; and work such as *F-ing Modules* and *1ML* later showed that surprisingly rich higher-order ML module systems can be given very clean foundations in ordinary polymorphic type theory.

The really interesting question for Rune is therefore no longer **“can SML cleanly have higher-order modules?”** It can. The question is **which point in the design space to choose: SML/NJ-style higher-order functors, OCaml-style applicative modules, an explicit generativity system, or the much more radical 1ML-style unification of core and modules.**

I can give you a three-question exercise here that uses small module fragments to distinguish generative, applicative, and genuinely higher-order functor semantics.

---


can you give me a haskell data type for a clean higher-order module system with applicative functors but also the ability to still represent sml97 first-order generative functors. so internally we can use the clean calculus but still remain 100% sml97 semantics at the surface with the option to expose the higher-order calculus as a language extension

---

Yes. I would make **generativity an effect of module computation, not a different kind of function**.

That gives you one clean higher-order calculus:

\[
\Pi X:S \xrightarrow{\epsilon} T
\]

where \(\epsilon\) says whether applying the functor can generate fresh type identities:

\[
\epsilon \in \{\text{Stable},\text{Fresh}\}.
\]

`Stable` functors are applicative. `Fresh` functors have SML-style generative application semantics. Both can be passed to and returned from higher-order functors.

A concrete Haskell representation could look like this.

```haskell
{-# LANGUAGE DeriveFunctor #-}

module ModuleCore where

import Data.Text (Text)

newtype ModVar = ModVar Int
  deriving (Eq, Ord, Show)

newtype TyVar = TyVar Int
  deriving (Eq, Ord, Show)

newtype Label = Label Text
  deriving (Eq, Ord, Show)


-- Type constructors may themselves be higher-kinded.
data Kind
  = KType
  | KArrow Kind Kind
  deriving (Eq, Show)


-- Whether applying a functor may generate fresh type identities.
--
-- Stable:
--     F(X) is a valid stable module path.
--
-- Fresh:
--     application is a computation and must be bound before its
--     generated type identities can be referenced.
data GenEffect
  = Stable
  | Fresh
  deriving (Eq, Ord, Show)


-- Stable module paths.
--
-- Crucially, application is allowed here only for Stable functors.
data ModPath
  = PVar  ModVar
  | PProj ModPath Label
  | PApp  ModPath ModPath
  deriving (Eq, Ord, Show)


data Ty
  = TVar TyVar

  -- M.t
  | TProj ModPath Label

  | TApp Ty Ty
  | TArrow Ty Ty
  | TTuple [Ty]
  | TRecord [(Label, Ty)]

  | TInt
  | TBool
  | TString
  | TUnit

  deriving (Eq, Show)


data TypeRequirement
  = AnyType
  | EqualityType          -- SML eqtype
  deriving (Eq, Show)


data TypeSpec
  = Abstract TypeRequirement Kind

  -- type t = ...
  | Manifest TypeRequirement Kind Ty

  deriving (Eq, Show)


data Spec
  = SType   Label TypeSpec
  | SVal    Label Ty

  -- structures and functors use the same namespace/class of component
  -- in the core calculus.
  | SModule Label ModType

  deriving (Eq, Show)


data Signature =
  Signature [Spec]
  deriving (Eq, Show)


data ModType

  -- Ordinary structure signature.
  = MTSig Signature

  -- Dependent higher-order functor type:
  --
  --   Π X : arg. result
  --
  -- result may mention X through paths such as X.t.
  --
  -- The GenEffect describes what happens when this particular arrow
  -- is applied.
  | MTPi
      ModVar
      ModType
      GenEffect
      ModType

  -- Explicit existential abstraction.
  --
  -- Useful as the core representation of opaque abstraction.
  --
  --   ∃ α : k. M
  | MTExists
      TyVar
      Kind
      ModType

  deriving (Eq, Show)


data SealMode
  = Transparent
  | Opaque
  deriving (Eq, Show)


data ModExpr

  -- Reference to a stable module.
  = MPath ModPath

  | MStruct [Decl]

  -- There is only ONE functor constructor.
  --
  -- Applicative/generative behaviour is inferred/checked through
  -- GenEffect, not encoded as two different lambda constructs.
  | MFunctor
      ModVar
      ModType
      ModExpr

  -- General module application.
  --
  -- Only some applications can subsequently be represented as PApp.
  | MApp
      ModExpr
      ModExpr

  -- Bind the result of an arbitrary module computation.
  --
  -- This is particularly important for Fresh applications:
  --
  --     let module A = F(X) in ...
  --
  -- A is stable after binding even though F(X) itself is not a
  -- stable applicative path.
  | MLet
      ModVar
      ModExpr
      ModExpr

  -- Explicit creation of a fresh nominal type identity:
  --
  --     ν α : k . M
  --
  -- This is the primitive underlying SML datatype generativity,
  -- abstype, opaque sealing, etc.
  | MNewType
      TyVar
      Kind
      ModExpr

  -- Can exist in an early core IR and be elaborated into MNewType /
  -- existential packaging.
  | MSeal
      SealMode
      ModType
      ModExpr

  deriving (Eq, Show)


data Decl
  = DType   Label Ty
  | DVal    Label CoreExpr
  | DModule Label ModExpr
  deriving (Eq, Show)


-- Placeholder for the ordinary SML core language.
data CoreExpr
  = EVar Text
  | EOther Text
  deriving (Eq, Show)
```

The most important part of that representation is not `MFunctor`. It is this distinction:

```haskell
data ModPath
  = PVar ModVar
  | PProj ModPath Label
  | PApp ModPath ModPath
```

versus:

```haskell
MApp :: ModExpr -> ModExpr -> ModExpr
```

They are intentionally different.

## 1. Applicative application is a path

Suppose:

```sml
applicative functor F (X : S) =
struct
    type t = X.t list
end
```

Internally it gets a type resembling:

```text
Π X : S -Stable-> T(X)
```

If `F` and `X` are stable paths, then:

```text
F(X)
```

itself has the stable path:

```haskell
PApp (PVar f) (PVar x)
```

Consequently:

```text
F(X).t
```

has a genuine type-level name:

```haskell
TProj
  (PApp (PVar f) (PVar x))
  (Label "t")
```

Another occurrence of:

```text
F(X).t
```

produces exactly the same syntax.

So:

\[
F(X).t = F(X).t
\]

essentially by normalization/path equality.

That is applicative functor semantics in an extremely concrete implementation form.

---

# 2. Generative application is not a path

An SML functor might be:

```sml
functor F (X : S) =
struct
    datatype t = K
end
```

Elaborate the datatype into explicit fresh-type creation:

```text
functor X : S =>
    ν α : Type .
    struct
        type t = α
        val K : α
    end
```

In the Haskell AST, approximately:

```haskell
MFunctor x s $
  MNewType alpha KType $
    MStruct
      [ DType (Label "t") (TVar alpha)
      , DVal  (Label "K") ...
      ]
```

The inferred arrow is:

```text
Π X : S -Fresh-> T
```

Now:

```sml
structure A = F(X)
structure B = F(X)
```

becomes approximately:

```haskell
MLet a
  (MApp (MPath (PVar f))
        (MPath (PVar x)))

  (MLet b
    (MApp (MPath (PVar f))
          (MPath (PVar x)))
    ...)
```

The first application executes:

```text
ν α₁
```

and the second executes:

```text
ν α₂
```

so:

\[
A.t = \alpha_1
\]

and:

\[
B.t = \alpha_2
\]

with:

\[
\alpha_1 \neq \alpha_2.
\]

Exactly the desired SML semantics.

Most importantly, there is **no**

```haskell
PApp (PVar f) (PVar x)
```

for this application.

`F(X)` isn't a stable path.

After you bind its result:

```text
structure A = F(X)
```

`A` becomes a path:

```haskell
PVar a
```

and therefore:

```text
A.t
```

is perfectly stable.

That distinction is the core of the design.

---

# 3. Don't make generativity mean “freshen every type”

This is an important subtlety if you want exact SML semantics.

Consider:

```sml
functor F (X : S) =
struct
    type t = X.t
end
```

Even under traditional SML generative functor semantics, applying it twice should not magically make `t` distinct:

```sml
structure A = F(X)
structure B = F(X)
```

Both contain:

```text
A.t = X.t
B.t = X.t
```

and hence:

\[
A.t = B.t.
\]

So `Fresh` should **not** mean:

> replace every result type by a fresh type.

It means:

> executing this module computation may execute `ν` operations.

Only explicit generative constructs generate identities.

This is why I prefer:

```haskell
MNewType
```

as the semantic primitive.

The effect merely tells you whether the application can safely participate in an applicative module path.

---

# 4. This makes SML datatypes especially clean

Source:

```sml
datatype tree
  = Leaf
  | Node of tree * tree
```

can elaborate approximately into:

```text
ν α : Type .
{
    type tree = α
    val Leaf : α
    val Node : α * α -> α
}
```

Of course your real datatype IR also needs constructor representation, recursion, equality status, runtime representation, etc.

But **from the module system's perspective**, the important operation is simply:

\[
\nu\alpha
\]

“create a new nominal type identity.”

This is a very useful primitive to have explicitly in the compiler.

---

# 5. Opaque sealing uses the same primitive

Consider:

```sml
structure M :> S =
struct
    type t = int
    ...
end
```

If `S` contains:

```sml
type t
```

then opaque sealing turns the implementation's:

```text
t = int
```

into a fresh external identity.

Conceptually:

```text
ν α .
    package {
        type t = α
        ...
    }
```

with the internal coercion relating `α` to the implementation representation.

The module type is naturally existential:

\[
\exists\alpha:\mathrm{Type}.\,
\{
  t=\alpha,\ldots
\}.
\]

That's why I included:

```haskell
MTExists TyVar Kind ModType
```

in the type language.

You could compile `MSeal Opaque` away early and have only:

```haskell
MNewType
MTExists
```

in your real typed module IR.

I would probably do exactly that.

---

# 6. Transparent sealing doesn't generate anything

For:

```sml
structure M : S =
struct
    type t = int
end
```

the restriction may hide some components from the visible interface, but it doesn't need to manufacture a nominal identity.

If the static semantics permits the equality to propagate, internally you retain:

```text
M.t = int
```

as a manifest equation.

So:

```haskell
Transparent
```

is essentially signature restriction/coercion.

While:

```haskell
Opaque
```

introduces existential abstraction and possibly `ν`.

This fits the established ML theory very naturally.

---

# 7. Higher-order functors need no additional mechanism

Now we get the payoff.

Say you want:

```sml
functor Compose
    (F : functor (X : B) -> C)
    (G : functor (X : A) -> B)
    (X : A) =
    F(G(X))
```

The module type is just nested `MTPi`.

For applicative `F` and `G`:

```haskell
composeType =
  MTPi f
    (MTPi x B Stable C)
    Stable
    (MTPi g
      (MTPi x A Stable B)
      Stable
      (MTPi x A Stable C))
```

Mathematically:

\[
\Pi F:(\Pi X:B \to C).
\Pi G:(\Pi X:A \to B).
\Pi X:A.
C
\]

Nothing special happens because `F` and `G` themselves are functors.

The calculus is genuinely higher order.

---

# 8. You can pass generative functors too

Suppose you have a higher-order combinator that accepts an SML-style functor:

```text
F : Π X:S -Fresh-> T
```

Then its type is simply:

```haskell
MTPi f
  (MTPi x S Fresh T)
  ...
```

So higher-order functionality and SML generativity are completely orthogonal.

You can have:

```text
Stable functor taking Stable functor

Stable functor taking Fresh functor

Fresh functor taking Stable functor

Fresh functor returning Fresh functor
```

etc.

For example:

\[
\Pi F:(S\xrightarrow{Fresh}T).
U
\]

is no harder than:

\[
\Pi F:(S\xrightarrow{Stable}T).
U.
\]

This is one of the strongest arguments for representing generativity as an effect on the arrow.

---

# 9. An outer functor may be applicative while returning a generative one

This distinction becomes useful quickly.

Suppose:

```sml
applicative functor Make (X : S) =
struct
    functor F (Y : T) =
    struct
        datatype u = U
    end
end
```

The outer application creates no fresh identity.

Its type can therefore be:

\[
\Pi X:S \xrightarrow{Stable}
    \{
       F :
       \Pi Y:T \xrightarrow{Fresh} U
    \}.
\]

That is:

```haskell
MTPi x S Stable $
  MTSig $
    Signature
      [ SModule (Label "F")
          (MTPi y T Fresh U)
      ]
```

So:

```text
Make(X)
```

is applicative.

But:

```text
Make(X).F(Y)
```

is generative because the inner arrow is `Fresh`.

This is much cleaner than labeling entire functor-containing structures “generative.”

Generativity belongs precisely where the fresh type creation happens.

---

# 10. You can infer the effect

I would not normally make programmers annotate:

```text
Stable
Fresh
```

on every functor.

Instead infer it from the module body.

Something roughly like:

\[
\Gamma\vdash M:T\;!\;\epsilon
\]

where:

```text
ε = Stable
```

means no escaping fresh type identity is allocated, and:

```text
ε = Fresh
```

means one may be.

Basic rules:

```text
path                    Stable

struct { ... }          join of component effects

ν α . M                 Fresh

transparent seal        effect(M)

opaque seal             Fresh, if abstraction creates identities

functor X => M          constructing the functor itself is Stable
                        but its arrow records effect(M)

F(X)                    effect recorded on F's arrow
```

The last two are particularly important.

Creating:

```text
functor X => ν α . ...
```

doesn't itself generate α.

Only **applying** it does.

Therefore the value containing the functor can be stable while its arrow is:

```text
-Fresh->
```

This is exactly analogous to:

```haskell
f :: X -> IO Y
```

where obtaining `f` is pure; invoking the computation isn't.

---

# 11. I'd actually call the effect `Gen`, not `Fresh`

For the implementation, something like:

```haskell
data GenEffect
  = Applicative
  | Generative
```

is more immediately readable.

But semantically I slightly prefer:

```haskell
data TypeEffect
  = NoFreshTypes
  | MayFreshTypes
```

because it prevents an easy conceptual mistake.

An applicative functor can still have ordinary runtime effects:

```sml
val x = print "hello"
```

or create references, perform initialization, etc.

**Applicative means applicative with respect to static type identity.**

It absolutely should not mean runtime purity.

So perhaps:

```haskell
data TypeGen
  = NoTypeGeneration
  | MayGenerateTypes
```

would be the least ambiguous compiler terminology.

---

# 12. SML’97 can then be a restricted surface language

This is where the architecture becomes particularly attractive.

Your parser/elaborator can have something like:

```haskell
data LanguageMode
  = SML97
  | RuneModules
```

In `SML97` mode enforce:

- functors may only accept structures;
- functors may not be structure components where SML forbids them;
- functors may not be passed as functor arguments;
- functors may not be returned as results;
- surface functor syntax has traditional SML behavior;
- ordinary SML generative constructs introduce `MNewType`;
- SML signature matching/sharing rules are preserved.

But immediately elaborate into the general calculus.

So this:

```sml
functor F (X : S) =
struct
    datatype t = C
end
```

becomes the same internal representation you would use if Rune's extended module language had written something like:

```text
functor F (X : S) =>
    newtype α in
    {
        type t = α
        ...
    }
```

There is no second SML-specific module implementation.

That's exactly what you want.

---

# 13. For maximum SML compatibility, distinguish two things

I'd actually keep these separate internally:

```haskell
data ArrowMode
  = ApplicativeArrow
  | GenerativeArrow
```

and:

```haskell
MNewType
```

because they answer different questions.

`MNewType` says:

> this point actually creates a fresh identity.

`GenerativeArrow` says:

> application of this functor is not allowed to serve as a stable applicative module path.

That distinction lets you reproduce SML conservatively.

For example:

```sml
functor F (X : S) =
struct
    type t = X.t
end
```

may get:

```text
Π X:S -Generative-> { type t = X.t }
```

even though there is no `MNewType`.

The restriction means you don't accidentally expose an extra OCaml-style applicative equality through the expression `F(X)` itself.

But after binding:

```sml
structure A = F(X)
structure B = F(X)
```

the manifest result equations still imply:

\[
A.t=X.t=B.t.
\]

Thus you don't fabricate inequality either.

This is the safest route to **100% SML semantics**.

---

# 14. So I might refine the Haskell type slightly

I'd use:

```haskell
data ArrowSemantics
  = ApplicativeArrow
  | GenerativeArrow
  deriving (Eq, Ord, Show)

data ModType
  = MTSig Signature
  | MTPi
      ModVar
      ModType
      ArrowSemantics
      ModType
  | MTExists
      TyVar
      Kind
      ModType
```

And independently retain:

```haskell
MNewType
    :: TyVar
    -> Kind
    -> ModExpr
    -> ModExpr
```

This gives you two independent axes:

| Arrow | Body contains `ν` | Meaning |
|---|---:|---|
| Applicative | no | normal applicative functor |
| Generative | no | SML-style application barrier, but no actual fresh result type |
| Generative | yes | normal SML datatype/opaque-abstraction case |
| Applicative | yes | reject if freshness escapes |

That last case is useful.

If someone writes:

```text
applicative functor F(X) =
    newtype α in ...
```

and `α` escapes through the result signature, the compiler reports:

```text
Applicative functor result depends on a freshly generated type.
```

If the fresh type doesn't escape, you could potentially allow it, depending on how sophisticated you want your effect system to be.

---

# 15. The path rule becomes extremely simple

The crucial typing rule is roughly:

\[
\frac{
\Gamma\vdash F :
\Pi X:S\xrightarrow{Applicative}T
\qquad
\Gamma\vdash P:S
}{
\Gamma\vdash F(P):T[P/X]
}
\]

and `F(P)` is a **path**.

But for:

\[
F :
\Pi X:S\xrightarrow{Generative}T
\]

there is no corresponding path formation rule.

Instead:

\[
\mathrm{let\ module}\ A=F(P)\ \mathrm{in}\ M
\]

introduces the stable path:

\[
A.
\]

This is the whole applicative/generative distinction reduced to one static-semantic rule.

That's about as clean as it gets.

---

# 16. Higher-order signatures become straightforward

Suppose the extension supports:

```sml
signature FUNCTOR =
sig
    functor Apply (X : S) : T
end
```

Internally there is no special `functor spec`.

It's simply:

```haskell
SModule
  (Label "Apply")
  (MTPi x S ApplicativeArrow T)
```

Likewise an ordinary nested module:

```sml
structure X : S
```

is:

```haskell
SModule (Label "X") S
```

So a signature contains **module-valued components**, some of whose module types happen to be Π-types.

That removes yet another first-order SML special case.

---

# 17. This also naturally gives you partial application

Suppose:

\[
F :
\Pi X:A.
\Pi Y:B(X).
C(X,Y).
\]

Then:

```text
F(X)
```

has type:

\[
\Pi Y:B(X).C(X,Y).
\]

It's simply a functor value.

There is no reason to invent multi-argument functor machinery.

Your source syntax:

```sml
functor F
    (X : A)
    (Y : B) =
...
```

can be sugar for:

```text
functor X : A =>
    functor Y : B =>
        ...
```

This would be a nice extension for Rune because it follows directly from the calculus.

---

# 18. The full conceptual core is surprisingly small

Ignoring the ordinary value language, your real core calculus can almost be reduced to:

```text
Types
─────

T ::= signature
    | Π X:T -a-> T
    | ∃ α:K . T


Stable paths
────────────

P ::= X
    | P.l
    | P(P)          -- applicative arrows only


Module expressions
──────────────────

M ::= P
    | { declarations }
    | λ X:T . M
    | M M
    | let X = M in M
    | ν α:K . M
```

with:

```text
a ::= applicative
    | generative
```

and structures containing:

```text
type l = τ
val  l = e
module l = M
```

That's enough to express the essence of:

- SML structures;
- SML functors;
- generative datatypes;
- opaque abstraction;
- applicative functors;
- higher-order functors;
- module components that are themselves functors;
- functors returning functors;
- dependent result signatures;
- stable type projection.

That is a much more attractive internal language than literally encoding the SML’97 module grammar.

---

# 19. I would use three module IR stages in the compiler

For Rune specifically, I would probably structure the compiler as:

```text
SML/Rune surface modules
        │
        ▼
Desugared module AST
        │
        │ resolves signatures,
        │ sharing, where-type,
        │ SML restrictions
        ▼
Higher-order module calculus
        │
        │ Π
        │ stable paths
        │ ν
        │ existential abstraction
        ▼
Typed core language / System Fω-ish IR
```

The middle layer would look very much like the Haskell representation above.

Then ultimately:

```text
structure
functor
signature
sharing
opaque ascription
```

can disappear from the runtime IR.

For example:

```text
functor
```

eventually becomes an ordinary closure/function;

```text
structure
```

becomes a record;

```text
abstract type
```

becomes purely static information;

```text
ν
```

is normally compile-time nominal identity generation, not runtime allocation.

That provides a very clean separation between module elaboration and your bytecode VM.

---

## The central design

I would therefore build Rune around these four primitives:

```haskell
MTPi       -- arbitrary higher-order dependent functor types
PApp       -- applicative/stable functor application
MApp       -- general module application
MNewType   -- explicit nominal type generation
```

plus an arrow annotation:

```haskell
ApplicativeArrow | GenerativeArrow
```

Then make **SML’97 a syntactic/semantic restriction on this richer IR**, rather than making the richer module system an extension bolted onto an SML-specific implementation.

That has a nice theoretical interpretation:

\[
\boxed{
\text{SML generative functor}
=
\text{ordinary higher-order function}
+
\text{non-applicative arrow}
+
\text{explicit } \nu\text{-bound type generation}
}
\]

while:

\[
\boxed{
\text{modern applicative functor}
=
\text{ordinary higher-order function}
+
\text{stable path application}
}
\]

The two systems are then not competing module calculi at all. They are two points in one calculus. That is probably the architecture I would choose for Rune.

---

i feel there is a close relation to haskell's newtype. i never liked this construct as it prented to be a wrapped datatype but the constructor is not present at runtime so semantics ar subtly different. could we replace it in Rune with a 'generative type' freshtype that has the fresh effect?

---

Yes. I think that is a better construct for Rune than Haskell's `newtype`, especially because it fits directly into the module calculus we just designed.

The essential idea would be:

> `freshtype` creates a new nominal type identity, while optionally declaring that the new type has the same runtime representation as an existing type.

So rather than pretending there is a datatype constructor that happens to disappear during compilation, the language says exactly what it means.

I would distinguish three constructs:

```sml
type UserId = int
```

ordinary alias:

\[
UserId \equiv int
\]

```sml
freshtype UserId repr int
```

fresh nominal identity, same representation:

\[
UserId \not\equiv int
\]

but:

\[
UserId \approx_{\mathrm{repr}} int
\]

and:

```sml
datatype UserId = UserId of int
```

a genuine datatype with a genuine constructor and datatype semantics.

That gives Rune a very clean three-way distinction.

| Construct | New nominal identity | Runtime representation | Constructor |
|---|---:|---|---:|
| `type T = U` | no | same | no |
| `freshtype T repr U` | yes | same | no |
| `datatype T = C of U` | yes | determined by datatype | yes |

That is much closer to what programmers usually want to know.

## Why this is related to Haskell `newtype`

Haskell:

```haskell
newtype UserId = UserId Int
```

really has two important properties:

1. `UserId` is nominally different from `Int`.
2. Its runtime representation is exactly that of `Int`.

The source-level constructor:

```haskell
UserId :: Int -> UserId
```

is somewhat misleading operationally because GHC erases it.

Conceptually the important object isn't really the constructor. It is a proof of **representational equality**:

\[
UserId \approx_R Int.
\]

Indeed, modern GHC's `Coercible` machinery makes this explicit internally.

Rune could expose the concept directly instead:

```sml
freshtype UserId repr int
```

There is simply no constructor to begin with.

That means there is no semantic fiction that:

```text
UserId 42
```

constructs an object.

It doesn't.

There is only a static type boundary.

---

# `freshtype` as ν

It fits perfectly with the `MNewType` operation from our previous module calculus.

The core construct is essentially:

\[
\nu \alpha : K . M
\]

meaning:

> create a fresh nominal type identity α within M.

For a representation-preserving type:

\[
\nu \alpha \mathrel{\mathrm{repr}} \tau . M
\]

meaning:

> create a fresh nominal type α whose runtime representation is τ.

I'd represent that approximately as:

```haskell
data FreshType = FreshType
  { freshVar  :: TyVar
  , freshKind :: Kind
  , freshRepr :: Maybe Ty
  }
```

and:

```haskell
data ModExpr
  = ...
  | MFreshType
      FreshType
      ModExpr
```

So:

```sml
freshtype UserId repr int
```

might elaborate into:

```text
ν UserId repr int . ...
```

Internally you get two facts:

```text
UserId : Type
```

and:

```text
Repr UserId = int
```

but crucially **not**:

```text
UserId = int
```

That distinction should be fundamental in Rune's type system.

---

# Two notions of equality

I'd explicitly distinguish:

\[
\tau \equiv \sigma
\]

for nominal/definitional type equality, and:

\[
\tau \approx_R \sigma
\]

for representation equality.

For example:

```sml
type A = int
```

gives:

\[
A \equiv int
\]

while:

```sml
freshtype B repr int
```

gives:

\[
B \not\equiv int
\]

but:

\[
B \approx_R int.
\]

And:

```sml
datatype C = C of int
```

normally gives neither:

\[
C \not\equiv int
\]

nor necessarily:

\[
C \approx_R int.
\]

An optimizer might happen to represent `C` identically to `int`, but that is an implementation detail.

For `freshtype`, representation equivalence is part of the language semantics.

That distinction is important.

---

# Conversion should be a coercion, not a constructor

You still need some way to cross the nominal boundary.

I would use an explicit `coerce`.

For example:

```sml
freshtype UserId repr int

val id : UserId =
    coerce 42

val n : int =
    coerce id
```

Typing:

\[
\frac{
\Gamma\vdash e:\tau
\qquad
\tau\approx_R\sigma
}{
\Gamma\vdash\operatorname{coerce}(e):\sigma
}
\]

Compilation:

```text
coerce e
```

simply becomes:

```text
e
```

in the runtime IR.

There is no instruction.

There is no allocation.

There is no wrapping.

There is no pattern matching.

There isn't even conceptually a function call.

It's a static type-system operation.

That strikes me as much more semantically honest than:

```haskell
UserId 42
```

where the syntax looks like data construction but the runtime semantics aren't construction.

---

# You could make the coercions lexically available

The representation equation shouldn't necessarily be globally visible.

For example:

```sml
structure UserId =
struct
    freshtype t repr int

    fun fromInt x : t =
        coerce x

    fun toInt x : int =
        coerce x
end
```

Outside the structure you could expose:

```sml
signature USER_ID =
sig
    type t

    val fromInt : int -> t
    val toInt   : t -> int
end
```

Now clients know only:

```text
UserId.t : Type
```

They do **not** know:

```text
UserId.t repr int
```

and therefore cannot write:

```sml
coerce x : UserId.t
```

themselves.

This gives you zero-cost abstraction without exposing the representation.

Internally:

\[
UserId.t \approx_R int
\]

but that witness has been hidden.

This is exactly where representation equality becomes especially useful.

---

# The module interaction is particularly elegant

Suppose:

```sml
functor MakeId (X : DOMAIN) =
struct
    freshtype id repr int
end
```

Now executing the functor body performs:

\[
\nu id \mathrel{repr} int.
\]

Therefore:

```sml
structure A = MakeId(X)
structure B = MakeId(X)
```

produces:

\[
A.id \neq B.id
\]

although:

\[
A.id \approx_R int
\]

and:

\[
B.id \approx_R int.
\]

And therefore transitively they have compatible representations:

\[
A.id \approx_R B.id
\]

but are **not type equal**:

\[
A.id \not\equiv B.id.
\]

That is exactly the distinction you want.

A value of `A.id` cannot accidentally be passed where a `B.id` is expected, despite both being machine integers.

---

# And yes: `freshtype` naturally has the Fresh effect

Our earlier typing judgment was roughly:

\[
\Gamma\vdash M:T\;!\;\epsilon.
\]

Then:

```sml
freshtype t repr int
```

produces a type-generation effect:

\[
Fresh(t).
\]

So a functor such as:

```sml
functor F (X : S) =
struct
    freshtype t repr int
end
```

has something conceptually like:

\[
F :
\Pi X:S
\xrightarrow{Fresh}
\{t:\mathrm{Type}\}.
\]

This ties the two ideas together extremely neatly:

```text
new nominal type
        ↓
     freshtype
        ↓
       ν α
        ↓
   Fresh effect
        ↓
generative functor application
```

There is no longer a mysterious special rule saying:

> “SML functors happen to be generative.”

Instead:

> the functor is generative because its body performs fresh type generation.

That's a much better explanation.

---

# But I would make `Fresh` scope-sensitive

There is one refinement worth making.

Consider:

```sml
functor F (X : S) =
struct
    local
        freshtype temporary repr int
    in
        val x = 42
    end
end
```

If `temporary` never appears in the result signature, should `F` really have to become generative?

Probably not.

The fresh identity cannot be observed.

So internally I wouldn't make the effect merely:

```haskell
data Effect
  = Pure
  | Fresh
```

I'd track which nominal identities are generated:

```haskell
data TypeEffect
  = TypeEffect (Set TyVar)
```

Conceptually:

\[
Fresh(\alpha).
\]

When the scope closes:

```text
ν α . M
```

if α does not escape into the result type, the effect can be discharged.

This is analogous to hiding locally allocated state.

So:

```sml
freshtype temp repr int
```

used entirely internally need not make a functor externally generative.

But:

```sml
freshtype t repr int

(* t appears in result *)
```

does.

The test is essentially:

\[
\alpha \in FV(T_{\mathrm{result}})
\]

If yes, the fresh identity escapes.

If no, generativity is unobservable.

That gives you a much more precise system.

---

# So the functor effect can be inferred

Consider:

```sml
functor Identity (X : S) =
struct
    type t = X.t
end
```

No escaping `freshtype`.

Internally:

```text
NoFreshTypes
```

and Rune can safely expose it as applicative:

\[
Identity(X).t = X.t.
\]

Now:

```sml
functor Make (X : S) =
struct
    freshtype t repr int
end
```

contains an escaping fresh type.

Therefore:

```text
MayGenerateEscapingTypes
```

and:

\[
Make(X)
\]

cannot be a stable applicative path.

Exactly what we wanted previously.

---

# SML'97 compatibility still needs the separate arrow barrier

There is one subtle distinction from our last discussion.

For Rune's modern semantics you can infer:

```text
no escaping freshtype
    =>
applicative functor
```

But if you're compiling literal SML'97, you may still want every SML functor application treated as a generative/non-applicative **path barrier**, regardless of whether this particular functor actually generates a type.

So keep these two concepts distinct:

```haskell
data ArrowSemantics
  = ApplicativeArrow
  | GenerativeArrow
```

and:

```haskell
data TypeGeneration
  = NoGeneration
  | GeneratesFreshTypes
```

For Rune source:

```text
ArrowSemantics
```

can usually be inferred from generation.

For strict SML'97:

```text
functor declaration
    =>
GenerativeArrow
```

even if its body contains no `freshtype`.

That preserves SML path semantics precisely.

Meanwhile actual type identities are still created solely by:

```text
freshtype / datatype / opaque sealing
```

This separation is worth retaining.

---

# `datatype` can itself be explained using `freshtype`

There's an even deeper payoff.

Suppose:

```sml
datatype color =
    Red
  | Green
  | Blue
```

At the static level, a datatype declaration first does:

\[
\nu color.
\]

That is exactly the same nominal identity operation as:

```sml
freshtype color ...
```

Then it additionally defines:

- a runtime representation;
- constructors;
- elimination/pattern-matching rules;
- recursion;
- equality behavior;
- constructor tags.

So conceptually:

```text
datatype
    =
fresh nominal type
+
chosen representation
+
constructors
+
eliminator/pattern semantics
```

This is a useful compiler architecture.

The common operation is:

```haskell
FreshNominalType
```

Then:

```text
freshtype
```

uses it without introducing value constructors.

And:

```text
datatype
```

uses it plus the ordinary datatype machinery.

---

# Opaque abstraction can also use the same primitive

Likewise:

```sml
structure M :> S =
struct
    type t = int
end
```

can be understood as:

```text
ν α
```

plus a hidden representation relation:

\[
\alpha \approx_R int.
\]

Outside:

```text
α : Type
```

Inside:

```text
α repr int
```

This means the same primitive can underlie:

```text
freshtype
datatype
opaque sealing
abstract module types
generative functors
```

That's a strong sign that you've found a good primitive.

---

# One caution: generalized coercion becomes nontrivial

If Rune merely permits:

```sml
coerce : int -> UserId
```

because:

```text
UserId repr int
```

that's easy.

But eventually you'll ask whether this should work:

```text
UserId list
    repr
int list
```

Usually yes.

Then:

```text
UserId option
    repr
int option
```

also yes.

But what about:

```text
Set UserId
```

versus:

```text
Set int
```

?

That depends on whether `Set` treats its parameter purely representationally.

For example, a type constructor could rely on the nominal identity of its parameter internally.

This is the problem that led GHC to **roles**.

Roughly:

```text
phantom
representational
nominal
```

Rune could eventually need the same distinction.

For example:

```text
list : representational -> Type

ref  : ? -> Type

SomeAbstractMap : nominal -> Type
```

Then coercion lifting is valid only through representational parameters.

You do not need this complexity initially.

A very clean first version is:

> `coerce` only operates directly between a `freshtype` and its declared representation.

No automatic lifting through arbitrary type constructors.

Later you can add representational roles if worthwhile.

---

# I'd even consider making `repr` a first-class static concept

For example:

```sml
freshtype UserId repr int
freshtype Price  repr int
freshtype Meters repr real
```

could result internally in:

```text
nominal:
    UserId != int
    Price  != int
    UserId != Price

representation:
    repr UserId = int
    repr Price  = int
    repr Meters = real
```

Then the compiler has a representation projection:

\[
Rep : Type \rightarrow RuntimeType.
\]

So:

\[
Rep(UserId)=Rep(int).
\]

This could become useful throughout your backend.

For example, bytecode generation can compile:

```text
UserId
Price
int
```

to exactly the same machine/VM representation.

The frontend retains nominal distinctions while the backend sees their `Rep`.

That is a clean phase separation.

---

# A possible core datatype

I might ultimately represent Rune's types something like:

```haskell
data Ty
  = TVar TyVar
  | TCon TyCon
  | TApp Ty Ty
  | TArrow Ty Ty
  | TTuple [Ty]
  | TProj ModPath Label
  deriving (...)
```

with a separate environment:

```haskell
data TyConInfo
  = AliasInfo
      { aliasTarget :: Ty
      }

  | FreshInfo
      { freshStamp :: TypeStamp
      , freshRepr  :: Maybe Ty
      }

  | DataInfo
      { dataStamp        :: TypeStamp
      , dataConstructors :: [Constructor]
      , dataRepr         :: DataRepresentation
      }
```

Then:

```sml
type A = int
```

doesn't really need a nominal `TyCon` at all after elaboration.

```sml
freshtype A repr int
```

does.

And:

```sml
datatype A = ...
```

does too.

Both `FreshInfo` and `DataInfo` contain a nominal identity.

---

# Surface syntax

Of several possibilities, I particularly like:

```sml
freshtype UserId repr int
```

because it doesn't misuse `=`.

Alternatively:

```sml
freshtype UserId : int
```

could work, but `:` traditionally means typing rather than representation.

Another possibility:

```sml
freshtype UserId
    representation int
```

is verbose but explicit.

I think:

```sml
freshtype UserId repr int
```

is concise and says exactly what's happening.

You could also allow an entirely abstract form:

```sml
freshtype Token
```

which means:

\[
\nu Token:\mathrm{Type}
\]

with no known representation equation.

That's useful for phantom identities or abstract brands.

Then:

```sml
freshtype UserId repr int
```

is simply the representation-refined form.

---

# The resulting Rune taxonomy is unusually clean

You could explain the whole system with four concepts:

```sml
type t = τ
```

> alias; no new identity.

```sml
freshtype t repr τ
```

> fresh identity; same runtime representation.

```sml
datatype t = ...
```

> fresh identity; introduces actual values/constructors.

```sml
structure M :> S
```

> hide type identity/representation information behind abstraction.

And under the hood, the latter three all ultimately use:

\[
\nu\alpha.
\]

That is more coherent than the usual collection of unrelated language constructs.

So yes: **I would seriously consider making `freshtype` Rune's replacement for `newtype`**. The key semantic difference in presentation is that Rune would describe it truthfully as a **type-generativity construct with a representation equation**, not as a strangely erased one-constructor datatype.

And it meshes almost perfectly with the higher-order module calculus:

\[
\boxed{
\texttt{freshtype}
\rightarrow
\nu
\rightarrow
Fresh(\alpha)
\rightarrow
\text{generative module result if }\alpha\text{ escapes}
}
\]

That gives one primitive explanation for both zero-cost nominal types and ML module generativity.

---

discuss the existing literature on this topic

---

Yes. There is substantial literature around almost every piece of the idea, although I do not know of a mainstream language or paper that presents exactly the combination

\[
\text{fresh nominal type}
+
\text{declared representation equality}
+
\text{explicit Fresh effect}
\]

as one primitive called something like `freshtype`.

Web search is disabled in this session, so I cannot verify bibliographic metadata against current sources. The research lineage below is based on the established literature.

The cleanest way to understand the prior art is as several research traditions that converge on the same point.

## 1. ML generativity: the closest source of the “fresh type” part

Standard ML already has the core semantic phenomenon you want. A datatype declaration creates a genuinely fresh type identity:

```sml
datatype t = C of int
```

Conceptually:

\[
\nu \alpha:\mathsf{Type}.\; \ldots
\]

where \(\alpha\) is a fresh nominal type name.

This idea is deeply embedded in the formal semantics of Standard ML. Relevant starting points are:

- Robin Milner, Mads Tofte, Robert Harper, David MacQueen, **The Definition of Standard ML**
- David MacQueen, **Modules for Standard ML**
- David MacQueen, **Using Dependent Types to Express Modular Structure**

The important point is that ML did not originally treat type constructors merely as structural descriptions. Some declarations allocate new **type identities**.

That makes your:

```sml
freshtype t repr int
```

very ML-like at the type-identity level.

The difference is that an ordinary ML abstract or datatype type does not expose the additional proposition:

\[
\operatorname{Rep}(t)=\operatorname{Rep}(int).
\]

That is where the Haskell literature enters.

---

# 2. Leroy: generativity as something that should be made syntactic

Xavier Leroy's work is especially close to the direction you're considering.

The important sequence includes:

- **Manifest Types, Modules, and Separate Compilation** (1994)
- **Applicative Functors and Fully Transparent Higher-Order Modules** (1995)
- **A Syntactic Theory of Type Generativity and Sharing**

Leroy's work progressively replaces semantic “type stamps” with things that can be represented explicitly in a formal type language.

The fundamental question is:

> When is a type identity fresh, and when can two type paths be proven to denote the same type?

This is precisely relevant to:

```sml
freshtype t repr int
```

because that declaration establishes two deliberately different relations:

\[
t \not\equiv int
\]

but

\[
t \approx_R int.
\]

Leroy's work mostly concentrates on the first relation—nominal/type identity and sharing—not the second representation relation.

But conceptually it provides half of your calculus.

---

# 3. Harper, Lillibridge, Dreyer: generative abstraction as a proper type-theoretic operation

A second major ML line develops generativity more explicitly in type theory.

Important works include:

- Harper, Mitchell, Moggi, **Higher-Order Modules and the Phase Distinction**
- Harper and Lillibridge, **A Type-Theoretic Approach to Higher-Order Modules with Sharing**
- Dreyer, Crary, Harper, **A Type System for Higher-Order Modules**
- Derek Dreyer, **Understanding and Evolving the ML Module System**

Dreyer's work is particularly relevant.

One central realization of this literature is that type generation should not be conflated with ordinary function application.

Instead, there is a genuine operation that creates a new abstract identity:

\[
\nu \alpha.
\]

That leads almost exactly to the conceptual decomposition we were discussing:

\[
\text{functor}
=
\text{function}
+
\text{possibly fresh type creation}.
\]

Your proposed `freshtype` would simply expose that operation directly in the language.

This is considerably cleaner than saying that “functor application itself is inherently generative.”

---

# 4. Dreyer's work on recursive type generativity

Dreyer also studied **recursive type generativity**, which becomes relevant surprisingly quickly if `freshtype` can appear inside recursive modules or mutually recursive definitions.

The issue is something like:

```sml
recursive module M =
struct
    freshtype t repr ...
    ...
end
```

Now the fresh identity participates in the very structure whose static definition is being computed.

This creates subtle interactions between:

- freshness;
- recursion;
- type identity;
- sealing;
- initialization.

Dreyer's work on recursive modules and generativity is therefore worth reading before making `freshtype` legal everywhere.

For a first Rune implementation, I would probably forbid or carefully constrain fresh-type generation inside recursively initialized module knots.

---

# 5. Existential types: “abstract types have existential type”

Another foundational result is:

**John Mitchell and Gordon Plotkin, _Abstract Types Have Existential Type_.**

This establishes the standard connection:

```sml
signature S =
sig
    type t
    val x : t
end
```

corresponds roughly to:

\[
\exists \alpha.\{\;x:\alpha\;\}.
\]

This matters because your `freshtype` can be interpreted similarly.

Suppose:

```sml
freshtype UserId repr int
```

and you hide its representation.

You can think of the resulting package as approximately:

\[
\exists \alpha.
\{
   \operatorname{Coercible}_R(\alpha,int),
   \ldots
\}.
\]

The abstraction boundary hides \(\alpha\).

Inside the package you possess the representation witness:

\[
\alpha \approx_R int.
\]

Outside you may only know:

\[
\alpha:\mathsf{Type}.
\]

That is a very natural formalization of zero-cost abstraction.

---

# 6. But existential quantification and generativity are not quite identical

This distinction is important.

An existential says:

\[
\exists\alpha.T
\]

whereas generative introduction says something closer to:

\[
\nu\alpha.T.
\]

Every evaluation of:

```text
ν α . M
```

must produce a new identity.

So:

```sml
structure A = Make()
structure B = Make()
```

gives:

\[
A.t \neq B.t.
\]

Even though the two packages have structurally identical existential types.

This difference between:

- existential abstraction;
- dynamically/generatively fresh type identity

is a major theme of ML module research.

For Rune, I would keep both notions in the core language rather than trying to encode every generative operation as a plain existential too early.

---

# 7. Fresh names and the ν-calculus

There is also a separate body of work about **fresh-name generation**.

A foundational line comes from Andrew Pitts and Ian Stark.

An important early paper is:

**Pitts and Stark, _Observable Properties of Higher Order Functions that Dynamically Create Local Names, or: What's new?_**

This work studies calculi containing an operation essentially like:

\[
\nu a.M
\]

meaning “generate a fresh name \(a\), locally scoped in \(M\).”

This is extremely close mathematically to your proposed:

\[
\nu \alpha:\mathsf{Type}.M.
\]

The difference is merely what kind of thing is being generated:

```text
ν a        fresh value-level name
ν α        fresh type-level name
```

This literature gives a rigorous account of:

- freshness;
- scope extrusion;
- observational equivalence;
- name hiding;
- generative allocation.

Those results are useful because `freshtype` is fundamentally a **name-generation operator at the type level**.

---

# 8. Nominal logic and nominal sets

The Pitts/Gabbay line later developed into nominal techniques more generally.

Important references include:

- Gabbay and Pitts, **A New Approach to Abstract Syntax with Variable Binding**
- Andrew Pitts, **Nominal Sets: Names and Symmetry in Computer Science**
- FreshML work by Shinwell, Pitts, Gabbay

FreshML is primarily concerned with generating fresh object-language names for metaprogramming, not fresh programming-language types.

But the underlying mathematical machinery is closely related.

A `freshtype` binder has the characteristic nominal rule:

\[
\alpha \# \Gamma
\]

meaning that \(\alpha\) must be fresh for the current context.

Then:

\[
\frac{
\alpha\#\Gamma
\qquad
\Gamma,\alpha:\mathsf{Type}\vdash M:T
}{
\Gamma\vdash\nu\alpha.M:\ldots
}
\]

This is a very natural formal basis if Rune ends up having more explicit name-generation constructs.

---

# 9. Haskell `newtype`: the representation-equality half

The other half of your proposed feature comes directly from Haskell.

Haskell's:

```haskell
newtype UserId = UserId Int
```

establishes:

\[
UserId \not\equiv Int
\]

but they have the same runtime representation.

Historically, `newtype` was presented largely as a datatype-like source construct whose constructor is representation-free.

Modern GHC theory makes the underlying concept much more explicit.

The critical distinction is between different notions of equality.

Roughly:

\[
\tau \sim_N \sigma
\]

nominal equality, versus:

\[
\tau \sim_R \sigma
\]

representational equality.

For a `newtype`:

\[
UserId \not\sim_N Int
\]

but:

\[
UserId \sim_R Int.
\]

That is almost exactly the relationship I suggested Rune should expose explicitly.

---

# 10. System FC: equality evidence becomes explicit

An important part of the GHC story is **System FC**, developed around work by Sulzmann, Chakravarty, Peyton Jones and others.

A key paper is:

**Sulzmann et al., _System F with Type Equality Coercions_.**

GHC's typed intermediate language contains explicit evidence of type equality/coercion.

Conceptually you might have:

\[
\gamma :
\tau \sim_R \sigma.
\]

Then an expression can be cast:

\[
e \triangleright \gamma.
\]

The coercion is erased before runtime.

This is exactly the right conceptual machinery for Rune's:

```sml
coerce x
```

If:

```sml
freshtype UserId repr int
```

creates an internal representation witness:

\[
c_{UserId} :
UserId \sim_R int,
\]

then:

```sml
coerce x
```

can compile to a System-FC-like cast and subsequently disappear.

So your proposed feature could be given an extremely conventional typed-IR interpretation.

---

# 11. `Coercible`: probably the most directly relevant Haskell work

The paper I would put near the top of your Rune reading list is:

**Joachim Breitner, Richard Eisenberg, Simon Peyton Jones, Stephanie Weirich, _Safe Zero-cost Coercions for Haskell_.**

This is the research underlying GHC's `Coercible`.

It tackles exactly the question:

> If two types have the same runtime representation, when is it safe to convert between them at zero cost?

For:

```haskell
newtype Age = Age Int
```

GHC can establish something like:

```haskell
Coercible Age Int
```

and:

```haskell
coerce :: Coercible a b => a -> b
```

is runtime-free.

This is essentially your desired:

```sml
coerce : τ -> σ
```

subject to:

\[
\tau\approx_R\sigma.
\]

The paper is essential because it also explains why simply declaring “same representation” isn't enough.

---

# 12. Roles are the subtle part

Consider:

```sml
freshtype UserId repr int
```

We know:

\[
UserId \approx_R int.
\]

Does that imply:

\[
list\ UserId
\approx_R
list\ int?
\]

Almost certainly yes.

But consider an arbitrary type constructor:

\[
F\ UserId
\]

versus:

\[
F\ int.
\]

You cannot automatically conclude that these can be coerced.

The type parameter might be used nominally.

The GHC literature solves this with **roles**:

- nominal;
- representational;
- phantom.

For example, conceptually:

\[
List : \mathsf{representational}\to Type.
\]

Therefore:

\[
A\approx_R B
\implies
List\,A\approx_R List\,B.
\]

But another constructor might require nominal equality:

\[
F : \mathsf{nominal}\to Type.
\]

Then:

\[
A\approx_R B
\]

is insufficient.

This is probably the single most important body of prior work to study before implementing general `freshtype` coercions.

---

# 13. Why roles exist: abstraction can otherwise be broken

Suppose a library defines something morally like:

```haskell
type role Set nominal
data Set a = ...
```

Internally it relies upon the actual nominal identity of `a`.

If the compiler allowed:

```text
Coercible a b
=>
Coercible (Set a) (Set b)
```

without knowing how `a` is used, representation coercion could violate invariants.

Your Rune system has exactly the same potential issue.

So:

```sml
freshtype UserId repr int
```

is easy.

But generalizing:

```sml
coerce : F UserId -> F int
```

requires a role system, variance-like representation analysis, or a much more conservative rule.

This is an area where GHC has already done much of the hard research.

---

# 14. Haskell `newtype` is not generative in your sense

This is an important difference.

A declaration:

```haskell
newtype UserId = UserId Int
```

introduces one statically named type constructor.

Every occurrence refers to the same `UserId`.

It does not behave like:

\[
\nu\alpha.
\]

For example, evaluating some function twice cannot ordinarily produce two unrelated `UserId` type identities.

So Haskell gives you:

\[
\text{nominal distinction}
+
\text{representation equality}
\]

but not:

\[
\text{dynamic/module-level type generativity}.
\]

Your `freshtype` adds exactly that missing dimension.

---

# 15. `runST`: an unexpectedly close Haskell analogy

Haskell does have another construct that creates something very much like a fresh type identity:

```haskell
runST :: (forall s. ST s a) -> a
```

Consider:

```haskell
STRef s Int
```

The phantom `s` prevents references created in one state thread from escaping into another.

Each invocation of `runST` can be reasoned about as though it gets a fresh abstract state-thread identity.

This isn't implemented as runtime fresh type generation.

Instead rank-2 polymorphism guarantees that the caller cannot choose or observe `s`.

But semantically it gives an effect very similar to:

\[
\nu s.
\]

The classic reference is:

**John Launchbury and Simon Peyton Jones, _Lazy Functional State Threads_.**

This deserves a place in the `freshtype` literature because it illustrates another way to model generativity:

\[
\nu\alpha.M
\]

can sometimes be encoded using higher-rank quantification:

\[
(\forall\alpha.M)\to\ldots
\]

depending on polarity and use.

---

# 16. Region systems are another close cousin

ML-inspired region calculi also use scoped identities.

A classic reference is Tofte and Talpin's work on region-based memory management, including:

**Implementation of the Typed Call-by-Value λ-Calculus using a Stack of Regions.**

A region variable behaves something like:

\[
\rho
\]

where allocating a fresh region introduces a new identity whose scope and effects are tracked statically.

That gives you another pattern:

```text
fresh resource identity
+
static effect
+
lexical scope
```

which is essentially the same architectural form as:

```text
fresh type identity
+
Fresh effect
+
lexical scope.
```

The domains are different, but the effect-system machinery is relevant.

---

# 17. Effect systems for allocation

More generally, traditional effect-system research studies judgments like:

\[
\Gamma\vdash e:\tau\;!\;\epsilon.
\]

where \(\epsilon\) might contain:

```text
read ρ
write ρ
allocate ρ
```

Your module calculus could analogously contain:

\[
\Gamma\vdash M:S\;!\;\mathrm{Fresh}(\alpha).
\]

This is not a strange new idea. It is an instance of the same effect-tracking framework.

The especially interesting question is **effect masking**.

If:

\[
\nu\alpha.M
\]

creates \(\alpha\), but \(\alpha\) does not escape in the result type, then externally the fresh effect can disappear.

That is closely analogous to local state:

\[
runST
\]

hiding state effects when the state token does not escape.

This connection is worth developing formally.

---

# 18. Scala opaque types are extremely close on the representation side

Scala 3 has:

```scala
opaque type UserId = Int
```

Outside the defining scope, `UserId` is abstract/distinct.

Inside the defining scope, the implementation knows its representation is `Int`.

This provides:

- zero-cost abstraction;
- nominal distinction at the abstraction boundary;
- representation transparency internally;
- no wrapper allocation.

In spirit:

\[
UserId\not\equiv Int
\]

externally, while internally:

\[
UserId\equiv Int
\]

or at least is known to use that representation.

That is very close to:

```sml
freshtype UserId repr int
```

But again, Scala's opaque type declaration is primarily a **named static declaration**, not an effectful operation that creates a new identity each time a module computation is executed.

So your idea is roughly:

> Scala opaque type + ML generativity + explicit representation equality.

---

# 19. OCaml has two pieces very close to the proposal

OCaml contributes several relevant mechanisms.

It has ordinary abstract type components:

```ocaml
module type S = sig
  type t
end
```

It also has applicative versus generative behavior in its module system.

Modern OCaml supports explicitly **generative functors**, commonly through unit functors of the form conceptually:

```ocaml
module F () = struct
  type t
end
```

Applying:

```ocaml
module A = F()
module B = F()
```

gives distinct abstract type identities.

That is directly comparable to:

\[
\nu\alpha.
\]

OCaml also has **private types/private abbreviations**, which provide interesting one-way abstraction and coercion properties.

For example, private type abbreviations allow code to expose knowledge related to an underlying representation while restricting construction.

They are worth examining for Rune's visibility rules around `repr`.

---

# 20. Ada derived types are an older, surprisingly close precedent

Ada distinguishes roughly between a subtype and a derived/new type.

Conceptually:

```ada
subtype X is Integer;
```

does not create a genuinely new type identity in the same sense as:

```ada
type X is new Integer;
```

The latter creates a distinct type derived from `Integer`.

This gives Ada a language-level distinction resembling:

```sml
type X = int
```

versus:

```sml
freshtype X repr int
```

although Ada's semantic model isn't the same as the explicit representation-equality calculus we're discussing.

Still, the linguistic distinction between:

> alias/restriction of an existing type

and

> genuinely new nominal type based on an existing representation/domain

is decades old.

---

# 21. Modula-family “brands” are also relevant

Some languages in the Modula tradition explicitly support **branded** or nominal types.

Modula-3 in particular has a notion of brands that can force otherwise structurally identical types to remain distinct.

That is closely related to:

\[
\nu\alpha.
\]

The interesting lesson from branded types is that there is utility in exposing nominal identity as its own concept rather than making it emerge indirectly from datatype declaration syntax.

That is philosophically very close to `freshtype`.

---

# 22. Rust's `repr(transparent)` is the low-level analogue

Rust programmers commonly use a newtype pattern:

```rust
#[repr(transparent)]
struct UserId(u64);
```

This creates a nominally distinct type whose ABI/layout is guaranteed to match its single field under the `repr(transparent)` rules.

That gives:

\[
UserId\neq u64
\]

but with a specified representation correspondence.

This is very close to your `repr` annotation from an ABI perspective.

However, Rust still semantically presents `UserId` as an actual struct.

So it has exactly the same stylistic property you dislike about Haskell `newtype`, although the operational details differ.

Rune's:

```sml
freshtype UserId repr int
```

would say directly what the Rust idiom is trying to accomplish.

---

# 23. Representation independence is another important literature

If Rune allows:

```sml
signature S =
sig
    type t
end
```

to hide the fact that:

```sml
freshtype t repr int
```

then you should also look at the classical literature on **representation independence**.

The core property you want is:

> A client that cannot see the representation witness should not be able to distinguish two implementations merely because their hidden representations differ.

This is closely related to:

- Reynolds' parametricity work;
- Mitchell and Plotkin on abstract types;
- logical relations for existential types;
- representation independence for ML modules.

This gives the theorem you'd ideally want:

If two structures implement the same abstract signature and are related by an appropriate logical relation, client programs cannot distinguish them.

Your representation-equality witness must therefore obey abstraction boundaries very carefully.

---

# 24. `freshtype` can be understood as existential + nominal freshness + coercion evidence

Combining the literature gives a very clean formal picture.

Your construct:

```sml
freshtype t repr τ
```

can be modeled as generating:

\[
\nu\alpha.
\]

together with a representation witness:

\[
c:\alpha\approx_R\tau.
\]

So internally:

\[
\nu\alpha.
\{
    t=\alpha,
    c:\alpha\approx_R\tau
\}.
\]

If sealed:

\[
\exists\alpha.
\{
    c:\alpha\approx_R\tau,
    \ldots
\}
\]

with `c` possibly hidden as well.

That combines three existing theories almost literally:

\[
\underbrace{\nu\alpha}_{\text{ML / nominal freshness}}
+
\underbrace{\exists\alpha}_{\text{abstraction}}
+
\underbrace{\alpha\sim_R\tau}_{\text{GHC representation coercion}}.
\]

That is why the idea feels unusually natural.

---

# 25. The “Fresh effect” has precedent but your exact formulation would be distinctive

The ML literature often treats generativity semantically or through typing rules rather than exposing an effect row literally called:

```text
Fresh α
```

But effect systems make such a presentation natural.

You could have:

\[
\Gamma\vdash M:S!\epsilon
\]

where:

\[
\epsilon ::= \varnothing
\mid Fresh(\alpha)
\mid \epsilon_1\cup\epsilon_2.
\]

Then:

\[
\frac{
\alpha\ \mathrm{fresh}
}{
\Gamma\vdash
\texttt{freshtype }\alpha\texttt{ repr }\tau
:
\ldots
!
Fresh(\alpha)
}
\]

If \(\alpha\) does not escape:

\[
\alpha\notin FV(S)
\]

you can mask it:

\[
\nu\alpha.M
\]

and remove `Fresh α` from the observable effect.

This part resembles:

- region effect masking;
- `runST`;
- local name generation;
- existential hiding.

I do not know of a mainstream ML-like language that exposes exactly this combination as a first-class type-generativity effect.

That could be one of the genuinely distinctive parts of Rune.

---

# 26. There is also a connection to generative phantom types

A recurring programming technique is to create an otherwise meaningless phantom parameter whose only purpose is to distinguish values from different invocations.

For example, APIs for:

- sessions;
- database transactions;
- regions;
- parser phases;
- graph identities;
- units;
- capabilities;

often want something like:

```text
Session s
Handle s
```

where `s` is unforgeable and unique to one invocation.

Haskell usually achieves this with:

- higher-rank polymorphism;
- phantom types;
- `ST`-style quantification.

ML can achieve it using generative modules.

Your language could simply write:

```sml
freshtype session

val h : Handle session
```

This would make a large family of phantom-type encodings much more direct.

There is a substantial literature on generative phantom types and lightweight static capabilities, although it is scattered across API-design, region, ST and generative-module papers rather than centered around one feature.

---

# 27. One especially useful comparison

The existing approaches can be arranged by which properties they provide:

| Mechanism | Fresh nominal identity | Zero-cost repr equality | Generative per invocation | Can hide repr |
|---|---:|---:|---:|---:|
| SML `datatype` | yes | generally no | yes | yes |
| SML abstract type | yes/abstract | not exposed | yes in generative contexts | yes |
| Haskell `newtype` | yes | yes | no | partially/module-dependent |
| GHC `Coercible` | — | yes | — | yes via abstraction/roles |
| Scala opaque type | yes | effectively yes | ordinarily no | yes |
| Rust transparent newtype | yes | ABI/layout correspondence | no | yes |
| OCaml generative functor | yes | not the central mechanism | yes | yes |
| `runST` phantom `s` | logical freshness | n/a | effectively yes | yes |
| ν-calculus | yes, as names | n/a | yes | yes |
| proposed Rune `freshtype` | yes | yes | yes | yes |

The last row is why your construct is interesting: it combines columns that existing systems usually split across separate features.

---

# 28. What I would read first

If the goal is specifically to design this Rune feature rather than survey modules generally, I would prioritize the literature in roughly this conceptual order:

1. **Breitner et al., _Safe Zero-cost Coercions for Haskell_**  
   For representation equality, `Coercible`, roles, and abstraction safety.

2. **Dreyer, _Understanding and Evolving the ML Module System_**  
   For generativity as an explicit semantic phenomenon rather than a mysterious functor property.

3. **Leroy, _A Syntactic Theory of Type Generativity and Sharing_**  
   For making type identity/freshness explicit and syntactic.

4. **Mitchell & Plotkin, _Abstract Types Have Existential Type_**  
   For understanding how fresh abstract types cross abstraction boundaries.

5. **Launchbury & Peyton Jones, _Lazy Functional State Threads_**  
   For the surprisingly close analogy between fresh phantom state tokens and locally scoped generativity.

6. **Pitts & Stark on dynamically generated local names**  
   For the actual \(\nu\)-binder/name-generation theory.

7. **GHC/System FC papers**  
   For representing coercion evidence explicitly in the compiler IR.

8. **Scala opaque types and OCaml generative functors**  
   For practical language-design precedent.

Taken together, these almost specify the feature.

---

# 29. Where Rune could go beyond the existing systems

The synthesis I would explore formally is:

\[
\texttt{freshtype }\alpha\ \texttt{repr}\ \tau\ \texttt{in}\ M
\]

with typing:

\[
\Gamma,\alpha:\mathsf{Type},
c:\alpha\sim_R\tau
\vdash M:T!\epsilon
\]

and result:

\[
\Gamma\vdash
\nu\alpha\sim_R\tau.M
:
T
!
(\epsilon-\mathrm{Fresh}(\alpha))
\]

when \(\alpha\) is locally masked, or retaining the generativity effect when \(\alpha\) escapes through a module result.

That would connect:

- ML type generativity;
- nominal fresh-name semantics;
- effect systems;
- System-FC-style coercions;
- representation roles;
- existential abstraction.

I think that is the right theoretical neighborhood for Rune. The feature is not just “a nicer spelling of Haskell `newtype`.” It is closer to **making nominal type generation itself a primitive effect, with representation equality orthogonal to nominal equality**. That is a stronger and more general idea than `newtype`.

---

one more feature i want in rune (not sure if this is an orthogonal or interacting feature) is allowing containers to specialize to their element type. E.g. an int map allows for more efficient implementation than string map, which ha a more efficient representation than complexDataType map. if the compiler statically knows the element type it should be allow to pick the specialized implementation. the user still programs agaisnt a signature, the compiler picks the implementation

---


Yes. I would treat this as a **compile-time implementation family** selected from static type facts. It is semantically orthogonal to `freshtype`, but the two interact through representation information in a very useful way.

The central principle should be:

\[
\boxed{
\text{one interface}
+
\text{many implementations}
+
\text{static selection}
}
\]

The programmer writes against one signature; the compiler chooses an implementation that satisfies that signature.

For example:

```sml
signature MAP =
sig
    type key
    type 'a map

    val empty  : 'a map
    val insert : key * 'a * 'a map -> 'a map
    val find   : key * 'a map -> 'a option
end
```

You might have:

```sml
IntMap
StringMap
HashMap
GenericMap
```

all satisfying appropriate instances of `MAP`.

The source program should not say which one is used.

## 1. A possible Rune surface construct

Something like:

```sml
implementation family Map (K : TYPE) : MAP
    where type key = K.t
=
    when repr K.t = int
        => IntMap

    when repr K.t = string
        => StringMap

    when Hash K.t and Eq K.t
        => HashMap

    otherwise
        => GenericMap
```

Then:

```sml
val x : Map int
```

selects something like `IntMap`.

While:

```sml
val y : Map string
```

selects `StringMap`.

And:

```sml
val z : Map Customer
```

may get `HashMap` or `GenericMap`.

Importantly, this happens statically.

There is no runtime:

```text
if type == int
```

dispatch.

---

# 2. There are actually three different kinds of specialization

It is useful to distinguish them because the safety conditions differ.

### Representation specialization

Same conceptual algorithm, different storage.

For:

```text
Vector int
```

you might store:

```text
[unboxed int32/int64 ...]
```

instead of:

```text
[pointer, pointer, pointer ...]
```

For:

```text
Vector bool
```

you might use a bit vector.

For:

```text
Vector (freshtype UserId repr int)
```

you could use exactly the `int` representation.

This kind of specialization depends mainly on:

\[
Rep(T).
\]

---

### Operational specialization

The data structure stays conceptually the same, but operations are specialized.

For:

```text
Map int
```

you don't need to pass an equality/hash/comparison function around.

The compiler can emit direct integer comparison:

```text
icmp
```

rather than:

```text
call comparator
```

This is conventional monomorphization/specialization.

---

### Algorithmic specialization

This is the most interesting case.

For integer keys:

```text
radix tree
HAMT with integer hash
crit-bit
dense array
```

might beat a generic balanced tree.

For strings:

```text
trie
radix trie
hash table with cached string hash
```

may be appropriate.

For arbitrary user types:

```text
red-black tree
generic HAMT
```

might be necessary.

Here the compiler isn't merely changing representation—it is selecting an entirely different implementation.

That is where the module-system formulation becomes valuable.

---

# 3. I would not model it as ordinary overloading

Haskell type classes might suggest:

```haskell
class MapFor k where
    ...
```

but that's slightly different from what you're describing.

A type-class instance is generally part of the program's semantics:

```text
instance selection
```

determines which implementation exists.

Your use case sounds more like:

> All implementations have the same abstract semantics. Selection is a compiler optimization.

That distinction is valuable.

For example, changing from:

```text
GenericMap
```

to:

```text
IntMap
```

should not make the program observably different.

Ideally:

\[
\llbracket IntMap \rrbracket
=
\llbracket GenericMap \rrbracket
\]

with respect to the public signature.

The compiler is merely selecting a refinement of the implementation.

---

# 4. Module families are a natural fit

In the higher-order module calculus we developed earlier, this can be modeled as a static module function:

\[
MapImpl :
TypeInfo
\rightarrow
Module.
\]

But I would not expose arbitrary runtime/typecase.

Instead introduce a restricted **static selection language**.

Conceptually:

```haskell
data StaticPredicate
  = NominalIs Ty Ty
  | ReprIs    Ty RuntimeRep
  | Has       Capability Ty
  | And       StaticPredicate StaticPredicate
  | Or        StaticPredicate StaticPredicate

data ImplRule = ImplRule
  { condition :: StaticPredicate
  , impl      :: ModExpr
  }

data ImplFamily = ImplFamily
  { interface :: ModType
  , rules     :: [ImplRule]
  , fallback  :: ModExpr
  }
```

Then:

```text
resolveFamily Γ MapImpl int
```

could return:

```text
IntMap
```

before lowering to the ordinary module calculus.

After that, the family mechanism disappears.

---

# 5. The interaction with `freshtype` is excellent

Suppose:

```sml
freshtype UserId repr int
```

Then:

\[
UserId \neq int
\]

nominally.

But:

\[
Rep(UserId)=Rep(int).
\]

Now distinguish two specialization predicates.

A rule saying:

```text
nominal-type = int
```

does **not** match `UserId`.

But:

```text
representation = int
```

does.

That distinction is exactly what you want.

For example, this is safe:

```sml
when repr K.t = int
    => PackedIntStorage
```

because it only cares about representation.

But this may not be safe:

```sml
when K.t = int
    => IntegerOrderedMap
```

because it depends upon the semantics of actual integers.

So Rune gets a powerful separation:

\[
\boxed{
\text{nominal identity}
\neq
\text{representation identity}
\neq
\text{semantic capabilities}
}
\]

That separation is important.

---

# 6. `repr int` is not enough to inherit integer semantics

This is one place where you should be conservative.

Suppose:

```sml
freshtype UserId repr int
```

That should imply:

\[
Rep(UserId)=Rep(int).
\]

It should not necessarily imply:

```text
Ord UserId
Hash UserId
Num UserId
```

or even that numeric ordering has meaningful semantics.

For example:

```sml
freshtype TemperatureCode repr int
```

might use some custom ordering.

So implementation selection should distinguish:

```text
ReprIs int
Has Eq
Has Ord
Has Hash
NominalIs int
```

instead of collapsing them.

---

# 7. Capabilities are a better selector than concrete types in many cases

Rather than:

```sml
when type = int
```

you'll often want:

```sml
when FixedWidth K.t
 and BitwiseEq K.t
 and CheapHash K.t
```

This makes the system much more reusable.

For example:

```sml
freshtype UserId repr uint64
freshtype AccountId repr uint64
```

could both exploit:

```text
FixedWidth
BitwiseEq
CheapHash
```

without explicitly mentioning either type.

A map family might therefore look conceptually like:

```text
if DenseIntegerDomain K
    use DenseIntMap

else if RadixKey K
    use RadixTrie

else if CheapHash K
    use HashMap

else if Ord K
    use TreeMap
```

This starts looking like static trait/capability resolution.

---

# 8. But compiler implementation choice must be coherent

Suppose both of these match:

```text
repr K = int
```

and:

```text
Hash K
```

Which wins?

You need deterministic rules.

I would avoid arbitrary textual first-match behavior.

Better options are:

1. Require rules to be non-overlapping.
2. Allow overlap only when one predicate logically implies another.
3. Give explicitly stated refinement relationships.

For example:

```text
DenseIntegerDomain
    <: CheapHash
```

Then the more specific implementation wins.

Conceptually:

\[
P_1 \Rightarrow P_2
\]

means the implementation for \(P_1\) is more specialized.

This gives you a partial order rather than ad-hoc priorities.

---

# 9. There should always be a generic implementation

For separate compilation and polymorphic code this matters enormously.

Consider:

```sml
fun f (m : Map 'k int) ...
```

while compiling `f`, `'k` may be unknown.

So Rune needs:

```text
GenericMap
```

as a valid implementation.

Later, when specializing:

```sml
f : Map int int -> ...
```

the compiler can generate:

```text
f<int>
```

using `IntMap`.

That suggests a two-stage strategy:

```text
compile polymorphic generic form
            ↓
instantiate / monomorphize
            ↓
re-run implementation selection
            ↓
specialized version
```

This works very well with whole-program compilation.

---

# 10. This is closely related to MLton's strengths

MLton is relevant conceptually because its whole-program compilation gives it unusually strong knowledge about actual type instantiations.

Whole-program monomorphization lets a compiler turn generic abstractions into specialized concrete code.

Rune could take this further.

Instead of merely:

```text
generic algorithm
    ↓
same algorithm specialized to int
```

Rune could do:

```text
generic interface
    ↓
implementation family
    ↓
completely different implementation for int
```

So:

\[
\text{monomorphization}
+
\text{module selection}
\]

becomes one optimization framework.

---

# 11. This resembles C++ templates, but with stronger abstraction

C++ achieves much of this through templates and specialization:

```cpp
template<class T>
struct Container { ... };

template<>
struct Container<int> { ... };
```

But now the programmer explicitly deals with the specialization system.

And template implementations are generally source-visible structural machinery rather than modules sealed behind an abstract interface.

Rune could provide the useful part:

\[
Container<int>
\rightarrow IntContainer
\]

without exposing implementation choice to ordinary code.

That is substantially cleaner.

---

# 12. Rust has a similar idea but specialization is difficult

Rust monomorphizes generics aggressively.

So:

```rust
fn f<T>(...)
```

can compile differently for each `T`.

But Rust's trait specialization story has historically been constrained by coherence and soundness issues.

The lesson is relevant:

> overlapping implementation selection becomes complicated very quickly.

Rune can avoid much of that complexity if these implementation alternatives are **semantically interchangeable compiler choices**, rather than user-observable trait implementations.

That is a significant simplification.

---

# 13. Swift is another interesting precedent

Swift distinguishes between generic code compiled using protocol witness tables and specialized code generated when concrete type information becomes available.

The optimizer can remove abstraction costs by:

- specializing generics;
- devirtualizing protocol calls;
- selecting concrete implementations.

Rune could make this idea more explicit in the module system:

```text
abstract interface
        ↓
static type known
        ↓
select specialized module
        ↓
inline / unbox / specialize
```

This is roughly the same optimization pipeline, but with explicit implementation families.

---

# 14. Haskell approaches this from several directions

Haskell has multiple partial analogues.

`SPECIALIZE`:

```haskell
{-# SPECIALIZE foo :: Int -> Int #-}
```

generates specialized versions.

`RULES` can rewrite generic implementations into optimized ones.

Type classes select implementations based on types.

`newtype`/`Coercible` tracks representation compatibility.

Unboxed types and worker/wrapper transformations specialize representation.

But these mechanisms are fairly separate.

Rune could unify them around:

\[
\text{static type facts}
\rightarrow
\text{module implementation choice}.
\]

That would be a cleaner conceptual model.

---

# 15. You need to distinguish semantic interface from performance contract

Suppose your `MAP` signature exposes:

```sml
val bindings : 'a map -> (key * 'a) list
```

If one implementation returns keys sorted and another returns arbitrary order, they're not observationally equivalent.

Likewise:

```text
IntMap
HashMap
TreeMap
```

may have different iteration behavior.

So the interface must specify the semantics precisely enough.

For example:

```sml
signature MAP =
sig
    ...
    (* ordering unspecified *)
end
```

would permit more implementations.

But:

```sml
signature ORDERED_MAP =
sig
    ...
    val bindings : 'a map -> (key * 'a) list
    (* ascending key order *)
end
```

would restrict selection.

Complexity guarantees matter similarly.

If the API promises:

\[
O(\log n)
\]

worst-case lookup, then a conventional hash table might not satisfy the contract even if semantically equivalent at the value level.

So there are two notions of conformance:

\[
\text{functional semantics}
\]

and possibly:

\[
\text{cost semantics}.
\]

Rune could eventually allow signatures to express both.

---

# 16. Representation-specialized containers are especially attractive

Your feature goes beyond maps.

Consider:

```text
Array bool
```

Compiler chooses:

```text
BitArray
```

while:

```text
Array int32
```

uses:

```text
PackedInt32Array
```

and:

```text
Array SomeLargeRecord
```

uses:

```text
PointerArray
```

Similarly:

```text
Option pointer-like
```

might use null-pointer representation.

```text
Option bool
```

might use two bits.

```text
List byte
```

could potentially use chunked byte arrays.

```text
Set int
```

might use bitmaps or radix trees.

```text
Set string
```

might use tries.

This is essentially **representation polymorphism plus type-directed implementation selection**.

---

# 17. This can be generalized to layout predicates

Instead of merely:

```text
repr T = int
```

the compiler could know static layout facts:

```text
Size T = 8
Alignment T = 8
PointerFree T
Flat T
BitwiseEq T
Movable T
Nullable T
```

Then implementation families could match against those.

For example:

```text
Vector T
```

could choose:

```text
InlineVector
```

if:

\[
Size(T)\le 16
\]

and:

```text
PointerVector
```

otherwise.

Or:

```text
SmallOption T
```

could exploit unused bit patterns.

This can become a major optimization system.

---

# 18. The connection to your `Rep` function becomes strong

Earlier we effectively introduced:

\[
Rep : Type \rightarrow RuntimeType.
\]

Now we can enrich it:

\[
Layout : Type \rightarrow StaticLayout.
\]

For example:

```haskell
data Layout
  = Scalar Width
  | Pointer
  | Struct [Layout]
  | Packed Int
  | OpaqueLayout
```

Then:

```sml
freshtype UserId repr int
```

gives:

\[
Layout(UserId)=Layout(int).
\]

Container selection can operate on `Layout`.

This creates a very coherent story:

```text
source type
    ↓
nominal identity
    ↓
representation equality
    ↓
layout information
    ↓
implementation specialization
    ↓
machine representation
```

---

# 19. Abstraction should control what specialization is legal

This is another important interaction with `freshtype`.

Suppose:

```sml
structure UserId :>
sig
    type t
end
```

Internally:

\[
UserId.t \approx_R int.
\]

Externally, that fact is hidden.

Should client code be allowed to specialize:

```text
Map UserId.t
```

to `IntMap` anyway?

There are two reasonable compiler architectures.

One says:

> hidden representation information is unavailable to clients, even to optimization.

Then no.

The other says:

> the compiler may exploit hidden representation information internally as long as observational abstraction is preserved.

Then yes.

I strongly prefer the second for optimization.

You want semantic abstraction without optimization barriers.

So distinguish:

```text
source-visible facts
```

from:

```text
compiler-known facts
```

The compiler may know:

\[
Rep(UserId.t)=int
\]

even though the source type checker does not expose that equality.

Then it can select a packed implementation while still rejecting:

```sml
coerce x : int
```

in user code.

That's a powerful design.

---

# 20. This suggests two environments

Internally:

```haskell
data TypeInfo = TypeInfo
  { nominalInfo       :: NominalInfo
  , publicFacts       :: StaticFacts
  , optimizationFacts :: StaticFacts
  }
```

For an opaque `freshtype`:

```text
publicFacts:
    UserId.t : Type

optimizationFacts:
    Rep UserId.t = int
```

The elaborator respects `publicFacts`.

The optimizer may use `optimizationFacts`.

This prevents abstraction from crippling optimization.

---

# 21. I would probably make implementation families an optimizer-facing construct

There is a design choice here.

You could expose:

```sml
implementation family ...
```

to ordinary Rune programmers.

Or you could keep most of it in library/compiler metadata.

I would likely expose a controlled version to library authors but make it semantically non-observable.

Something like:

```sml
signature VECTOR = ...

implementation Vector =
    GenericVector

specialize Vector
    when layout elem = Bit
    with BitVector

specialize Vector
    when layout elem = Int32
    with Int32Vector
```

The meaning is:

> these modules are interchangeable implementations of the same abstract interface.

Not:

> the program can determine which one was chosen.

That's a crucial restriction.

---

# 22. Avoid type reflection

I would not allow normal Rune code to write:

```sml
if typeOf 'a = int then ...
```

That destroys parametricity and makes specialization observable.

Instead:

```text
specialize
```

should belong to the static implementation-selection layer.

So ordinary polymorphic code still satisfies parametricity:

\[
\forall \alpha.\;F(\alpha)
\]

while the compiler is permitted to produce implementation-equivalent specialized versions underneath.

This is analogous to an optimizer generating:

```text
foo<int>
```

without making typecase available to `foo` itself.

---

# 23. A good formal model is elaboration to ordinary modules

You don't need the runtime calculus to understand specialization.

Suppose:

\[
C[T]
\]

uses:

```text
Map T
```

During elaboration:

\[
Resolve(Map,T,\Gamma)=M.
\]

Then replace:

```text
Map T
```

with ordinary module path:

\[
M.
\]

After resolution, the rest of the compiler sees only the higher-order module calculus we've already designed.

So:

```text
ImplementationFamily
```

can disappear before your core IR.

That's architecturally attractive.

---

# 24. It also combines nicely with higher-order functors

Suppose an algorithm is written:

```sml
functor Graph (M : MAP) =
struct
    ...
end
```

Then for:

```text
key = int
```

Rune might elaborate:

```text
Graph(IntMap)
```

while for:

```text
key = string
```

it generates:

```text
Graph(StringMap)
```

Because your functors are applicative and higher-order, this remains ordinary module composition.

No additional machinery is needed after implementation selection.

---

# 25. The architecture I would use

Conceptually:

```text
Rune source
    │
    │ abstract APIs
    ▼
Type elaboration
    │
    │ nominal / repr / capability facts
    ▼
Implementation-family resolution
    │
    │ choose specialized modules
    ▼
Higher-order module calculus
    │
    │ functors, structures, freshtype
    ▼
Monomorphization / specialization
    │
    │ layouts now concrete
    ▼
Typed core
    ▼
VM / native backend
```

There can actually be **two passes** of implementation selection.

First during ordinary elaboration when types are already known.

Then again after monomorphization when previously abstract types become concrete.

That second opportunity is particularly valuable.

---

## The larger idea

The feature you're describing fits into a fairly elegant Rune philosophy:

\[
\boxed{
\text{program against semantics;
compile against representations}
}
\]

The source programmer sees:

```text
Map K V
```

and the signature tells them what it means.

The compiler sees:

```text
K is nominally CustomerId
Rep(K) = uint64
K has BitwiseEq
K has CheapHash
```

and chooses:

```text
PackedUInt64HashMap
```

without changing source-level semantics.

That interacts very naturally with `freshtype`. `freshtype` provides exactly the distinction the specialization mechanism needs: **a type can remain nominally abstract while the compiler still knows enough about its representation to optimize it aggressively**.

I would therefore treat the two features as orthogonal in the language semantics, but deliberately design them to share the same internal `TypeInfo / Rep / Layout` machinery.

---

hmm yes this is a complex feature. please discuss the literature and prior art

---


Yes. This feature has substantial prior art, but no single tradition exactly matches what you are proposing. The closest synthesis is:

\[
\boxed{
\text{type-directed compilation}
+
\text{representation analysis}
+
\text{monomorphization}
+
\text{module/interface abstraction}
+
\text{implementation specialization}
}
\]

The unusual part in Rune would be making **whole data-structure implementations** selectable from static type facts while preserving one abstract signature.

Web search is disabled in this session, so I cannot verify bibliographic details against current sources. The works below are established literature I know.

## 1. The closest theoretical ancestor: intensional type analysis

Probably the most important paper for this idea is:

**Robert Harper and Greg Morrisett, _Compiling Polymorphism Using Intensional Type Analysis_ (1995).**

Ordinary parametric polymorphism treats types as erased information:

\[
\Lambda \alpha.e
\]

becomes code that cannot inspect \(\alpha\).

Harper and Morrisett instead preserve enough type information during compilation that code can make **type-directed choices**.

Conceptually:

```text
case type α of
    int    => ...
    string => ...
    _      => ...
```

This is extremely close to the underlying mechanism Rune needs.

The difference is philosophical.

They permit type information to participate fairly directly in compilation/execution, whereas for Rune I would strongly restrict such inspection to the **static implementation-selection layer**.

You don't want ordinary Rune functions doing:

```sml
if type 'a = int then ...
```

because that destroys ordinary parametric reasoning.

But you very much do want the compiler doing the equivalent while specializing.

So Harper–Morrisett gives you a formal basis for:

\[
Type \rightarrow CompileTimeDecision.
\]

---

# 2. TIL: type-directed optimization as compiler architecture

The next major reference is the TIL compiler:

**Tarditi, Morrisett, Cheng, Stone, Harper, Lee — _TIL: A Type-Directed Optimizing Compiler for ML_.**

TIL stands for **Typed Intermediate Language**.

The important design decision was to preserve rich type information far into compilation rather than erase it immediately after type checking.

That allows optimization based on information such as:

- whether something is a pointer;
- whether it can be unboxed;
- known representation;
- concrete datatype;
- calling convention;
- type-specific operations.

That architecture maps very naturally to what we've been designing for Rune.

Instead of:

```text
SML source
   ↓
typecheck
   ↓
erase types
   ↓
optimize
```

you want:

```text
Rune
 ↓
rich static type information
 ↓
module specialization
 ↓
representation selection
 ↓
typed optimization
 ↓
erase types relatively late
```

If Rune is going to do serious representation-dependent specialization, TIL is highly relevant.

---

# 3. FLINT and typed compiler IRs

The SML/NJ **FLINT** work belongs to the same general family.

The broad idea is to maintain an explicitly typed intermediate representation in which information about:

- polymorphism;
- type constructors;
- abstract types;
- representations;

remains available to optimizer passes.

Zhong Shao's work around FLINT, type-directed compilation and typed intermediate languages is therefore relevant.

This is particularly interesting for Rune because you're already considering a rich module calculus.

You could plausibly have:

```text
Surface SML/Rune
       ↓
higher-order module calculus
       ↓
typed polymorphic core
       ↓
representation-specialized core
       ↓
bytecode/native IR
```

rather than throwing the module/type information away after elaboration.

---

# 4. Xavier Leroy: unboxing polymorphic programs

A particularly relevant earlier paper is:

**Xavier Leroy, _Unboxed Objects and Polymorphic Typing_ (1992).**

The core problem is closely related.

Suppose:

```ml
'a list
```

is polymorphic.

If `'a = int`, you'd like to store integers efficiently.

But if `'a` is an arbitrary heap object, you may need pointers.

So polymorphism conflicts with efficient representation.

Leroy investigated how representation information can be reconciled with polymorphic typing.

Your proposed feature generalizes the question from:

> How should one value be represented?

to:

> Which complete container implementation should represent values of this abstract container type?

That's a natural next step.

---

# 5. Unboxing is the simplest form of your feature

A normal generic container might contain:

```text
pointer → boxed int
pointer → boxed int
pointer → boxed int
```

while:

```text
Vector int
```

could contain:

```text
42 | 17 | 93 | ...
```

directly.

That is **representation specialization**.

The literature on unboxing is therefore directly relevant.

Important strands include work on:

- unboxed values;
- worker/wrapper transformation;
- representation analysis;
- polymorphic unboxing;
- strictness analysis;
- unlifted types.

In Haskell, Peyton Jones and Launchbury's work on **unboxed values** is part of this history.

Rune's idea goes further because the specialization may change algorithms, not merely boxing.

---

# 6. Monomorphization is the second major ancestor

Another large body of prior art says:

Given:

\[
f : \forall\alpha.\alpha\rightarrow\alpha
\]

and actual applications:

```text
f<int>
f<string>
```

generate separate copies:

```text
f_int
f_string
```

Now each copy knows its concrete type.

This technique appears in:

- C++ templates;
- Rust generics;
- MLton;
- various ML compilers;
- native-code compilation of generic languages;
- partial evaluation.

Once you monomorphize:

```text
Map<'k,'v>
```

into:

```text
Map<int,string>
```

you have precisely the information required to choose another representation.

So Rune could treat:

\[
\text{implementation selection}
\]

as a stronger form of monomorphization.

Normal monomorphization:

\[
GenericMap<K,V>
\rightarrow
GenericMap<int,string>
\]

Rune:

\[
GenericMap<int,string>
\rightarrow
IntKeyMap<string>.
\]

The second step changes the implementation family.

---

# 7. MLton is particularly relevant

MLton's whole-program compilation strategy is an important practical precedent.

Because it sees the complete Standard ML program, it can perform aggressive:

- monomorphization;
- defunctorization;
- representation analysis;
- whole-program specialization;
- dead-code elimination.

That eliminates many abstraction costs which separate compilation otherwise preserves.

For Rune, you could make this an explicit part of the architecture:

```text
generic module representation
       ↓
whole-program concrete type discovery
       ↓
implementation-family selection
       ↓
monomorphic optimized program
```

The difference is that MLton generally specializes the existing program rather than selecting arbitrarily different user/library implementations based on type predicates.

Your proposal makes that choice first-class in the optimization model.

---

# 8. Partial evaluation is another theoretical interpretation

There is also a strong connection to **partial evaluation**.

Imagine:

```text
makeMap : TypeInfo -> MapImplementation
```

The generic program depends on some static input:

```text
TypeInfo(K)
```

If the compiler knows:

```text
K = int
```

then partial evaluation computes:

```text
makeMap(IntType)
```

at compile time and obtains:

```text
IntMap
```

So your feature can be viewed as:

\[
\text{module specialization}
=
\text{partial evaluation over static type information}.
\]

This connects to the large literature around:

- Futamura projections;
- binding-time analysis;
- offline/online partial evaluation;
- multi-stage programming.

You probably don't want to *implement* the feature using a general-purpose partial evaluator initially, but this is a useful semantic perspective.

---

# 9. C++ template specialization is probably the closest mainstream language mechanism

C++ permits:

```cpp
template<class T>
struct Container {
    // generic
};
```

and then:

```cpp
template<>
struct Container<int> {
    // completely different implementation
};
```

or partial specialization:

```cpp
template<class T>
struct Container<T*> {
    ...
};
```

That is extraordinarily close to:

```text
Container T
```

selecting implementation according to static type.

C++ therefore demonstrates that:

\[
\text{same apparent type constructor}
+
\text{different implementation per type}
\]

is workable.

But Rune can improve considerably on the C++ model.

C++ specialization is part of template semantics and can expose implementation differences relatively easily.

Rune could instead enforce:

\[
M_i : SIG
\]

for every implementation \(M_i\).

The specialization becomes an implementation refinement behind a semantic interface.

That's a much stronger abstraction model.

---

# 10. `std::vector<bool>` is the cautionary tale you should study

C++ has perhaps the most famous example of exactly your proposal going wrong.

`std::vector<T>` ordinarily behaves roughly like a dynamic contiguous array of `T`.

But `std::vector<bool>` has a specialized representation using bits.

That sounds ideal:

\[
Vector<bool>
\rightarrow
BitVector.
\]

Unfortunately, individual elements can no longer be represented by real `bool&` references.

So C++ had to introduce proxy-reference objects.

That means:

```cpp
v[i]
```

does not have quite the same semantics as ordinary `vector<T>::operator[]`.

This has caused decades of complaints.

It demonstrates the central rule Rune should enforce:

\[
\boxed{\text{representation specialization must not violate the abstract signature}}
\]

If your signature exposes something representation-sensitive like:

```sml
val addressOfElement : 'a vector -> int -> 'a ref
```

then bit-packing `bool` might be impossible.

If it exposes only:

```sml
val get : 'a vector * int -> 'a
val set : 'a vector * int * 'a -> unit
```

then the specialization remains invisible.

`vector<bool>` is probably the most useful practical warning in this entire area.

---

# 11. Standard ML itself chooses explicit specialized containers in the Basis Library

The SML Basis Library takes a conservative approach.

It has generic structures/interfaces, but also specialized monomorphic facilities such as byte and numeric arrays/vectors.

For example, the general pattern includes specialized constructs such as:

```text
Word8Array
Word8Vector
```

rather than asking the compiler to transform:

```text
Word8 Array.array
```

automatically.

This is semantically straightforward and predictable, but pushes specialization onto the programmer/library API.

Your proposed Rune feature is roughly:

> make those specialized implementations available internally, but allow `Array Word8` to select them automatically.

That is a plausible evolution from the Basis design.

---

# 12. OCaml's float arrays are a particularly important cautionary precedent

OCaml historically has special representation treatment for arrays of floating-point values.

Ordinary generic arrays generally hold tagged values/pointers, but floating-point arrays have used an unboxed representation.

That sounds attractive:

```text
array<float>
```

automatically becomes a specialized flat representation.

But it complicates:

- polymorphic array operations;
- runtime representation tests;
- code generation;
- generic functions;
- the relationship between static types and layouts.

This is almost exactly the kind of complexity you're contemplating.

OCaml's experience is useful because it demonstrates:

> automatic type-directed container specialization is possible, but becomes unpleasant if the specialization leaks into generic runtime semantics.

Rune can avoid much of that by performing specialization before a lower representation-polymorphic layer and by requiring a generic fallback.

---

# 13. Haskell usually makes container representation explicit instead

Haskell has traditionally offered separate types:

```text
Vector a
UnboxedVector a
StorableVector a
```

and similarly:

```text
Array
UArray
```

rather than having:

```text
Vector Int
```

automatically turn into an entirely different abstract representation.

Why?

Because representation affects constraints.

An unboxed vector cannot necessarily contain every possible Haskell type.

You therefore get things conceptually like:

```haskell
Unbox a => Vector a
```

This explicit approach makes type checking and abstraction straightforward but exposes representation decisions to the programmer.

Rune's approach would move that decision behind the interface.

---

# 14. GHC `SPECIALIZE`

Haskell does provide an important halfway point:

```haskell
{-# SPECIALIZE foo :: Int -> Int #-}
```

The programmer writes one polymorphic implementation, but the compiler generates a concrete optimized copy.

This preserves semantics:

\[
foo_{\text{generic}}
\equiv
foo_{\text{int}}
\]

while allowing very different generated code.

This is directly aligned with your design principle:

> specialization is an implementation decision, not source semantics.

Rune's implementation families would just permit a much larger replacement unit than a function body.

Instead of replacing:

```text
foo
```

you replace an entire:

```text
MAP module.
```

---

# 15. GHC's SpecConstr

Another very relevant piece of GHC research is Simon Peyton Jones's work on **call-pattern specialization**, implemented as the `SpecConstr` optimization.

The compiler notices repeated calls with known constructor shapes and produces specialized versions.

For example, conceptually:

```text
f (Cons x xs)
```

gets a version optimized specifically for `Cons`.

Again, this illustrates the general pattern:

\[
\text{generic program}
+
\text{static structural knowledge}
\rightarrow
\text{specialized implementation}.
\]

Rune's static knowledge happens to be about types and representations rather than constructor call patterns.

---

# 16. Rewrite rules and stream fusion show a related mechanism

GHC's `RULES` mechanism permits compiler-time replacement such as:

```text
generic operation composition
        ↓
specialized implementation
```

Stream fusion goes even further, replacing entire chains of collection operations with radically different generated loops.

For example:

```haskell
map f (filter p xs)
```

can eventually compile to a single loop without intermediate lists/vectors.

So modern functional compilers already accept that the runtime implementation can bear very little resemblance to the abstract source data structure.

What Rune adds is a structured, typed way of selecting the base container implementation itself.

---

# 17. Type classes are related but should probably not be the model

Type classes do:

\[
Type \rightarrow Dictionary.
\]

For example:

```haskell
Ord Int
```

selects an `Ord Int` dictionary.

That looks very similar to:

\[
Type \rightarrow MapImplementation.
\]

There is consequently a deep relationship between your feature and **ad-hoc polymorphism**.

Wadler and Blott's work on type classes is the classical reference.

But there is a critical semantic distinction.

With a type class:

```haskell
instance Ord Foo
```

the selected dictionary is generally part of program semantics.

Rune's container specialization ideally shouldn't be.

That suggests:

```text
type-class / trait selection
    = semantic evidence

implementation-family selection
    = optimization evidence
```

I would preserve that distinction.

---

# 18. Dictionary specialization is nevertheless useful prior art

Functional compilers frequently specialize type-class-constrained code.

Suppose:

```haskell
f :: Ord a => ...
```

normally receives a dictionary:

```text
OrdDict a
```

At `a = Int`, specialization can eliminate the dictionary and directly call integer comparison.

This gives:

```text
dynamic interface
       ↓
known concrete type
       ↓
known implementation
       ↓
devirtualized specialized code
```

That is almost exactly what you'd do with your module signatures.

The difference is scale: an entire data-structure implementation can be substituted.

---

# 19. Rust is useful mainly for monomorphization and coherence lessons

Rust generics are generally monomorphized.

Thus:

```rust
fn f<T>(...)
```

gets concrete machine-code instantiations for used `T`s.

Traits determine operations available on those types.

Rust has also spent considerable design effort around **specialization**, overlap, coherence and which implementation wins.

That matters because your implementation families will encounter the same issue:

```text
Rule 1: use PackedMap if FixedWidth K
Rule 2: use HashMap if Hash K
```

What happens when both apply?

Rust's experience suggests that unconstrained overlapping specialization rapidly becomes difficult.

Rune can make the problem easier by requiring that specialized implementations be semantically interchangeable and by defining a simple specificity order.

---

# 20. Scala `@specialized` is particularly relevant

Scala historically suffered heavily from generic primitive boxing on the JVM.

Its `@specialized` mechanism generates specialized variants for primitive instantiations.

Conceptually:

```scala
class Box[@specialized(Int, Double) T]
```

causes primitive-specific implementations.

This is directly relevant to:

```text
Container<int>
Container<double>
```

having different physical implementations.

The downside is combinatorial code growth.

If you specialize:

\[
n
\]

type parameters over:

\[
k
\]

representations, naive specialization may produce:

\[
k^n
\]

versions.

That is one of the major engineering issues Rune would need to address.

---

# 21. Miniboxing is worth studying

Research on **miniboxing** in Scala is especially relevant.

The core idea is to avoid generating a separate specialized class for every primitive instantiation.

Instead, multiple primitive types can share a compact representation, typically accompanied by a small tag describing which primitive is represented.

This explores the tradeoff between:

\[
\text{maximum specialization}
\]

and:

\[
\text{code size}.
\]

Rune will eventually face exactly that tradeoff.

You do not necessarily want:

```text
Vector<Int8>
Vector<Int16>
Vector<Int32>
Vector<Int64>
Vector<UInt8>
...
```

all to generate entirely independent copies of every operation.

You may instead classify types by **representation class**.

For example:

```text
RepWord32
RepWord64
RepFloat32
RepFloat64
RepPointer
RepAggregate
```

and specialize per class.

That is closely related to miniboxing.

---

# 22. .NET generics provide another important strategy

The .NET CLR made a notable compromise in its generics implementation.

Generic code can often be shared among reference-type instantiations because all references have compatible machine representations.

Value types, however, often get separately instantiated/specialized code.

Conceptually:

```text
List<String>
List<Object>
```

can share substantial implementation,

while:

```text
List<Int32>
```

may require a specialized representation/code path.

This is an important alternative to “one version per source type.”

The compiler/runtime specializes by:

\[
Rep(T)
\]

rather than necessarily by:

\[
T.
\]

That aligns extremely well with your `freshtype` model.

If:

```sml
freshtype UserId repr int
```

then:

```text
Map<UserId>
Map<int>
```

might share the same low-level representation-specialized implementation even while remaining nominally distinct at the source level.

---

# 23. Representation classes are probably more important than exact types

That suggests an important refinement for Rune.

Do not primarily specialize on:

```text
T = int
```

but on:

```text
Layout(T) = Word64
```

or:

```text
Capability(T) = DenseUnsignedKey
```

Then:

```text
int64
UserId repr int64
Timestamp repr int64
```

can all reuse one implementation.

This controls code explosion.

The literature on:

- representation polymorphism;
- runtime type passing;
- miniboxing;
- unboxing;

all points in this direction.

---

# 24. Representation polymorphism is a direct theoretical neighbour

Representation polymorphism asks how one abstraction can work over types with different runtime representations.

For example:

```text
Int#      unboxed integer
Double#   unboxed float
Object    pointer
```

A naïvely polymorphic:

```text
identity : ∀a. a -> a
```

cannot necessarily use one calling convention for all of them.

Modern GHC tackles this with concepts such as:

- runtime representations;
- levity;
- representation polymorphism.

The interesting relation to Rune is:

\[
Rep(T)
\]

becoming part of static kind/type information.

Instead of:

```text
T : Type
```

you might eventually have something conceptually like:

\[
T : Type(Rep).
\]

That would make implementation selection based on representations much more principled.

---

# 25. Polytypic and generic programming are adjacent but different

There is also a substantial literature on:

- polytypic programming;
- Generic Haskell;
- datatype-generic programming;
- Scrap Your Boilerplate;
- generic derivation.

These systems allow programs to vary according to the **structure of types**.

For example:

```text
type is sum     → do this
type is product → do that
type is recursive → ...
```

This is similar to Rune's implementation selector inspecting static type properties.

But generic programming typically derives **operations** from datatype structure.

You want to derive/select **implementations**.

Still, the type-reflection and specialization machinery has significant overlap.

---

# 26. Multi-stage programming is another useful comparison

Multi-stage languages make the distinction between:

- compile-time computation;
- later runtime computation

explicit.

Your implementation selection is naturally staged:

\[
Stage_0:
\text{inspect static type information}
\]

\[
Stage_1:
\text{execute selected data structure}.
\]

MetaML and later staging systems provide theory for ensuring stage correctness.

You probably do not need to expose quotation/splicing to Rune programmers just to implement this feature.

But internally:

```text
implementation family
```

is a form of restricted compile-time metaprogram.

---

# 27. Julia shows the extreme dynamic end

Julia specializes methods aggressively according to inferred runtime argument types.

A single generic function can get many machine-code specializations.

This permits highly generic high-level programs while producing code close to manually specialized implementations.

However, Julia generally performs this via JIT compilation and dynamic dispatch/type inference.

Rune would instead perform the analogous decisions statically.

So Julia is relevant less as a semantic model than as evidence that:

\[
\text{high-level generic abstraction}
+
\text{aggressive type specialization}
\]

can be a central language strategy.

---

# 28. Database query optimization is an interesting conceptual analogue

There is also a surprisingly useful analogy with databases.

SQL specifies:

\[
\text{what result is wanted}
\]

rather than:

\[
\text{which algorithm implements it}.
\]

The optimizer chooses:

```text
nested-loop join
hash join
merge join
```

depending on static/runtime facts.

Your `Map` interface could behave similarly:

```text
program specifies MAP semantics
```

while the compiler chooses:

```text
red-black tree
HAMT
radix tree
dense array
```

according to available facts.

That's a stronger abstraction principle than normal generic programming.

Conceptually Rune would have a small **implementation optimizer** rather than merely overload resolution.

This analogy becomes useful once you start thinking about cost models.

---

# 29. Cost-based selection would be the next research step

Suppose both are valid:

```text
IntMap
HashMap
```

Which should Rune choose?

A fixed specificity hierarchy is simple.

But eventually you could attach cost models:

\[
Cost(I,T,W)
\]

where:

- \(I\) = implementation;
- \(T\) = key/value type information;
- \(W\) = expected workload.

Then choose:

\[
\arg\min_I Cost(I,T,W).
\]

That starts resembling:

- database query optimization;
- auto-tuning;
- superoptimization;
- algorithm selection.

There is an entire algorithm-selection literature going back to Rice's work on the **algorithm selection problem**.

This is further than I would go initially, but it is the natural destination of the idea.

---

# 30. Auto-tuning systems are relevant once selection is performance-based

Systems such as:

- ATLAS;
- FFTW;
- SPIRAL;

select or synthesize implementations based on machine characteristics and problem structure.

Their principle is:

\[
\text{same semantics}
+
\text{many implementations}
\rightarrow
\text{choose optimized implementation}.
\]

Rune could eventually incorporate:

```text
type properties
+
target CPU
+
profile data
```

into implementation-family selection.

For example:

```text
Map<int>
```

might become:

```text
BTreeMap
```

on one target and:

```text
SwissTable-style HashMap
```

on another.

Again, semantically invisible.

---

# 31. Separate compilation is where things get difficult

Type-directed specialization is easiest with whole-program compilation.

Suppose library `A` exports:

```sml
val process : 'k Map.map -> ...
```

and library `B` later instantiates `'k = int`.

If `A` has already been compiled to machine code, how do you specialize it?

The literature offers several strategies.

### Generate only generic code

Simple, but misses optimization.

### Export typed IR

Later compilation units can specialize it.

This is roughly the direction of:

- C++ templates;
- LLVM bitcode/LTO;
- some generic compiler schemes.

### Generate generic + selected specialized versions

For common representations.

### Link-time specialization

Perform specialization during LTO.

### Runtime/JIT specialization

Julia/.NET style.

For Rune, typed bytecode or typed intermediate modules could make link-time specialization particularly attractive.

---

# 32. This connects to your module system more than it first appears

Suppose:

```sml
functor Graph (M : MAP) = ...
```

The compiler initially has:

\[
Graph : MAP\rightarrow GRAPH.
\]

Later static type information says:

```text
key = int
```

and implementation resolution chooses:

```text
M = IntMap.
```

Then ordinary applicative functor specialization yields:

\[
Graph(IntMap).
\]

That means the module calculus itself can serve as the **representation-independent specification layer**, while ordinary compiler specialization eliminates the abstraction.

This is a very ML-like way to express the feature.

---

# 33. Existential abstraction interacts with specialization

Suppose an API exports:

```sml
type key
```

and hides:

```text
key = UserId
repr UserId = int64.
```

Should another compilation unit be able to choose `Int64Map`?

This becomes a question of **optimization transparency**.

Traditional existential abstraction says:

\[
\exists\alpha.M
\]

and deliberately prevents the client from knowing \(\alpha\).

But the compiler itself might retain secret representation metadata.

There is substantial literature on:

- representation independence;
- abstraction-preserving compilation;
- type abstraction in typed IRs.

This is where Rune's proposed `freshtype` and implementation families genuinely interact.

You want:

\[
\text{source abstraction}
\]

without necessarily requiring:

\[
\text{optimizer ignorance}.
\]

That is an interesting design point.

---

# 34. The key safety theorem would be contextual equivalence

Suppose:

\[
I_1 : MAP
\]

and:

\[
I_2 : MAP.
\]

Your specialization mechanism should be allowed to replace \(I_1\) with \(I_2\) only if clients cannot distinguish them through the public interface:

\[
I_1 \approx_{MAP} I_2.
\]

This is essentially a **representation independence** theorem.

Logical relations are the standard tool for formalizing this.

That is perhaps the theoretically cleanest answer to:

> When is compiler-selected implementation replacement valid?

Not merely when the modules type-check against the same signature.

Two modules can satisfy the same ML signature and still behave differently.

For example:

```sml
val lookup : key -> map -> value option
```

could be implemented incorrectly in one of them.

Type checking alone doesn't establish semantic equivalence.

So Rune needs to treat the implementations as **asserted or verified refinements**, not merely signature-compatible modules.

---

# 35. You probably need two levels of contract

Something like:

```text
Signature:
    operations and types

Implementation family contract:
    all members must implement the same abstract semantics
```

The compiler can mechanically check the first.

The second is generally a programmer/library-author assertion unless you introduce proofs.

So:

```sml
specialization IntMap
    implements Map
```

means more than:

```sml
IntMap : MAP
```

It promises semantic substitutability.

This is analogous to a compiler rewrite rule being trusted to preserve meaning.

---

# 36. The literature splits exactly where your feature splits

I would map the research like this:

| Rune problem | Closest literature |
|---|---|
| Know concrete type during compilation | intensional type analysis |
| Preserve type information late | TIL / FLINT |
| Specialize generic code | monomorphization / partial evaluation |
| Choose representation | unboxing / representation analysis |
| Group types by runtime representation | representation polymorphism / miniboxing / CLR generics |
| Select behavior from types | type classes / traits |
| Select whole alternative implementation | C++ template specialization |
| Preserve abstract API | ML modules / existential types |
| Ensure substitutions are unobservable | representation independence / logical relations |
| Avoid code explosion | miniboxing / code sharing |
| Choose among several fast implementations | algorithm selection / auto-tuning |
| Make specialization cross modules | LTO / typed IR / staged compilation |

There really isn't one literature to read. This feature lies across all of them.

---

# 37. The prior art suggests three increasingly powerful Rune designs

### Level 1: monomorphic representation specialization

Only select storage layout.

```text
Vector<int>
→ PackedIntVector
```

while keeping the same algorithm.

This is relatively well understood.

---

### Level 2: capability-based implementation specialization

For example:

```text
Map<K,V>
```

becomes:

```text
DenseMap
```

if:

```text
DenseIndex K
```

or:

```text
HashMap
```

if:

```text
Hash K
```

or otherwise:

```text
TreeMap.
```

This starts resembling trait/type-class specialization.

---

### Level 3: cost-based algorithm selection

Choose among semantically interchangeable implementations based on:

```text
type
layout
target architecture
profile information
expected workload
```

This becomes closer to database optimization/auto-tuning.

I would regard Level 2 as the interesting target for Rune, with Level 1 as the implementation starting point.

---

# 38. The strongest caution from prior art

Several systems teach the same lesson:

**do not let physical representation become accidentally observable.**

C++ `vector<bool>` is one warning.

OCaml float arrays are another.

Java's distinction between primitives and objects is another.

Haskell's proliferation of:

```text
Vector
Unboxed.Vector
Storable.Vector
```

shows the opposite conservative choice.

Rune has an opportunity to do something cleaner because you already have an ML-style abstraction system.

You can say:

\[
\boxed{\text{representation is an implementation property, unless explicitly exposed}}
\]

and make specialization respect that rule.

---

# 39. The papers/areas I would put at the top of the reading list

For this specific Rune feature, I would start with roughly:

1. **Harper & Morrisett — _Compiling Polymorphism Using Intensional Type Analysis_**  
   The fundamental type-directed-selection idea.

2. **Tarditi et al. — _TIL: A Type-Directed Optimizing Compiler for ML_**  
   How to build a compiler that retains enough type information to exploit it.

3. **Leroy — _Unboxed Objects and Polymorphic Typing_**  
   Representation specialization under polymorphism.

4. **MLton's whole-program specialization/monomorphization work**  
   Closest SML engineering precedent.

5. **Wadler & Blott / subsequent type-class literature**  
   Type-indexed implementation selection and coherence.

6. **C++ template specialization literature and practice**  
   Whole implementation selection according to type.

7. **GHC `SPECIALIZE`, worker/wrapper and SpecConstr work**  
   Semantics-preserving specialization of polymorphic programs.

8. **Scala specialization/miniboxing research**  
   Critical for understanding specialization/code-size tradeoffs.

9. **Kennedy & Syme on .NET generics**  
   Representation-based generic code sharing versus specialization.

10. **Representation-independence/logical-relations literature**  
    For the semantic justification of replacing implementations behind an interface.

Then I would look at `std::vector<bool>` and OCaml float arrays not because they are elegant, but because they illustrate exactly what can go wrong.

---

The larger conceptual point is that your feature is not really “generic containers with some optimizations.” It is closer to a **static implementation-selection calculus**:

\[
\boxed{
(\text{abstract interface},
\text{static type facts},
\text{representation facts},
\text{capabilities})
\longrightarrow
\text{concrete module implementation}
}
\]

while preserving the source-level abstraction.

That is a fairly powerful idea, and the existing literature supplies nearly all the pieces separately. The interesting Rune contribution would be integrating them coherently with the higher-order module system and `freshtype` representation information rather than exposing them as unrelated compiler pragmas.

---

so earlier we discussed a module-based build language for rune. i think this could be relevant here. e.g. the build for a program would import the build of basis library. the basis library in it's build program could specify allowable optimizations to the compiler (since it is a closed universe and it knows which optimization are safe within basis). how would this work?

---

Yes. I think the module-based build language is the right place to control this feature.

The clean design is for a library build to export **three things**, not just compiled code:

\[
\boxed{
\text{public interface}
+
\text{compiled implementation}
+
\text{optimization contract}
}
\]

The optimization contract says, in effect:

> “For values and operations belonging to this library, these alternative representations and implementations are semantically interchangeable under these statically checkable conditions.”

The application build imports that contract, but the **final compiler invocation** decides which alternatives to use once it knows concrete types, target architecture, whole-program information, etc.

## 1. Basis should describe possibilities, not choose them

Suppose Basis provides:

```sml
signature VECTOR =
sig
    type 'a vector

    val fromList : 'a list -> 'a vector
    val sub      : 'a vector * int -> 'a
    val length   : 'a vector -> int
end
```

Internally it might contain:

```text
GenericVector
Word8Vector
IntVector
RealVector
BitVector
```

The Basis build could export rules saying:

```text
Vector word8   may use Word8Vector
Vector int     may use PackedIntVector
Vector real    may use PackedRealVector
Vector bool    may use BitVector
otherwise      use GenericVector
```

But Basis shouldn't resolve those while compiling Basis because it doesn't yet know how downstream programs instantiate polymorphic code.

Instead:

```text
Basis build
      │
      ├── basis code
      ├── basis signature
      └── optimization catalogue
                         │
                         ▼
Application build imports all three
                         │
                         ▼
whole-program / link-time specialization
                         │
                         ▼
actual implementations selected
```

That gives the compiler the final word while allowing the library author to define the safe search space.

---

# 2. The build output becomes richer

Something conceptually like:

```sml
signature BUILD_EXPORT =
sig
    val units         : Build.unit list
    val interface     : Interface.t
    val optimizations : Optimize.catalog
end
```

Then:

```sml
structure BasisBuild : BUILD_EXPORT =
struct
    val units =
        Build.library
        {
            name = "basis",
            sources = [...]
        }

    val interface =
        Interface.fromModule Basis

    val optimizations =
        Optimize.catalog
        [
            ...
        ]
end
```

And an application:

```sml
structure Basis =
    Build.import "basis/build.rune"

structure App =
    Build.program
    {
        sources = [...],
        dependencies = [Basis.units]
    }

val result =
    Compiler.build
    {
        program = App,
        optimizations = Basis.optimizations
    }
```

So importing a dependency's build description automatically imports its permitted optimizer knowledge.

---

# 3. The important object is an optimization contract

I'd make each rule more structured than a rewrite pragma.

Conceptually:

```haskell
data Optimization = Optimization
  { family      :: ImplementationFamily
  , predicate   :: StaticPredicate
  , replacement :: ModuleImpl
  , evidence    :: EquivalenceEvidence
  , scope       :: OptimizationScope
  , phase       :: OptimizationPhase
  }
```

A Basis rule might mean:

```text
family:
    Basis.Vector

condition:
    element layout = Word8

replacement:
    Basis.Private.Word8Vector

evidence:
    Word8Vector implements VECTOR semantics

scope:
    whole-program

phase:
    after type specialization
```

The compiler doesn't trust an arbitrary pattern rewrite like:

```text
Vector<a> → Foo
```

It consumes a typed optimization object.

---

# 4. Your higher-order module calculus gives this a very elegant formulation

Recall that Rune now has stable applicative module functions.

You could model an implementation family conceptually as:

\[
VectorRep : Type \rightarrow Module.
\]

For example:

```sml
implementation family VectorRep (E : TYPE)
    : VECTOR_REP
    where type elem = E.t
=
    when layout E.t = Word8
        => Word8VectorRep

    when layout E.t = Int64
        => Int64VectorRep

    when layout E.t = Float64
        => Real64VectorRep

    otherwise
        => GenericVectorRep(E)
```

This is effectively an applicative static function:

\[
VectorRep(E).
\]

Same static type input means same selected representation within a build.

That works extremely naturally with the higher-order module system.

---

# 5. But the public type should not change identity

This is an important design point.

I would **not** define:

```text
Vector int = IntVector.t
Vector string = StringVector.t
```

at the nominal type level.

Otherwise optimizer decisions leak into type identity.

Instead the Basis API owns one abstract nominal type constructor:

\[
Vector.vector : Type \rightarrow Type.
\]

Then internally the compiler knows a hidden representation equation:

\[
Rep(Vector.vector\;T)
=
Rep(VectorRep(T).t).
\]

So the public program still sees:

```sml
int vector
```

regardless of implementation.

Internally:

```text
int vector
    repr
PackedIntVector.t
```

might hold.

This plugs directly into the `freshtype` machinery we just designed.

---

# 6. This gives a very nice synthesis with `freshtype`

You can think of Basis as defining something morally like:

```sml
freshtype 'a vector
    repr VectorRep('a).t
```

although you probably wouldn't expose syntax exactly like that.

The important relationship is:

\[
Vector\,T \not\equiv VectorRep(T).t
\]

but:

\[
Vector\,T \approx_R VectorRep(T).t.
\]

The Basis source interface hides that representation witness.

The compiler's optimization environment retains it.

So:

```text
source type checker:
    Vector int is abstract

optimizer:
    Rep(Vector int) = PackedIntVector
```

This is exactly the distinction we wanted earlier between **programmer-visible facts** and **optimizer-visible facts**.

---

# 7. Basis can safely reveal more to the optimizer than to programs

Suppose:

```sml
structure Vector :> VECTOR = ...
```

The programmer should not gain access to implementation details.

But the compiler can retain something like:

```text
PUBLIC KNOWLEDGE
────────────────

Vector.vector : Type -> Type


COMPILER-PRIVATE KNOWLEDGE
──────────────────────────

Rep(Vector.vector word8)
    = Word8Vector.t

Rep(Vector.vector real)
    = RealVector.t

Rep(Vector.vector T)
    = GenericVector(T).t      otherwise
```

Opaque abstraction remains intact at the source-language level.

This gives you:

\[
\boxed{
\text{semantic abstraction without optimization blindness}
}
\]

which is a very desirable property.

---

# 8. The build system is the right authority for this knowledge

Why shouldn't the compiler simply recognize `Vector` by name?

Because that produces compiler magic like:

```text
if moduleName == "Basis.Vector" ...
```

which becomes brittle and unextensible.

Instead Basis itself exports:

```text
optimization capability
```

alongside its artifact.

That means a third-party library could do exactly the same thing.

For example:

```text
Graph
Matrix
Map
Tensor
DatabaseIndex
```

could each export specialization families.

The compiler only understands the generic mechanism.

It does not know what a vector or a map is.

That's architecturally much cleaner.

---

# 9. This resembles GHC RULES, but at module scale

GHC libraries can provide rewrite rules roughly saying:

```text
when you see this expression,
replace it with that expression
```

Rune's version would be much more structured:

```text
when static facts satisfy P,
this abstract module family may be implemented by M
```

So instead of an expression rule:

\[
f(g(x)) \rightarrow h(x)
\]

you have:

\[
Map(K,V) \rightarrow IntMap(V)
\]

subject to:

\[
K = int.
\]

Or:

\[
Vector(T) \rightarrow PackedVector(T)
\]

subject to:

\[
Flat(T)\land Size(T)\le 8.
\]

That's essentially **module-level specialization rules**.

---

# 10. There should be different categories of optimization facts

I'd distinguish at least three.

### Representation facts

For example:

```text
Rep T = Int64
Size T = 8
Align T = 8
PointerFree T
```

These can normally affect storage.

---

### Semantic capabilities

For example:

```text
Eq T
Ord T
Hash T
DenseIndex T
BitwiseEq T
```

These justify algorithm choices.

---

### Exact nominal identity

For example:

```text
T = int
T = string
```

These should be used relatively rarely.

This distinction matters enormously.

---

# 11. Example: your `freshtype UserId`

Suppose:

```sml
freshtype UserId repr int
```

Then:

\[
UserId\not\equiv int
\]

but:

\[
Rep(UserId)=Rep(int).
\]

A vector specialization requiring:

```text
Rep element = int64
```

may therefore use packed integer storage.

Good.

But a map optimization requiring:

```text
integer numeric ordering
```

cannot automatically apply.

`UserId` might define a different ordering.

So:

```text
repr T = int
```

can justify:

```text
packed 64-bit storage
```

but not necessarily:

```text
integer comparison algorithm.
```

For that you need something stronger, perhaps:

```text
OrderRepresentation T = SignedIntegerOrder
```

or a capability:

```text
RadixOrder T
```

This is exactly why separating representation facts from semantic facts pays off.

---

# 12. Basis could define special capabilities invisible to normal programs

For example:

```text
BitwiseEq T
RadixSortable T
DenseIndex T
NoPointers T
ZeroIsValid T
```

These need not necessarily be ordinary user-facing interfaces.

They might be static optimization properties.

Then:

```sml
specialize Map
    when RadixSortable key
    using RadixMap
```

rather than:

```sml
specialize Map
    when key = int
```

This makes specializations reusable for:

```text
int
word
UserId repr word64
Timestamp repr word64
```

provided their semantic contracts really permit it.

---

# 13. A Basis build file might therefore look like this

Conceptually:

```sml
structure BasisBuild =
struct
    structure Basis =
        Build.library
        {
            sources =
                [ "array.rn",
                  "vector.rn",
                  "string.rn",
                  "word8-vector.rn",
                  "real-vector.rn" ]
        }

    structure VectorFamily =
        Optimize.Family
        (
            type Parameter = Type

            signature Interface = VECTOR

            val default =
                Basis.Private.GenericVector

            val candidates =
                [
                    Optimize.when
                    {
                        predicate =
                            Layout.isWord8,

                        implementation =
                            Basis.Private.Word8Vector,

                        contract =
                            Basis.Proofs.word8Vector
                    },

                    Optimize.when
                    {
                        predicate =
                            Layout.isFloat64,

                        implementation =
                            Basis.Private.RealVector,

                        contract =
                            Basis.Proofs.realVector
                    }
                ]
        )

    val optimizations =
        Optimize.export
        [
            VectorFamily.catalog
        ]
end
```

I wouldn't necessarily use that exact syntax, but that's the model.

---

# 14. The application build composes catalogs

Suppose:

```sml
structure Basis =
    Build.import "basis/build.rune"

structure Collections =
    Build.import "collections/build.rune"

structure LinearAlgebra =
    Build.import "linalg/build.rune"
```

Then:

```sml
val optimizationCatalog =
    Optimize.union
    [
        Basis.optimizations,
        Collections.optimizations,
        LinearAlgebra.optimizations
    ]
```

The final compiler sees one optimization environment.

This naturally makes optimization modular.

---

# 15. The build language can also restrict scope

Not every optimization should be usable everywhere.

I'd define something like:

```sml
datatype optimization_scope =
      WithinLibrary
    | RecompiledDependents
    | WholeProgram
    | ABIStable
```

These mean different things.

### `WithinLibrary`

Only Basis itself may use it.

Representation can change freely internally.

### `RecompiledDependents`

Safe when the library and dependent code are specialized together.

### `WholeProgram`

Requires closed-world compilation.

Useful for aggressive container representation changes.

### `ABIStable`

Safe even across precompiled boundaries.

Usually much more restrictive.

This becomes very important for shared libraries, plugins and FFI.

---

# 16. Example of why scope matters

Suppose:

```text
Vector int
```

normally has generic boxed representation.

You want:

```text
Vector int → PackedIntVector
```

If a precompiled shared library expects the generic representation, you cannot silently pass a packed vector through that ABI.

So the optimization catalogue might say:

```text
PackedIntVector specialization:
    requires = RecompiledDependents
```

or:

```text
requires = WholeProgram.
```

Whereas:

```text
replace generic integer comparison
with machine integer comparison
```

might be ABI-neutral and permitted much more widely.

---

# 17. The final compilation pipeline becomes staged

I would arrange it roughly like:

```text
1. Parse/typecheck source
        ↓
2. Elaborate modules
        ↓
3. Load dependency optimization catalogs
        ↓
4. Collect static type/layout/capability facts
        ↓
5. Monomorphize / discover concrete instantiations
        ↓
6. Resolve implementation families
        ↓
7. Re-specialize affected higher-order modules
        ↓
8. Defunctorize / inline
        ↓
9. Representation lowering
        ↓
10. Bytecode/native code
```

And potentially iterate stages 5–7 until stable.

For example:

```text
specialize Graph<int>
    ↓
discovers Map<int,_>
    ↓
select IntMap
    ↓
specialize Graph(IntMap)
    ↓
more calls become inlineable
```

This can expose further optimization opportunities.

---

# 18. The optimization family itself can be higher order

This is where your higher-order module system becomes unexpectedly useful.

Imagine:

```text
ChooseMap :
    TYPE
    -> MAP_IMPLEMENTATION
```

and:

```text
Graph :
    MAP_IMPLEMENTATION
    -> GRAPH
```

Then specialization naturally computes:

\[
Graph(ChooseMap(Int)).
\]

Since `ChooseMap` is static and applicative, this is just ordinary module composition.

You don't need an unrelated compiler subsystem for every optimization.

The build-level selector can produce normal module expressions that your existing module elaborator already understands.

That is elegant.

---

# 19. The build language itself can manipulate these selectors

Because your build language can operate on modules, it can construct compiler variants such as:

```sml
val release =
    Compiler.build
    {
        optimizations =
            Optimize.allImported ()
    }

val conservative =
    Compiler.build
    {
        optimizations =
            Optimize.onlyABIStable
                (Optimize.allImported ())
    }

val baseline =
    Compiler.build
    {
        optimizations =
            Optimize.none
    }
```

You can even benchmark:

```text
baseline generic containers
vs
representation specialization
vs
algorithm specialization
```

using the same source program.

This ties directly into your earlier goal of using the build language to generate compiler/program variants for correctness and performance comparison.

---

# 20. This is especially powerful for validating optimizations

Because the build system can generate variants, Basis could include tests saying:

```text
compile program with specialization disabled
compile program with specialization enabled

run same test corpus

compare observable results
```

For example:

```sml
val generic =
    Build.withOptimizations program Optimize.none

val specialized =
    Build.withOptimizations program Basis.optimizations

val test =
    Test.differential
    {
        reference = generic,
        candidate = specialized,
        suite = BasisTests.all
    }
```

That doesn't mathematically prove correctness, but it makes differential testing easy.

Given your build/benchmark provenance system, you can make this extremely systematic.

---

# 21. A stronger design allows proof/certificate levels

Optimization contracts could carry different evidence:

```sml
datatype evidence =
      CompilerChecked
    | Proof of Proof.term
    | DifferentiallyTested of TestManifest.t
    | TrustedLibraryAssertion
```

The compiler doesn't necessarily need to understand all of these semantically.

But it can enforce policy.

For example:

```text
--safe
    only CompilerChecked / Proof

--trusted-basis
    allow Basis assertions

--experimental
    allow all imported optimization rules
```

I would definitely treat Basis differently from arbitrary third-party packages.

The Basis library and runtime are effectively part of Rune's trusted computing base anyway.

---

# 22. But don't give build scripts arbitrary compiler internals

I would resist:

```sml
Compiler.registerRewrite
    (fn ir => arbitraryIRMutation ir)
```

for ordinary libraries.

That turns build scripts into compiler plugins and creates:

- compiler crashes;
- unsound IR;
- optimizer-version coupling;
- nondeterministic builds;
- security problems.

Instead let libraries export a **declarative typed optimization language**.

For example:

```text
implementation family
representation equation
rewrite rule
intrinsic mapping
capability implication
cost hint
```

The compiler remains responsible for applying these safely.

This is very similar to the distinction between:

```text
compiler plugin
```

and:

```text
GHC RULES-like declarative metadata.
```

For Basis itself you could have a privileged escape hatch, but I would keep it exceptional.

---

# 23. You also want artifact fingerprints

An optimization catalogue must be tied to the exact library implementation it describes.

Otherwise:

```text
Basis 1.7 binary
+
Basis 1.8 optimization metadata
```

could be disastrous.

So every exported rule should implicitly depend on:

```text
library artifact hash
source version
compiler ABI/version
target/runtime ABI
```

Conceptually:

```haskell
data OptimizationCatalog = Catalog
  { owner       :: ArtifactHash
  , compilerABI :: CompilerABI
  , rules       :: [Optimization]
  }
```

This fits very naturally into the provenance tracking you already wanted for Rune's build system.

---

# 24. Closed-world declarations should be explicit

You mentioned Basis being a closed universe.

I would let a build state exactly what is closed.

For example:

```sml
val basis =
    Build.library
    {
        ...
        world =
            Build.closed
            {
                implementations =
                    [Vector,
                     Array,
                     String]
            }
    }
```

This tells the optimizer:

> No unknown external implementation of these internal interfaces will appear.

That's much stronger than ordinary module abstraction.

It enables things like exhaustive implementation selection and devirtualization.

But it should not mean the whole application is closed.

The final build can compose closed regions:

```text
Basis: closed internally
Collections: closed internally
Application: whole-program closed
```

This gives a hierarchy of optimization domains.

---

# 25. There is an interesting analogy to link-time optimization

Ordinary LTO says:

> give the linker IR instead of opaque object code so it can optimize across translation-unit boundaries.

Rune could go further:

> give downstream builds not only typed IR, but also **library-authored optimization laws**.

So an imported artifact becomes something like:

```text
Code
Interface
Typed IR
Optimization catalog
Representation metadata
Provenance
```

rather than merely:

```text
.o file
```

That could be an unusually strong compilation model.

---

# 26. Basis can declare implementation families while remaining portable

For example:

```text
Vector<word8>
```

might have candidates:

```text
PortableWord8Vector
SSE2Word8Vector
AVX2Word8Vector
AVX512Word8Vector
NEONWord8Vector
```

The Basis build exports all of them with predicates:

```text
Target.Has AVX512
Target.Has AVX2
...
```

The application build selects according to target:

```text
x86_64-v3
```

or perhaps produces multiple runtime-dispatch versions.

Now the optimization family depends on:

\[
TypeFacts
\times
TargetFacts.
\]

This is another reason the choice belongs at final program build rather than Basis build.

---

# 27. You can eventually add cost models without changing the architecture

Initially:

```text
when P1 -> A
when P2 -> B
otherwise -> G
```

is enough.

Later:

```text
candidate A:
    requirements P
    estimated cost C_A
```

and:

```text
candidate B:
    requirements Q
    estimated cost C_B
```

Then the compiler chooses the lowest-cost valid implementation.

So:

\[
Resolve(F,T)
=
\arg\min_{I\in Valid(F,T)} Cost(I,T,Target).
\]

The build-level interface doesn't need a fundamental redesign.

That leaves room for profile-guided or architecture-specific selection later.

---

# 28. I would make the optimization metadata part of the library's contract, but not its API

There are therefore really two signatures for a Rune library:

```text
PROGRAMMER SIGNATURE
────────────────────

What programs may assume.


OPTIMIZER CONTRACT
──────────────────

What the compiler may assume.
```

For Basis:

```text
programmer:
    type 'a Vector.vector is abstract

optimizer:
    Vector.vector T has representation family VectorRep(T)

programmer:
    UserId.t is abstract

optimizer:
    Rep(UserId.t) = Int64

programmer:
    Map operations satisfy MAP

optimizer:
    If RadixKey K, RadixMap is interchangeable with GenericMap
```

This division strikes me as central to the design.

---

## The resulting architecture

I would make an imported Rune build artifact roughly:

```text
BuildArtifact
├── public interface
├── compiled code / typed IR
├── private representation metadata
├── exported optimization catalogue
│   ├── representation specializations
│   ├── implementation families
│   ├── rewrite rules
│   ├── capability facts
│   └── target-specific alternatives
├── applicability scopes
├── correctness evidence / trust level
└── provenance + fingerprints
```

Then your application build does something conceptually like:

```sml
structure Basis =
    import "basis/build"

structure Program =
    Build.program ...

val executable =
    Compiler.compile
    {
        program       = Program,
        dependencies  = [Basis],
        optimizations = Optimize.fromDependencies [Basis],
        mode          = WholeProgram
    }
```

The attractive part is how the three Rune ideas now reinforce each other:

\[
\boxed{
\begin{array}{c}
\text{higher-order modules}\\
\downarrow\\
\text{express alternative implementations compositionally}
\\[6pt]
\texttt{freshtype}/representation equality\\
\downarrow\\
\text{retain abstraction while exposing private layout facts}
\\[6pt]
\text{module-based build language}\\
\downarrow\\
\text{libraries declare which substitutions are valid}
\end{array}}
\]

So the build language isn't merely orchestrating files. It becomes the place where **a library communicates its optimization theory to the compiler**. That is a substantially more interesting role, and it avoids hard-wiring Basis-specific knowledge into the Rune compiler itself.

---

list research literature and prior art in this area

---

The closest prior art is spread across several literatures. There is not, as far as I know, one established system that does exactly:

\[
\text{library build exports}
\quad
\{\text{code, interface, private representation facts, admissible optimizations}\}
\]

and then lets a downstream program build import those optimization contracts and apply them under closed-world knowledge.

But many pieces exist separately. For Rune, I would study them in roughly six clusters.

## 1. Library-supplied rewrite rules: GHC is the closest direct precedent

The most directly relevant practical mechanism is **GHC RULES**.

A library can ship rules such as:

```haskell
{-# RULES
"map/map" forall f g xs.
    map f (map g xs) = map (f . g) xs
#-}
```

The rule is defined by the library and consumed by the optimizer of downstream clients.

That is very close to your idea:

> the library knows transformations that are valid for its abstractions, so it communicates those transformations to the compiler.

Important work and documentation around this area includes:

- Simon Peyton Jones et al., work on **GHC rewrite rules**
- **Playing by the Rules: Rewriting as a practical optimisation technique in GHC**
- GHC work on `INLINE`, `SPECIALIZE`, worker/wrapper, SpecConstr, and fusion
- Andrew Gill, John Launchbury, Simon Peyton Jones, **A Short Cut to Deforestation**

The central precedent is:

\[
\boxed{\text{optimization knowledge can belong to the library}}
\]

rather than being hardcoded into the compiler.

Rune would generalize this from expression-level equations:

\[
f(g(x)) \Rightarrow h(x)
\]

to module-level choices:

\[
Vector(T)
\Rightarrow
PackedVector(T)
\]

under static predicates.

### Where Rune would improve on RULES

GHC RULES are essentially trusted equations.

Rune could make rules substantially more structured:

```text
family
precondition
replacement module
scope
ABI constraints
evidence/trust
target conditions
```

rather than arbitrary term rewriting.

That would make them more like **typed optimization contracts** than pragmas.

---

# 2. Stream fusion and library/compiler co-design

The collection/fusion literature is particularly relevant because it shows libraries deliberately exposing an intermediate representation that is meant to disappear during optimization.

Important examples include:

- Andrew Gill, John Launchbury, Simon Peyton Jones, **A Short Cut to Deforestation**
- Duncan Coutts, Roman Leshchinskiy, Don Stewart, **Stream Fusion: From Lists to Streams to Nothing at All**
- vector library stream-fusion work in Haskell
- shortcut fusion / foldr-build fusion

The interesting architecture is:

```text
nice public API
        ↓
library-defined internal representation
        ↓
compiler rewrite rules
        ↓
radically different generated program
```

That is conceptually very close to:

```text
Map API
        ↓
library-defined implementation family
        ↓
compiler static selection
        ↓
IntMap / Trie / GenericMap
```

The lesson is that **library abstractions can intentionally be designed together with optimizer metadata**.

This is one of the strongest precedents for the Basis library exporting optimization knowledge.

---

# 3. Cross-module optimization and typed intermediate languages

The next important area is preserving enough information across compilation boundaries that downstream compilation can still optimize.

Relevant systems include:

- TIL
- FLINT
- MLton
- OCaml Flambda
- LLVM LTO
- GCC LTO
- Swift cross-module optimization
- .NET generic specialization

Important papers include:

### TIL

Tarditi et al., **TIL: A Type-Directed Optimizing Compiler for ML**

This is relevant because rich type information survives far enough into compilation to guide representation and code generation.

For Rune, that suggests a dependency artifact richer than object code:

```text
typed IR
+
module information
+
representation metadata
+
optimization catalogue
```

---

### FLINT

Zhong Shao and collaborators' FLINT work is relevant for typed compiler IRs and explicit representation/type information.

The general theme is:

\[
\text{don't erase useful static facts too early}.
\]

Rune's downstream optimizer needs precisely that.

---

### MLton

MLton is especially relevant because it performs aggressive whole-program transformations on SML:

- defunctorization;
- monomorphization;
- representation analysis;
- whole-program specialization;
- dead-code elimination.

MLton demonstrates how much module abstraction can disappear once the whole program is known.

Rune would add a missing layer:

> library authors explicitly state which alternative implementations are valid.

---

### OCaml Flambda

Flambda is very relevant to **cross-module specialization and inlining**.

The important ideas include:

- retaining optimization summaries;
- interprocedural analysis;
- cross-compilation-unit inlining;
- function specialization;
- closure information;
- target-aware optimization.

Rune's optimization catalogue can be understood as an enriched Flambda-style summary:

```text
optimization summary
+
library-authored semantic alternatives.
```

---

# 4. Link-time optimization is structurally very close

LLVM and GCC LTO are worth studying even though they operate below the module/type level.

Ordinary separate compilation:

```text
library
   ↓
opaque machine code
```

prevents many optimizations.

LTO instead keeps:

```text
library
   ↓
intermediate representation
   ↓
link-time whole-program optimization
```

The Rune analogue could be:

```text
library
   ↓
typed module IR
+
optimization contracts
+
representation facts
   ↓
Rune link/specialization phase
```

So your proposed system is almost a **typed semantic LTO**.

The major literature here covers:

- interprocedural optimization;
- whole-program analysis;
- devirtualization;
- global constant propagation;
- link-time code generation;
- ThinLTO.

### ThinLTO is especially interesting

ThinLTO does not necessarily ship full IR everywhere. It uses summaries to drive selective import and optimization.

Rune could similarly export:

```text
optimization summary
representation summary
specialization candidates
```

and only import bodies when a candidate is actually selected.

That may eventually matter a great deal for compile time.

---

# 5. Separate compilation with optimization summaries

This is one of the most directly relevant conceptual areas.

A compiled module can export more than its ordinary type/signature.

It can export optimization information such as:

- known constants;
- purity/effect information;
- inlinability;
- size estimates;
- calling conventions;
- representation facts;
- specialization opportunities.

This has precedents in many compilers.

Examples include:

- OCaml `.cmx` optimization metadata
- GHC `.hi` interface files
- Swift serialized SIL/interface optimization data
- LLVM summaries
- Java classfile metadata plus JIT profiling
- .NET generic metadata

### GHC interface files are particularly relevant

GHC interface files contain more than user-facing type declarations.

They can include things needed for downstream optimization, such as:

- unfoldings;
- strictness information;
- occurrence information;
- rules;
- class/instance information.

This is extremely close to your proposed distinction:

```text
PROGRAMMER INTERFACE
vs
OPTIMIZER INTERFACE
```

Rune could formalize this explicitly.

For example:

```text
Basis.rni          public Rune interface

Basis.ropt         optimizer contract

Basis.rir          typed intermediate representation
```

or package them in one artifact.

This may be the single strongest practical precedent for your build-artifact design.

---

# 6. C++ templates and explicit specialization

C++ gives another important form of library-controlled specialization.

For example:

```cpp
template<typename T>
class Vector { ... };

template<>
class Vector<bool> { ... };
```

The library itself declares:

\[
Vector(bool)
\Rightarrow
SpecialVectorBool.
\]

Partial specialization goes further:

```cpp
template<class T>
struct X<T*> { ... };
```

The similarity to Rune is obvious:

```text
when Predicate(T)
    use Implementation(T)
```

But C++ has two characteristics you probably want to avoid.

First, specialization is deeply part of source semantics.

Second, specialized implementations may have detectably different APIs/behavior.

`std::vector<bool>` is the canonical warning.

Rune could instead require:

\[
I_{\text{specialized}}
\approx_{\text{interface}}
I_{\text{generic}}.
\]

So C++ is both precedent and cautionary example.

---

# 7. Type classes, traits and coherence

Your implementation catalogue resembles type-class resolution:

\[
Type \rightarrow Implementation.
\]

Important starting points include:

- Wadler and Blott, **How to Make ad-hoc Polymorphism Less ad hoc**
- type-class coherence literature
- Jones' qualified types work
- Haskell instance resolution
- Rust trait coherence/specialization

These become especially relevant when rules overlap.

For example:

```text
FixedWidth K => PackedMap
Hash K       => HashMap
Ord K        => TreeMap
```

What if all three are true?

Type-class research has spent decades on:

- coherence;
- overlap;
- instance selection;
- principal solutions;
- orphan rules;
- specialization;
- ambiguity.

Your optimization system gets an easier version of the problem because selection should ideally not affect semantics.

But you still need deterministic compilation.

A good lesson from this literature is:

\[
\boxed{\text{make overlapping applicability explicit and formally ordered}}
\]

rather than relying on arbitrary rule order.

---

# 8. Rust specialization and coherence

Rust's specialization efforts are particularly useful as a warning.

Rust would like to express things such as:

```rust
impl<T> Foo for T { ... }

impl Foo for i32 { ... }
```

but overlap interacts with:

- coherence;
- associated types;
- inference;
- downstream implementations;
- semver;
- separate compilation.

This maps almost directly onto Rune's question:

> Can a downstream library add another optimization candidate to a family defined elsewhere?

If yes, then your “closed universe” assumption becomes much harder.

Your idea of letting Basis declare itself a **closed implementation universe** is precisely one way to avoid this.

The Basis build can say:

```text
ImplementationFamily Vector is sealed.
```

Then no downstream dependency can silently add another candidate.

That dramatically simplifies specialization.

---

# 9. Sealed classes / closed type families / closed worlds

Several language mechanisms are relevant to your “Basis knows the complete universe” idea.

### Haskell closed type families

A closed type family has an ordered, complete set of equations known in one declaration.

Conceptually:

```haskell
type family Rep a where
    Rep Int    = ...
    Rep Bool   = ...
    Rep a      = ...
```

This is interesting because your optimization family is somewhat similar:

```text
family VectorImplementation T where
    Word8   -> Word8Vector
    Float64 -> FloatVector
    _       -> GenericVector
```

Except Rune's family produces a module implementation rather than a type.

The distinction between **open** and **closed** families is highly relevant.

For Basis I would strongly favor closed families.

---

### Sealed traits/classes

Scala/Kotlin/Java-style sealed hierarchies establish:

> this is the complete set of cases.

Compilers then gain exhaustiveness and optimization opportunities.

That same declaration is what your build system needs:

```text
sealed optimization family Basis.Vector
```

---

# 10. Devirtualization under closed-world assumptions

There is a large literature on devirtualization and class hierarchy analysis.

Classic techniques include:

- Class Hierarchy Analysis (CHA)
- Rapid Type Analysis (RTA)
- whole-program devirtualization
- points-to analysis
- speculative devirtualization

The relevance is conceptual.

If the compiler knows the complete set of possible implementations of an interface, it can replace:

```text
interface dispatch
```

with:

```text
known concrete implementation.
```

Rune's situation is stronger:

```text
abstract module interface
+
closed implementation family
+
static type information
```

can choose an implementation before runtime.

The same closed-world principle applies.

---

# 11. Whole-program analysis in OO compilers

Research on Self, Smalltalk, Java and other OO languages also explored:

- method specialization;
- type feedback;
- inline caches;
- class hierarchy analysis;
- whole-program method selection.

The classic Self compiler work by Chambers and Ungar is relevant conceptually, even though it is dynamic/JIT-oriented.

They demonstrate a general principle:

\[
\text{generic abstraction}
+
\text{known implementation/type}
\Rightarrow
\text{specialized code}.
\]

Rune moves the decision earlier and makes library-authored constraints explicit.

---

# 12. Partial evaluation

Your entire implementation catalogue can also be understood as a restricted partial evaluator.

Suppose the library conceptually defines:

\[
ChooseVector : TypeInfo \rightarrow Module.
\]

The application build knows:

\[
TypeInfo = Int64.
\]

Then it evaluates:

\[
ChooseVector(Int64)
\]

during compilation.

Relevant literature includes:

- Neil Jones, Carsten Gomard, Peter Sestoft, **Partial Evaluation and Automatic Program Generation**
- Futamura's work on partial evaluation
- binding-time analysis
- offline and online specialization

This is especially relevant because your **build language itself is executable**.

You could interpret implementation selection literally as staged module computation:

```text
build stage:
    evaluate ChooseVector TypeInfo

program stage:
    run resulting Vector module
```

That gives the mechanism a very clean staging interpretation.

---

# 13. Multi-stage programming

Related work includes:

- MetaML
- Taha and Sheard's staging work
- Typed Template Haskell
- LMS / Lightweight Modular Staging

The key separation is:

\[
Stage_0 = build/compile time
\]

\[
Stage_1 = runtime.
\]

Your module build language lives naturally at stage 0.

An implementation selector:

```sml
fun chooseMap facts = ...
```

is simply stage-0 computation producing a module.

What you probably *don't* want is arbitrary stage-0 reflection over compiler internals.

So the prior art suggests:

- unrestricted staging is powerful;
- restricted typed staging is much easier to reason about.

Rune's `Optimize.Predicate`, `ImplementationFamily`, etc. would form such a restricted staging API.

---

# 14. Meta-programmed builds: Shake is relevant

For the executable-build-language part, **Shake** is worth looking at.

Neil Mitchell's Shake embeds a build system in Haskell.

The point is that builds are programs, not declarative static files.

That is similar to your idea of using Rune itself as the build language.

Important ideas include:

- dependencies as values;
- build rules as functions;
- dynamic dependency discovery;
- reproducibility;
- incremental rebuilds.

But Shake primarily manipulates files/actions, not typed modules.

Rune would extend the embedded-build-language idea into:

\[
\text{build program manipulates typed compilation objects}.
\]

---

# 15. Bazel/Starlark is the opposite design point

Bazel's Starlark is a restricted programming language for build definitions.

It is intentionally constrained to improve:

- determinism;
- hermeticity;
- caching;
- reproducibility.

This is relevant because your Rune build language could easily become too powerful.

If a build module can arbitrarily inspect:

```text
clock
filesystem
network
randomness
environment
```

then optimization catalogues become difficult to cache or trust.

The build-systems literature suggests strongly separating:

```text
pure build description
```

from:

```text
external effect execution.
```

---

# 16. Build systems à la carte

A particularly relevant theoretical paper is:

**Andrey Mokhov, Neil Mitchell, Simon Peyton Jones — _Build Systems à la Carte_.**

It develops a framework for understanding build systems in terms of:

- tasks;
- dependencies;
- schedulers;
- rebuilder strategies.

It doesn't address module optimization metadata specifically, but it would be useful when designing Rune's programmable build layer rigorously.

Your system adds typed compiler artifacts as another kind of build value.

---

# 17. Dune

Dune is relevant as a practical ML build-system precedent.

Important concepts include:

- library descriptions;
- module dependency tracking;
- preprocessing;
- separate compilation;
- compiler flags;
- wrapped libraries;
- virtual libraries / implementations.

Virtual libraries are especially interesting.

A library can define an interface with implementations supplied elsewhere.

This gives:

```text
abstract library
+
choice of implementation
```

although the implementation choice is mostly declarative/build-time, not automatically type-specialized.

Still, Dune's **virtual libraries** are conceptually adjacent to Rune implementation families.

---

# 18. Haskell Backpack

Backpack is even more directly relevant to the module/build interaction.

Important work includes:

- Edward Z. Yang and collaborators on Backpack
- **Backpack: Retrofitting Haskell with Interfaces**

Backpack supports modules with abstract dependencies that can later be instantiated with implementations.

Conceptually:

\[
Program(ModuleHole)
\]

later becomes:

\[
Program(ConcreteModule).
\]

This is highly relevant to Rune:

```text
Graph(MapImplementation)
```

where the final build chooses the concrete `MapImplementation`.

Backpack itself does not primarily choose implementations based on representation predicates, but its notion of **build-time module instantiation** is very close to your architecture.

Of the build/module literature, Backpack may be the most important one to study.

---

# 19. ML functors as build-time composition

Standard ML itself is already relevant prior art.

A functor:

```sml
functor F (X : S) = ...
```

is essentially a statically typed component constructor.

Large SML programs have historically used functors for:

- configuration;
- implementation replacement;
- platform adaptation;
- testing;
- feature selection.

Your build language essentially raises this idea by one level:

```text
build program chooses functor arguments
```

and now additionally gives the compiler permission to make those choices automatically.

There is old module-system literature around:

- separate compilation;
- functor linking;
- configuration languages;
- module composition.

MacQueen's module work remains relevant here.

---

# 20. Units and linking calculi

There is a separate research tradition around **linking calculi**.

Important examples include work by:

- Cardelli
- Leroy
- Flatt and Felleisen
- Pierce and others

Racket's **units** are an especially practical example.

Units make linking itself programmable:

```text
component imports
component exports
link configuration
```

That is much closer to a build language than ordinary modules.

Your Rune build system could be thought of as a typed linking calculus that additionally manipulates optimization metadata.

---

# 21. Mixins and recursive modules

Mixin module research is also relevant because build configurations often need mutually dependent components.

Important work includes:

- Bracha and Cook on mixins
- Duggan and Sourelis
- Hirschowitz and Leroy on mixin modules
- recursive modules

This matters if optimization catalogues can themselves be composed recursively across packages.

It may also help with scenarios such as:

```text
runtime depends on Basis representation
Basis specialization depends on runtime target
```

where careless design can create dependency cycles.

---

# 22. Proof-carrying code is a useful analogy for optimization evidence

Your idea that an optimization catalogue might carry evidence has a strong conceptual precedent in:

**George Necula — Proof-Carrying Code**

The original setting is security/safety rather than optimization.

Producer supplies:

```text
code + proof
```

Consumer verifies the proof cheaply.

Your analogue could be:

```text
optimization rule + certificate
```

where the compiler verifies that a transformation satisfies some property.

For example:

```text
replacement:
    PackedVector

certificate:
    representation compatibility
```

Full semantic equivalence proofs would generally be hard, but restricted proof obligations could be practical.

---

# 23. Translation validation

Another relevant field is **translation validation**.

Instead of proving an optimizer correct once and for all, validate each concrete optimization result.

Important names include:

- Pnueli et al. on translation validation
- CompCert-related validation techniques

Rune could theoretically allow a library to propose:

```text
GenericVector -> PackedVector
```

and have the compiler validate certain structural invariants.

This might be practical for low-level representation transformations even if full functional equivalence isn't.

---

# 24. CompCert and verified optimization

CompCert is important for the general question:

> How do we know compiler transformations preserve semantics?

Xavier Leroy's CompCert work formalizes compiler passes and proves semantic preservation.

Rune's library-authored optimizations create a new trust boundary:

```text
compiler proves its passes
but library supplies transformation law
```

Possible responses are:

- trust the library;
- verify a certificate;
- restrict the transformation DSL enough that preservation is automatic.

The third option is probably the most attractive for Basis representation specialization.

---

# 25. Equality saturation and e-graphs

This is a less obvious but potentially important connection.

Systems such as:

- `egg`
- equality saturation
- e-graphs

allow a collection of equivalence rules:

\[
a+b \equiv b+a
\]

\[
map f (map g x) \equiv map (f\circ g)x
\]

and then search among equivalent programs for a cheap representative.

Rune's optimization catalogue could ultimately feed an e-graph-like optimizer:

```text
library exports semantic equivalences
compiler chooses based on cost
```

This matches your idea almost perfectly at a more general level:

\[
\boxed{
\text{library defines valid equivalences;
compiler chooses profitable representative}
}
\]

Relevant work includes:

- Tate et al., **Equality Saturation: A New Approach to Optimization**
- Willsey et al., **egg: Fast and Extensible Equality Saturation**

Your module-level selection could be seen as a coarse-grained form of equality saturation.

---

# 26. Stratego/XT and programmable rewriting

Stratego and similar program-transformation systems explore programmable rewrite systems and strategies.

They show both the power and danger of user-extensible optimizer rewriting.

Rune probably should not expose unrestricted AST rewriting to libraries, but Stratego is useful prior art for:

- rule composition;
- rewriting strategies;
- phase control;
- rule conflicts.

---

# 27. Semantic optimization contracts and refinement

There is also relevant work around:

- refinement types;
- behavioral subtyping;
- abstract interpretation;
- semantic interfaces;
- contracts.

If a specialization requires:

```text
key has dense integer domain
```

that's richer than a normal ML type.

You could model such assumptions as refinement properties:

\[
K : \{T \mid DenseIndex(T)\}.
\]

Likewise an implementation can promise:

\[
IntMap \models MAP[K].
\]

I would not necessarily make Rune optimization predicates full refinement types, but the literature is relevant to designing the predicate language.

---

# 28. Abstract interpretation

Abstract interpretation is useful for thinking about the optimizer's static-fact system.

Relevant foundational work:

- Patrick and Radhia Cousot, **Abstract Interpretation**

Suppose the compiler knows:

```text
Layout(T) = Word64
PointerFree(T)
HasHash(T)
```

These are abstract facts computed about types/programs.

Implementation applicability becomes a predicate over the abstract state.

So the optimization resolver can be viewed as consuming results from one or more abstract analyses.

This gives you a principled architecture:

```text
analyses
    ↓
StaticFacts
    ↓
optimization-family applicability
```

rather than letting each library run arbitrary analysis code.

---

# 29. Auto-tuning and algorithm selection

Once several Basis implementations are valid, the question becomes:

> which one should the compiler choose?

That links to a separate research tradition.

Classic:

**John R. Rice — The Algorithm Selection Problem**

Later examples include:

- ATLAS
- FFTW
- SPIRAL

These systems choose among semantically equivalent algorithms based on:

- architecture;
- input characteristics;
- measurement;
- cost models.

For Rune, the search space is library-authored:

```text
Basis declares valid implementations
compiler chooses cheapest one
```

This is a particularly good conceptual model.

---

# 30. FFTW and SPIRAL are surprisingly relevant

FFTW famously describes itself in terms of generating/planning implementations for a specific environment.

SPIRAL automatically generates highly optimized numerical kernels.

The important architectural idea is:

\[
\text{domain expert provides transformation/search space}
\]

while:

\[
\text{compiler/search engine chooses implementation}.
\]

That's very close to Basis saying:

> these representations/algorithms are all valid for `Vector`; choose according to static facts and target.

The scale differs, but the architecture is similar.

---

# 31. Database query optimizers may be the closest conceptual analogy

A database system has:

```text
logical query
```

and multiple valid physical implementations:

```text
hash join
merge join
nested-loop join
```

The query optimizer chooses one based on:

- statistics;
- available indexes;
- cost;
- machine environment.

Rune would have:

```text
logical module/interface
```

and physical implementations:

```text
GenericMap
HashMap
RadixMap
DenseMap
```

with selection based on:

- type facts;
- layout;
- capabilities;
- target;
- workload/profile.

The distinction:

\[
\text{logical plan}
\quad\text{vs}\quad
\text{physical plan}
\]

maps almost perfectly onto:

\[
\text{abstract module}
\quad\text{vs}\quad
\text{implementation module}.
\]

This literature becomes especially relevant once you add cost-based selection.

---

# 32. Profile-guided optimization adds another future dimension

PGO systems use runtime measurements to guide later compilation.

Rune's build system could eventually combine:

```text
Basis optimization catalogue
+
target facts
+
profile data
```

to choose implementations.

For example:

```text
Map<int>
```

could select differently depending on whether the workload is:

```text
90% lookup / 10% insert
```

or:

```text
50% iteration / 50% mutation.
```

That begins approaching database/algorithm-selection systems.

Not necessary initially, but your architecture would support it naturally.

---

# 33. The closest prior-art matrix

I would summarize the landscape like this:

| Rune idea | Closest prior art |
|---|---|
| Library exports optimization rules | GHC RULES |
| Rules travel with compiled interface | GHC `.hi`, OCaml `.cmx` |
| Late cross-module specialization | Flambda, GHC, Swift CMO |
| Whole-program specialization | MLton |
| Compile-time module instantiation | Backpack, ML functors |
| Different implementation per type | C++ template specialization |
| Closed implementation universe | closed type families, sealed classes |
| Static predicates determine implementation | type classes / traits |
| Build language as program | Shake |
| Restricted deterministic build DSL | Bazel/Starlark |
| Rich link-time compilation | LLVM/GCC LTO |
| Typed IR preserved across phases | TIL, FLINT |
| Library declares equivalent alternatives | rewrite-rule / fusion literature |
| Search among equivalent programs | equality saturation |
| Verify producer-provided evidence | proof-carrying code |
| Validate individual transformations | translation validation |
| Choose best implementation | algorithm selection / auto-tuning |
| Logical interface vs physical implementation | database query optimization |

There is a clear research lineage behind nearly every piece.

---

# 34. The most relevant reading list for Rune

If you want to focus tightly on **your exact design**, I would prioritize:

1. **GHC RULES / Playing by the Rules**  
   The closest example of a library shipping optimizer knowledge.

2. **GHC interface-file optimization metadata**  
   Very close to your separate programmer/optimizer interface.

3. **Backpack: Retrofitting Haskell with Interfaces**  
   For build-time component instantiation.

4. **TIL: A Type-Directed Optimizing Compiler for ML**  
   For retaining semantic/type knowledge deep into compilation.

5. **MLton implementation papers/documentation**  
   For whole-program defunctorization and specialization of SML.

6. **OCaml Flambda literature**  
   For optimization summaries and cross-module specialization.

7. **Harper & Morrisett, Compiling Polymorphism Using Intensional Type Analysis**  
   For statically choosing based on type information.

8. **C++ partial/full template specialization**  
   As the mainstream analogue of implementation families.

9. **Rust specialization/coherence work**  
   For why open overlapping implementation families become difficult.

10. **Mokhov, Mitchell, Peyton Jones, Build Systems à la Carte**  
    For the programmable build-system foundation.

11. **Shake**  
    For a build language embedded in a general-purpose functional language.

12. **ThinLTO literature**  
    For scaling cross-module optimization summaries.

13. **Equality saturation / egg**  
    For the more general idea that libraries provide equivalences and the compiler chooses among them.

14. **Rice, The Algorithm Selection Problem**  
    For choosing among equivalent implementations.

15. **FFTW / SPIRAL / ATLAS**  
    For domain-defined optimization search spaces.

16. **database query optimization literature**  
    For separating semantic interface from physical implementation selection.

---

The genuinely distinctive Rune idea is not any single mechanism. It is the composition:

\[
\boxed{
\begin{aligned}
&\text{typed executable build language}\\
+&\text{module-level abstract interfaces}\\
+&\text{library-exported optimization contracts}\\
+&\text{private representation metadata}\\
+&\text{closed implementation families}\\
+&\text{whole-program or link-time selection}
\end{aligned}}
\]

GHC comes closest on **library-supplied optimizer knowledge**, Backpack on **build-time module instantiation**, MLton/Flambda on **cross-module specialization**, and databases/auto-tuning on **choosing among semantically interchangeable implementations**. Rune would be combining those ideas into one coherent typed system.
