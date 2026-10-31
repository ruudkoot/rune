in standard ml the module language cannot operate on the module language (no higher-order functors), the module langauge does operate on the core language (obiously), the core language does operate on the core language (higher-order functions). would it be sensible to have a build system for sml where we can have core language operate on module language to assemble modules in interesting ways? because this happens at build time we would maintain the phase separation

----

Yes. In fact, that is a fairly coherent way to fill the missing quadrant in Standard ML’s staging story.

You can think of ordinary SML as having roughly this matrix:

| Operator language | Operates on core | Operates on modules |
|---|---:|---:|
| Core language | ✓ higher-order functions | ✗ |
| Module language | ✓ structures contain/core declarations | ✓ but traditionally only first-order functors |

What you are proposing is essentially:

> run ordinary SML as a **meta-language at build time**, where values represent module-language constructions.

That gives you the missing **core → module** direction without turning modules into runtime values.

The staging becomes:

```text
Stage -1: build/meta program written in SML
             |
             | constructs
             v
         module program
             |
             | elaboration/typechecking
             v
Stage 0: ordinary SML program
             |
             | compilation
             v
Stage 1: runtime
```

That is a good architecture, particularly for Rune.

### The important distinction: this is not quite higher-order functors

Suppose SML had higher-order functors. You could conceptually write something like:

```sml
functor Twice
    (F : functor (X : S) -> T) =
struct
    functor G (X : S) =
    struct
        structure A = F(X)
        structure B = F(A)
    end
end
```

The module type system itself understands `F` as a functor.

In your proposed system, you might instead write build-time SML:

```sml
fun twice f =
    fun x =>
        let
            val a = applyFunctor f x
            val b = applyFunctor f a
        in
            b
        end
```

Here:

```text
fun
```

is just an ordinary SML higher-order function, while `f`, `x`, `a`, and `b` are descriptions or handles representing module-language entities.

So ordinary higher-order functions become your higher-order module composition mechanism.

This can be surprisingly powerful.

For example, your build language might expose:

```sml
type module
type signature
type functor

val structure :
    string -> declaration list -> module

val functor_ :
    string -> signature -> module -> functor

val apply :
    functor -> module -> module

val seal :
    module -> signature -> module

val import :
    string -> module

val emit :
    module -> unit
```

Then ordinary SML naturally provides all the missing combinators:

```sml
fun mapFunctor f xs =
    map (apply f) xs

fun composeFunctors f g x =
    apply g (apply f x)

fun instantiateAll f implementations =
    map (apply f) implementations
```

No special higher-order module machinery is required in the build language because SML already has higher-order functions.

## Where I think this becomes especially interesting

Don't make it merely a source-code generator.

Instead, make the build system manipulate a **module IR**.

For example:

```sml
datatype Module =
    Import of Path.t
  | Structure of
      { name : string,
        decls : Declaration list }
  | FunctorApp of
      { functor : Module,
        argument : Module }
  | Seal of
      { module : Module,
        signature : Signature }
  | Let of
      { bindings : Binding list,
        body : Module }
```

Although in an implementation I would probably make `Module.t` abstract rather than expose the datatype directly.

Then a build file could say something like:

```sml
val collections =
    [import "List.sml",
     import "Vector.sml",
     import "Array.sml"]

val debugCollections =
    map (applyFunctor DebugWrapper) collections

val optimizedCollections =
    map (applyFunctor Optimize) debugCollections

val Library =
    aggregate "Collections"
        optimizedCollections
```

That's much closer to a **module algebra** than to Make.

And because it is ordinary SML:

```sml
map
foldl
List.filter
option
pattern matching
higher-order functions
user-defined datatypes
```

all immediately become tools for manipulating your module graph.

### A particularly nice example: parameterized build families

Suppose you have:

```text
IntMap
StringMap
SymbolMap
PathMap
TypeMap
```

Today you might manually write several functor applications.

Your build program could instead contain:

```sml
val mapTypes =
    [("Int", IntKey),
     ("String", StringKey),
     ("Symbol", SymbolKey),
     ("Path", PathKey),
     ("Type", TypeKey)]

fun makeMap (name, key) =
    named (name ^ "Map")
        (applyFunctor MapFn key)

val maps =
    map makeMap mapTypes
```

This isn't necessarily *code generation* in the ugly textual sense. It can simply construct the module elaboration graph.

That distinction is important.

## You can preserve very strong phase separation

I would deliberately prevent the build-time meta-language from observing runtime values.

You would have approximately:

```text
Build SML
    |
    | produces ModuleGraph
    v
Module elaborator
    |
    | produces Core IR
    v
Compiler
    |
    v
Program
```

A build program could inspect:

```text
module names
source files
signatures
dependencies
target platform
compiler configuration
feature flags
generated module topology
```

but not:

```text
runtime values
runtime closures
runtime references
runtime exceptions
```

Unless you deliberately provide those things as configuration.

So this arguably has *cleaner* phase separation than first-class runtime modules.

It resembles staged programming:

```text
meta level          object level

SML value     --->  module-language term
SML function  --->  transformation over module terms
```

The build program disappears once compilation is finished.

## There are actually three designs you could choose

The simplest is **syntactic module generation**:

```sml
val m : ModuleSyntax.t
```

The build system constructs ASTs.

For example:

```sml
apply :
    ModuleSyntax.t ->
    ModuleSyntax.t ->
    ModuleSyntax.t
```

This is easy, but:

```text
build phase
    ↓
untyped/generated module AST
    ↓
normal SML elaboration
```

means errors occur after generation.

A much more interesting approach is **elaborated module handles**:

```sml
type module
type signature
type functor

val import : path -> module

val signatureOf : module -> signature

val apply : functor * module -> module
```

The build environment has access to the compiler's module elaborator.

Now the build program operates on actual compiler-level module objects rather than text or syntax.

This begins looking like:

> a programmable linker/module elaborator.

I think this is the more interesting Rune design.

And there is an even more ambitious third option: **typed module combinators**.

Conceptually:

```sml
'a module
('a, 'b) functor
```

and:

```sml
val apply :
    ('a, 'b) functor ->
    'a module ->
    'b module
```

But SML's own type system cannot directly encode arbitrary SML signatures as ordinary core-language types. You would need phantom representations, existential packaging, compiler-generated witnesses, or dependent/GADT-like machinery.

I probably would **not** start there.

## The major semantic question is type identity

This is the part that prevents the idea from being just an unusually fancy Make.

Consider:

```sml
functor F () =
struct
    datatype t = T
end

structure A = F()
structure B = F()
```

With generative semantics:

```text
A.t ≠ B.t
```

Your build meta-language must not accidentally turn:

```sml
val f = apply F
val a = f Unit
val b = f Unit
```

into shared modules merely because:

```text
f(Unit)
```

has the same build expression twice.

This matters enormously for caching.

A normal build system likes:

```text
same inputs -> same cached result
```

but generative module application can mean:

```text
same syntax
same input module
same functor

BUT

different application occurrence
→ different static type identities
```

So you'd need to distinguish something like:

```text
structural identity
build artifact identity
static/generative identity
```

Those must not be casually conflated.

This actually connects directly to your recent question about functor application and bytecode duplication.

A good module-aware build graph could let you separately represent:

```text
Functor code
    F

Functor application identities
    F(A) #1
    F(A) #2

Generated static environments
    Env1
    Env2

Shared executable implementation
    Code_F
```

depending on whether sharing is semantically valid.

That could give Rune a much more sophisticated treatment of functor instantiation than merely macro-expanding functor bodies.

## Applicative functors become particularly interesting

If Rune eventually has applicative functors, your build system can potentially memoize:

```text
F(A)
```

according to module identity.

For applicative functors:

```text
F(A).t = F(A).t
```

across applications in the appropriate static sense.

That permits much stronger graph sharing.

For generative functors:

```text
apply F A
apply F A
```

must generally retain distinct generativity stamps.

So the module graph could explicitly contain:

```sml
datatype ApplicationMode =
    Generative
  | Applicative
```

or, preferably, know this property from the functor's semantics.

This makes your build system's graph substantially richer than a conventional build DAG.

## This also gives you an elegant answer to higher-order functors

You might decide that Rune **doesn't need higher-order functors in the source module language initially**.

You could support:

```text
runtime/core language
    ordinary higher-order functions

static/module language
    first-order functors

build/meta language
    arbitrary higher-order manipulation of functors/modules
```

So:

```text
             Core values       Module values
           ┌───────────────┬─────────────────┐
Core       │ functions     │ build-stage     │
           │               │ combinators     │
           ├───────────────┼─────────────────┤
Modules    │ structures    │ functors        │
           └───────────────┴─────────────────┘
```

with the upper-right cell existing only at build time.

That's conceptually quite elegant.

## But it doesn't completely replace higher-order functors

There is one substantial difference.

A real higher-order functor participates directly in the language's static semantics:

```text
signature checking
sharing constraints
abstract types
generativity
functor signatures
principal environments
```

A build-time SML function:

```sml
fun transformModule m = ...
```

normally doesn't.

For example, a higher-order functor might have a module-level type approximately:

```text
(F : S -> T) -> (S -> U)
```

where the type system knows relationships between types exposed by `S`, `T`, and `U`.

Your build function initially only sees:

```sml
Module.t -> Module.t
```

which forgets those relationships.

So I'd distinguish:

```text
Higher-order functors
    = typed abstraction over module computations

Build-time module functions
    = programmable construction of module computations
```

They overlap a lot operationally, but the former has stronger static abstraction.

## One especially useful architecture

I would consider making the compiler itself expose a module-construction API:

```sml
structure Build :
sig
    type module
    type signature
    type functor
    type program

    val source :
        string -> module

    val structure_ :
        string * module list -> module

    val apply :
        functor * module -> module

    val seal :
        module * signature -> module

    val alias :
        string * module -> module

    val dependency :
        module * module -> unit

    val compile :
        module -> program
end
```

Then a Rune project might literally have:

```text
project.rune
```

which is an SML program executed by the compiler's build-stage evaluator:

```sml
val Basis =
    Build.source "basis.sml"

val Parser =
    Build.apply (ParserFn, Basis)

val Optimizers =
    map
        (fn opt => Build.apply (opt, IR))
        [ConstFold, Inline, DCE]

val Compiler =
    Build.structure_
        ("Compiler",
         [Parser, Elaborator, Codegen] @ Optimizers)

val _ =
    Build.target Compiler
```

Now the project description is itself a typed functional program.

There are precedents for portions of this idea—ML's own module calculi, staged/meta-programming systems, programmable build systems such as Shake, and languages with sophisticated phase separation—but the combination is especially natural for ML because **the core language is already extremely good at describing compositional transformations**.

The main design principle I would adopt is:

> Don't let SML generate strings containing SML. Let SML manipulate compiler-recognized module objects.

That turns the feature from "fancy code generation" into a genuine **meta-module layer**.

I would therefore describe Rune as having three languages/phases:

```text
Meta/build language
    SML functions over module descriptions
             ↓
Module language
    structures / signatures / functors
             ↓
Core language
    values / functions / datatypes / effects
             ↓
Runtime
```

And there is a pleasing symmetry:

```text
meta level       higher-order functions over modules
module level     functors over structures
core level       functions over values
```

Each level is a computational language over the objects of the level below it.

For Rune specifically, I think this is potentially more interesting than simply adding higher-order functors: you can still add higher-order functors eventually for proper module-level abstraction, while the build/meta layer solves a broader problem—whole-program module graph construction, target-dependent composition, generated families of functor applications, specialization, dependency management, and compilation caching—without weakening SML's runtime/module phase distinction.

----

so some things i would be interested in:

- have my build system compose and compiler variants of a single program so we can compare performace and correctness between them
- produce a debug build that that inserts/wraps logging around certain modules (not present in the release build)
- replace creatain modules depending on the platform we run on (e.g. one impleemntation for linux, one for linux
- produce different versions of a program (home, pro, enterprise)

give concrete build programs using the core can manipulate modules concept to see if this is indeed solving the problem (and how)

----

Yes. These are exactly the cases where a build-time core language operating on modules starts to justify itself. The key is that the build program should manipulate **module graph objects**, not source strings.

I would give the build language an API roughly like this:

```sml
structure Build :
sig
    type module
    type signature
    type program
    type executable

    (* Existing source modules *)
    val source :
        string -> module

    (* Module construction *)
    val structure_ :
        string -> module list -> module

    val apply :
        module -> module -> module

    val seal :
        module -> signature -> module

    val rename :
        string -> module -> module

    (* Replace a named submodule somewhere in a module graph *)
    val replace :
        { root        : module,
          path        : string,
          replacement : module }
        -> module

    (* Transform/wrap modules satisfying some predicate *)
    val rewrite :
        (module -> module option) ->
        module ->
        module

    (* Compilation *)
    val compile :
        { root    : module,
          options : Compiler.option list }
        -> executable

    val test :
        executable -> Test.result

    val benchmark :
        executable -> Benchmark.result

    val emit :
        string -> executable -> unit
end
```

The exact API is negotiable. The important thing is that `Build.module` is an abstract compiler object carrying enough static identity for signatures, sharing, generativity, dependencies, and caching.

Then the build file itself is ordinary SML.

---

# 1. Build several compiler/program variants and compare them

Suppose the application is:

```text
App
├── Parser
├── Optimizer
├── Backend
└── Runtime
```

and you want combinations such as:

```text
baseline
no optimizer
new optimizer
old backend
new backend
```

Traditionally this tends to leak into Makefiles, conditional compilation, command-line options, separate source trees, or ad-hoc scripts.

With module-level build programming:

```sml
val Parser       = Build.source "parser.sml"
val OptimizerV1  = Build.source "optimizer-v1.sml"
val OptimizerV2  = Build.source "optimizer-v2.sml"
val NoOptimizer  = Build.source "optimizer-none.sml"

val BackendV1    = Build.source "backend-v1.sml"
val BackendV2    = Build.source "backend-v2.sml"

val Runtime      = Build.source "runtime.sml"
val MainFn       = Build.source "main-fn.sml"
```

Assume:

```sml
MainFn :
    functor
      (structure Parser    : PARSER
       structure Optimizer : OPTIMIZER
       structure Backend   : BACKEND
       structure Runtime   : RUNTIME)
      -> PROGRAM
```

Your build system can make variants using ordinary data:

```sml
type variant =
    { name      : string,
      optimizer : Build.module,
      backend   : Build.module }

val variants =
    [{ name = "baseline",
       optimizer = OptimizerV1,
       backend = BackendV1 },

     { name = "optimizer-v2",
       optimizer = OptimizerV2,
       backend = BackendV1 },

     { name = "backend-v2",
       optimizer = OptimizerV1,
       backend = BackendV2 },

     { name = "optimizer-v2-backend-v2",
       optimizer = OptimizerV2,
       backend = BackendV2 },

     { name = "no-optimizer",
       optimizer = NoOptimizer,
       backend = BackendV1 }]
```

Now construction is simply a function:

```sml
fun makeProgram {name, optimizer, backend} =
    let
        val Config =
            Build.structure_ "Config"
                [Parser,
                 optimizer,
                 backend,
                 Runtime]

        val Program =
            Build.apply MainFn Config
    in
        { name = name,
          program = Program }
    end
```

And compilation is just:

```sml
val programs =
    map makeProgram variants

val executables =
    map
        (fn {name, program} =>
            { name = name,
              executable =
                  Build.compile
                      { root = program,
                        options = [] } })
        programs
```

Now ordinary SML can drive differential testing:

```sml
fun checkEquivalent [] =
      ()
  | checkEquivalent ({name, executable} :: rest) =
      let
          val result = Build.test executable
      in
          print (name ^ ": " ^ Test.show result ^ "\n");
          checkEquivalent rest
      end

val _ =
    checkEquivalent executables
```

Or benchmarking:

```sml
val benchmarkResults =
    map
        (fn {name, executable} =>
            (name, Build.benchmark executable))
        executables
```

This is already much nicer than a build system with a pile of flags.

But the interesting part is that you can generate the **Cartesian product** naturally:

```sml
val optimizers =
    [("none", NoOptimizer),
     ("v1",   OptimizerV1),
     ("v2",   OptimizerV2)]

val backends =
    [("v1", BackendV1),
     ("v2", BackendV2)]

val variants =
    List.concat
        (map
            (fn (oname, optimizer) =>
                map
                    (fn (bname, backend) =>
                        { name = "opt-" ^ oname ^ "-backend-" ^ bname,
                          optimizer = optimizer,
                          backend = backend })
                    backends)
            optimizers)
```

So:

```text
ordinary SML higher-order programming
             ↓
generation of module configurations
             ↓
compiler runs on every configuration
```

This is one of the strongest arguments for the mechanism.

---

# 2. Debug build that wraps selected modules with logging

This case is even more compelling.

Suppose your program normally contains:

```sml
structure Store : STORE = StoreImpl
structure Parser : PARSER = ParserImpl
structure Solver : SOLVER = SolverImpl
```

You have generic instrumentation functors:

```sml
functor LogStore
    (structure Inner : STORE) : STORE =
struct
    fun get k =
        let
            val _ = Log.debug ("Store.get " ^ k)
        in
            Inner.get k
        end

    fun put (k, v) =
        let
            val _ = Log.debug ("Store.put " ^ k)
        in
            Inner.put (k, v)
        end
end
```

and similarly:

```sml
LogParser : PARSER -> PARSER
LogSolver : SOLVER -> SOLVER
```

The release graph is:

```sml
val release =
    makeApplication
        { store  = StoreImpl,
          parser = ParserImpl,
          solver = SolverImpl }
```

The debug graph:

```sml
val debug =
    makeApplication
        { store  = Build.apply LogStore StoreImpl,
          parser = Build.apply LogParser ParserImpl,
          solver = Build.apply LogSolver SolverImpl }
```

Already useful.

But the build-time transformation lets you do something more systematic.

Suppose modules carry metadata:

```sml
Build.name      : Build.module -> string
Build.signature : Build.module -> Build.signature
```

You could define:

```sml
fun instrument m =
    case Build.name m of
        "Store" =>
            SOME (Build.apply LogStore m)

      | "Parser" =>
            SOME (Build.apply LogParser m)

      | "Solver" =>
            SOME (Build.apply LogSolver m)

      | _ =>
            NONE
```

and then:

```sml
val release =
    Application

val debug =
    Build.rewrite instrument Application
```

Conceptually:

```text
release:

            Application
          /     |      \
       Store  Parser  Solver


debug:

            Application
          /     |      \
      LogStore LogParser LogSolver
          |       |        |
        Store   Parser    Solver
```

Crucially, the logging code does **not exist at all in the release module graph**.

This is stronger than:

```sml
if debug then Log.debug ...
```

because the release build never includes the wrapper.

Consequences:

```text
no runtime branch
no logging dependency
no logging strings
no logging initialization
possibly no logging library linked
no effect on optimizer assumptions
```

That gives you genuine structural build variants.

You can even make instrumentation declarative:

```sml
val debug =
    instrumentModules
        { modules =
            ["Store",
             "Parser",
             "Solver"],
          wrapper =
            fn sig_ =>
                loggingWrapperFor sig_ }
        Application
```

This starts resembling an aspect system, but entirely at build time.

---

# 3. Platform-specific module replacement

Suppose your application depends on:

```sml
signature FILESYSTEM =
sig
    type file

    val openFile : string -> file
    val read     : file -> Word8Vector.vector
    val close    : file -> unit
end
```

and you provide:

```text
filesystem-posix.sml
filesystem-windows.sml
filesystem-wasi.sml
```

Instead of conditional compilation inside the application, the build graph decides which implementation exists.

```sml
datatype platform =
    Linux
  | MacOS
  | Windows
  | WASI
```

Then:

```sml
fun filesystemFor platform =
    case platform of
        Linux =>
            Build.source "platform/posix/filesystem.sml"

      | MacOS =>
            Build.source "platform/posix/filesystem.sml"

      | Windows =>
            Build.source "platform/windows/filesystem.sml"

      | WASI =>
            Build.source "platform/wasi/filesystem.sml"
```

Similarly:

```sml
fun clockFor platform =
    case platform of
        Linux =>
            Build.source "platform/linux/clock.sml"

      | MacOS =>
            Build.source "platform/macos/clock.sml"

      | Windows =>
            Build.source "platform/windows/clock.sml"

      | WASI =>
            Build.source "platform/wasi/clock.sml"
```

Then:

```sml
fun applicationFor platform =
    let
        val Platform =
            Build.structure_ "Platform"
                [filesystemFor platform,
                 clockFor platform,
                 networkingFor platform]

    in
        Build.apply ApplicationFn Platform
    end
```

Now:

```sml
val linux =
    applicationFor Linux

val windows =
    applicationFor Windows

val macos =
    applicationFor MacOS
```

and:

```sml
val _ =
    Build.emit "myapp-linux"
        (Build.compile {root = linux, options = []})

val _ =
    Build.emit "myapp-windows.exe"
        (Build.compile {root = windows, options = []})
```

The important architectural result is:

> `ApplicationFn` does not know that platforms exist.

It merely requires:

```sml
signature PLATFORM =
sig
    structure FileSystem : FILESYSTEM
    structure Clock      : CLOCK
    structure Network    : NETWORK
end
```

That is proper module abstraction rather than preprocessor abstraction.

### Platform families

And again ordinary SML gives you more power than configuration files.

For example:

```sml
val platforms =
    [("linux-x86_64", Linux X86_64),
     ("linux-aarch64", Linux AArch64),
     ("windows-x86_64", Windows X86_64),
     ("macos-aarch64", MacOS AArch64)]
```

Then:

```sml
val builds =
    map
        (fn (name, target) =>
            Build.compile
                { root = applicationFor target,
                  options =
                      [Compiler.Target target] })
        platforms
```

This scales cleanly to:

```text
OS
× CPU
× word size
× GC
× runtime
× optimization level
```

without hard-coding that product into the build system.

---

# 4. Home / Pro / Enterprise products

This is another case where modules work better than feature flags.

Suppose you have:

```sml
signature FEATURES =
sig
    structure Database : DATABASE
    structure Auth     : AUTH
    structure Reports  : REPORTS
    structure Cluster  : CLUSTER
end
```

Different implementations exist:

```text
SQLiteDatabase
PostgresDatabase

LocalAuth
LDAPAuth

BasicReports
AdvancedReports

SingleNode
DistributedCluster
```

Then:

```sml
val HomeFeatures =
    Build.structure_ "HomeFeatures"
        [SQLiteDatabase,
         LocalAuth,
         BasicReports,
         SingleNode]

val ProFeatures =
    Build.structure_ "ProFeatures"
        [PostgresDatabase,
         LocalAuth,
         AdvancedReports,
         SingleNode]

val EnterpriseFeatures =
    Build.structure_ "EnterpriseFeatures"
        [PostgresDatabase,
         LDAPAuth,
         AdvancedReports,
         DistributedCluster]
```

The common application is:

```sml
val ApplicationFn =
    Build.source "application-fn.sml"
```

and:

```sml
val home =
    Build.apply ApplicationFn HomeFeatures

val pro =
    Build.apply ApplicationFn ProFeatures

val enterprise =
    Build.apply ApplicationFn EnterpriseFeatures
```

The resulting binaries genuinely have different module graphs.

For example:

```text
Home

Application
 ├── SQLite
 ├── LocalAuth
 ├── BasicReports
 └── SingleNode
```

versus:

```text
Enterprise

Application
 ├── PostgreSQL
 ├── LDAP
 ├── AdvancedReports
 └── DistributedCluster
```

Again, this is fundamentally different from:

```sml
if license = Enterprise then ...
```

because the Home executable need never contain:

```text
LDAP code
distributed cluster code
enterprise reporting code
PostgreSQL support
```

at all.

---

# Now combine all four dimensions

This is where the idea starts paying off substantially.

You might have:

```sml
datatype edition =
    Home
  | Pro
  | Enterprise

datatype mode =
    Release
  | Debug

datatype optimizer =
    Baseline
  | NewOptimizer

datatype platform =
    Linux
  | Windows
  | MacOS
```

And a complete build specification:

```sml
type configuration =
    { platform  : platform,
      edition   : edition,
      mode      : mode,
      optimizer : optimizer }
```

Then:

```sml
fun makeBuild
    { platform,
      edition,
      mode,
      optimizer } =
    let
        val Platform =
            makePlatform platform

        val Features =
            makeFeatures edition

        val Optimizer =
            makeOptimizer optimizer

        val Base =
            Build.apply
                ApplicationFn
                (Build.structure_ "Environment"
                    [Platform,
                     Features,
                     Optimizer])

        val Final =
            case mode of
                Release =>
                    Base

              | Debug =>
                    instrument Base
    in
        Final
    end
```

Notice what happened.

The build process itself is now just function composition:

```text
platform
    \
edition
      \
optimizer ---> makeBuild ---> module graph
      /
mode /
```

And because this is ordinary SML, you can generate test matrices:

```sml
val platforms =
    [Linux, Windows, MacOS]

val editions =
    [Home, Pro, Enterprise]

val modes =
    [Release, Debug]

val optimizers =
    [Baseline, NewOptimizer]
```

Cartesian product:

```sml
fun product xs ys =
    List.concat
        (map
            (fn x =>
                map (fn y => (x, y)) ys)
            xs)

val configurations =
    List.concat
        (map
            (fn platform =>
                List.concat
                    (map
                        (fn edition =>
                            List.concat
                                (map
                                    (fn mode =>
                                        map
                                            (fn optimizer =>
                                                { platform = platform,
                                                  edition = edition,
                                                  mode = mode,
                                                  optimizer = optimizer })
                                            optimizers)
                                    modes))
                        editions))
            platforms)
```

That's:

```text
3 platforms
×
3 editions
×
2 modes
×
2 optimizers

= 36 module graphs
```

Then:

```sml
val executables =
    map
        (fn config =>
            (config,
             Build.compile
                 { root = makeBuild config,
                   options = compilerOptions config }))
        configurations
```

Now you can run correctness testing across the whole matrix:

```sml
val testResults =
    map
        (fn (config, exe) =>
            (config, Build.test exe))
        executables
```

or benchmark only the interesting subset:

```sml
fun benchmarkable
    { platform = Linux,
      mode = Release,
      ... } =
      true
  | benchmarkable _ =
      false

val benchmarks =
    map
        (fn (config, exe) =>
            (config, Build.benchmark exe))
        (List.filter
            (fn (config, _) =>
                benchmarkable config)
            executables)
```

This is where using SML as the build language is substantially better than inventing increasingly complicated configuration syntax.

---

# An even better abstraction: transformations

I would probably make module transformations first-class concepts in the build library.

For example:

```sml
type transformation =
    Build.module -> Build.module
```

Then:

```sml
val logging :
    transformation

val profiling :
    transformation

val boundsChecking :
    transformation

val coverage :
    transformation

val tracing :
    transformation
```

Composition is just function composition:

```sml
infixr 9 >>>

fun (f >>> g) x =
    g (f x)
```

Then:

```sml
val debugTransform =
    logging
    >>> profiling
    >>> boundsChecking
```

and:

```sml
val releaseTransform =
    optimize
    >>> stripDebugInfo
```

So:

```sml
fun modeTransform Debug =
      debugTransform
  | modeTransform Release =
      releaseTransform
```

and the whole build reduces to:

```sml
fun makeBuild cfg =
    cfg
    |> makeBaseProgram
    |> modeTransform (#mode cfg)
```

If you dislike `|>`:

```sml
fun makeBuild cfg =
    modeTransform (#mode cfg)
        (makeBaseProgram cfg)
```

This gives you an algebra of build transformations.

---

# Compiler experiments become particularly elegant

Given your Rune compiler work, I think this is one of the most useful applications.

Imagine testing:

```text
closure conversion A/B
GC A/B/C
inliner A/B
bytecode optimizer A/B
VM dispatch A/B
representation strategy A/B
```

Instead of these being compiler-global flags, many of them can themselves be modules.

For example:

```sml
signature CLOSURE_CONVERSION = ...
signature INLINER            = ...
signature CODE_GENERATOR     = ...
signature GC                 = ...
```

Then:

```sml
val compilerConfigurations =
    crossProduct
        { closure =
            [ClosureOld,
             ClosureNew],

          inliner =
            [NoInline,
             SimpleInline,
             AggressiveInline],

          backend =
            [BytecodeBackend,
             NativeBackend],

          gc =
            [CheneyGC,
             MarkSweepGC] }
```

That's:

```text
2 × 3 × 2 × 2 = 24 compilers
```

Your build program can instantiate all 24:

```sml
fun makeCompiler
    { closure,
      inliner,
      backend,
      gc } =
    Build.apply
        CompilerFn
        (Build.structure_ "CompilerConfiguration"
            [closure,
             inliner,
             backend,
             gc])
```

Then use every compiler to compile the same benchmark suite:

```sml
val compilers =
    map
        (fn cfg =>
            (cfg, makeCompiler cfg))
        compilerConfigurations
```

And eventually you could express:

```text
compiler configuration
    ×
program
    ×
compiler optimization flags
    ×
runtime configuration
```

as one experiment description.

That ties very naturally into the provenance-heavy benchmarking system you've been considering for Rune. 

---

# More interesting: compiler builds can compile compiler builds

Because your build language is itself SML, this naturally extends to bootstrap experiments.

For example:

```sml
val RuneA =
    makeCompiler
        { closure = ClosureOld,
          inliner = SimpleInline,
          backend = BytecodeBackend,
          gc = CheneyGC }

val RuneB =
    makeCompiler
        { closure = ClosureNew,
          inliner = AggressiveInline,
          backend = BytecodeBackend,
          gc = CheneyGC }
```

Compile the compiler itself:

```sml
val runeAExe =
    Build.compile
        { root = RuneA,
          options = [] }

val runeBExe =
    Build.compile
        { root = RuneB,
          options = [] }
```

And conceptually:

```sml
val compilerBuiltByA =
    Build.compileWith runeAExe RuneSource

val compilerBuiltByB =
    Build.compileWith runeBExe RuneSource
```

Then:

```sml
val benchmarkA =
    Build.benchmarkCompiler compilerBuiltByA

val benchmarkB =
    Build.benchmarkCompiler compilerBuiltByB
```

Your build graph can therefore directly represent:

```text
Rune source
    |
    +---- compiled by Rune-A ----> Rune[A]
    |
    +---- compiled by Rune-B ----> Rune[B]

Rune[A] --compile--> benchmark X --> performance
Rune[B] --compile--> benchmark X --> performance
```

This is quite a bit beyond what people normally mean by "build system".

It starts becoming a **programmable experiment graph**.

---

# One important design refinement

I wouldn't make replacement depend heavily on strings like:

```sml
Build.replace
    { path = "Application.Store",
      ... }
```

That's useful occasionally, but weakly typed.

Prefer explicit module parameters:

```sml
fun makeApplication
    { filesystem,
      network,
      database,
      logger,
      optimizer } =
    Build.apply
        ApplicationFn
        (Build.structure_ "Dependencies"
            [filesystem,
             network,
             database,
             logger,
             optimizer])
```

Then build-time rewriting is mostly functional composition rather than AST mutation.

Use `rewrite` for cross-cutting things such as:

```text
logging
coverage
profiling
sanitizers
instrumentation
```

Use explicit functor arguments for architectural variation:

```text
platform
edition
database
backend
GC
optimizer
```

That distinction keeps the system comprehensible.

---

## This suggests a surprisingly clean conceptual model

Your build language has three main kinds of things:

```sml
type module
type transformation = module -> module
type configuration
```

Then most builds have the form:

```text
Configuration
      |
      v
base module graph
      |
      v
transformations
      |
      v
compiler
      |
      v
artifact
```

Or mathematically:

```text
Configuration
    → ModuleGraph
    → ModuleGraph
    → Artifact
```

And SML is already particularly well suited to expressing all three steps.

So for the cases you listed, I think this mechanism is doing genuine work rather than merely being cute syntax. The strongest cases are **variant matrices, module substitution, structural instrumentation, and compiler experiments**. They are all essentially computations over module graphs, and ordinary higher-order SML is a very natural language in which to express those computations.

----

prior art in this area

----

There is substantial prior art around pieces of this idea, but I do not know of a mainstream SML system that quite combines them in the exact way you are proposing: **ordinary core-language computation at build time over typed module-graph objects, with the result then elaborated/compiled as an ordinary SML program**.

Because web access is disabled here, I cannot verify the latest state of niche research or newer systems. Historically, the closest lines of work are these.

### 1. SML/NJ Compilation Manager (CM)

SML/NJ's CM is probably the first thing to study from the SML side. It already treats compilation as something richer than “compile these files in order”: it tracks dependencies between compilation units, groups libraries, supports conditional compilation-like mechanisms, and understands SML's static environment.

But CM descriptions are not themselves arbitrary SML programs manipulating module objects. They are a build-description language around the compiler.

So compared with your proposal:

| Feature | CM | Your idea |
|---|---:|---:|
| Dependency graph | yes | yes |
| Understands SML compilation units | yes | yes |
| Can choose variants | somewhat | yes |
| Arbitrary higher-order computation | no | yes |
| `module -> module` transformation | no | yes |
| Build-time use of SML itself | no | yes |
| Generate many module configurations programmatically | limited | central |

CM is important because it demonstrates that the build system can be tightly integrated with the SML elaborator rather than being an external Make-like tool.

Relevant historical work includes Matthias Blume's work on compilation management for ML, especially the development of CM and later work on scalable compilation management.

---

### 2. ML Basis / MLton

MLton's `.mlb` files are another close relative.

An MLB file describes a compilation environment using things such as:

```text
basis
local
open
ann
```

and can compose multiple bases.

This is more semantically aware than a conventional build system. An MLB file essentially constructs an SML elaboration environment.

The crucial connection to your idea is:

> MLB already treats compilation environments as composable objects.

But MLB deliberately has a small declarative language rather than full SML computation.

You could almost view your proposal as:

```text
MLB
+
ordinary SML computation
+
first-class module/build objects
```

Instead of:

```text
myprogram.mlb
```

containing a fixed configuration, you could have:

```sml
fun basisFor cfg =
    ...
```

producing one.

That is a fairly natural generalization of MLB.

---

### 3. Higher-order module calculi

This is the nearest theoretical prior art, even though your staging differs.

There is a large literature on higher-order modules where modules themselves become arguments/results of module operators.

Important strands include:

- MacQueen's work on modules for Standard ML.
- Harper, Mitchell, and Moggi on higher-order modules and phase distinctions.
- Harper and Lillibridge on translucent sums.
- Leroy's work on applicative functors and OCaml's module system.
- Dreyer's work on recursive modules and type abstraction.
- Rossberg's work on modules and abstraction.

The important conceptual relationship is:

```text
higher-order module system

functor : Module -> Module
```

versus your:

```text
build-time SML

function : ModuleRep -> ModuleRep
```

They look similar operationally, but sit in different phases.

A higher-order functor makes module computation part of the language's static semantics.

Your mechanism makes module computation part of an earlier meta-stage.

That distinction is significant because it lets you keep SML97 itself relatively conventional.

---

### 4. MetaML and staged programming

This is conceptually very close.

MetaML, developed by Walid Taha and Tim Sheard, explored explicit multi-stage programming.

The basic idea is that one stage computes code that will execute at another stage:

```text
Stage 0
   constructs
Stage 1 program
```

Your design is essentially a specialized form:

```text
build-stage SML
   constructs
module-stage SML
   elaborates to
core-stage SML
```

The biggest difference is that your generated object is not arbitrary core-language syntax. It is specifically a **module graph**.

That restriction may actually make your design much cleaner.

You could describe it as domain-specific staged programming where:

```text
code<T>
```

is replaced with something more like:

```text
module<S>
```

although the latter is much harder to type inside plain SML.

---

### 5. Template Haskell

Template Haskell is another obvious comparison.

It allows Haskell code to run at compile time and construct Haskell syntax:

```haskell
Q Exp
Q Dec
```

So Haskell code operates on Haskell program representations.

Conceptually:

```text
core language
     ↓
compile-time execution
     ↓
language syntax
```

Your mechanism is narrower:

```text
SML core language
     ↓
build-time execution
     ↓
module graph
```

I think yours has an advantage for this use case because you are not primarily trying to manipulate syntax.

You want:

```sml
Build.module
```

rather than:

```sml
ModuleAst.t
```

That means you can preserve semantic properties like:

```text
module identity
signature matching
functor generativity
dependencies
sharing
```

instead of doing AST metaprogramming.

---

### 6. Racket's module and macro system

Racket is probably one of the richest pieces of practical prior art.

Racket's macro system and module system allow substantial computation during expansion. Modules can be transformed, generated, instantiated at different phases, and imported for syntax versus runtime.

Racket explicitly tracks phases such as:

```text
phase 0   runtime
phase 1   macro expansion
phase 2   macros used by macros
...
```

This is very relevant to your concern about preserving phase separation.

Racket essentially demonstrates that:

> very powerful compile-time computation does not require abandoning phase separation.

Its model is more general and more dynamic than what you are proposing, but the conceptual lesson is useful.

Your system might deliberately be much simpler:

```text
phase -1   build program
phase 0    SML module/core elaboration
phase 1    runtime
```

rather than arbitrary phase towers.

---

### 7. Haskell Backpack

Backpack is particularly relevant to your product/platform configuration examples.

Backpack provides separately compiled components with signatures and module substitution.

A package can say, roughly:

```text
I require module X satisfying signature S
```

and another component supplies it.

That supports things like:

```text
implementation A
implementation B
```

plugged into the same program.

This resembles your:

```sml
ApplicationFn {
    FileSystem = LinuxFS,
    Database   = SQLite
}
```

Backpack's emphasis is separate compilation and mixin-style linking rather than arbitrary build-time computation.

Your build-language layer would give something like:

```text
Backpack-style module substitution
+
higher-order configuration generation
```

which is considerably more expressive.

---

### 8. Racket Units

Racket's unit system is even closer to the module-composition side.

Units are separately composable program components with imports and exports, and unit linking is programmable.

You can construct component graphs independently of lexical modules.

The conceptual model is:

```text
component
 + component
 + linker
 → program
```

That is extremely close to your desired:

```text
module
 + module
 + SML build program
 → module graph
```

Racket Units are worth studying specifically for issues around:

```text
component identity
linking
cyclic dependencies
signature matching
instantiation
```

---

### 9. OCaml first-class modules

OCaml takes the opposite route from your proposal in an interesting way.

OCaml lets modules be packed into core-language values:

```ocaml
(module M : S)
```

and unpacked later.

That literally introduces:

```text
core language → modules
```

inside the language.

For example, conceptually:

```ocaml
let choose_backend x =
  if x then
    (module LinuxBackend : BACKEND)
  else
    (module WindowsBackend : BACKEND)
```

This breaks the strict SML-style division to some extent.

Your build-stage mechanism gives you much of the same compositional power without making modules first-class at runtime:

```text
build SML
    chooses backend

compiled program
    contains exactly one backend
```

For your use case, that's arguably preferable.

---

### 10. OCaml functors + Dune

The OCaml ecosystem also gets surprisingly close through composition of two layers.

OCaml provides strong module abstractions and functors, while Dune handles build variants, preprocessing, generated files, platform conditions, libraries, and compilation modes.

But Dune is deliberately declarative.

Your proposal could be characterized as replacing something like:

```text
OCaml module system
+
Dune configuration language
```

with:

```text
SML module system
+
SML itself as the build/configuration language
```

The latter gives arbitrary abstraction without Dune having to grow its own programming language.

---

### 11. Shake

Shake is relevant from the build-system side rather than the module side.

Shake is a Haskell library for writing build systems in Haskell.

Instead of having:

```text
Makefile DSL
```

you have:

```haskell
main :: IO ()
```

and ordinary Haskell abstraction controls the build.

That demonstrates one important principle behind your proposal:

> don't keep extending a build DSL; embed the build system in an existing general-purpose functional language.

Your proposal essentially takes Shake one level deeper.

Shake operates over:

```text
files
commands
dependencies
```

whereas you want:

```text
modules
signatures
functors
compiler environments
```

So you could almost call the idea:

> Shake over the compiler's module graph rather than the filesystem graph.

That is a useful mental model.

---

### 12. Bazel configuration transitions

Bazel has another piece of relevant prior art.

Its build graph supports configurations and configuration transitions. One logical target can produce multiple configured targets based on things such as:

```text
architecture
platform
compiler flags
features
```

So the same source tree can represent:

```text
Linux debug
Linux release
Windows debug
Windows release
```

as distinct graph nodes.

Your system does the same, but at a semantically richer level:

```text
Bazel:
Target × configuration → configured target

Your system:
Module graph × configuration → specialized module graph
```

Bazel therefore provides useful implementation ideas around:

```text
configuration keys
memoization
graph identity
incremental rebuilds
variant explosion
```

even though its language model is quite different.

---

### 13. Nix

Nix is also closely related in spirit.

A Nix package is basically a pure function of dependencies and configuration:

```text
inputs → derivation
```

You can write:

```text
packageSet compiler platform features
```

and produce different package graphs.

Your proposal has a structurally similar model:

```text
configuration → module graph
```

and potentially:

```text
module graph → compilation derivation
```

Nix is worth studying especially for:

```text
content-addressing
reproducibility
pure configuration
dependency graph identity
build caching
```

Those concepts map remarkably well onto your compiler variant experiments.

---

### 14. ML functorized compilers themselves

There is also a more mundane but important precedent: many ML compilers and systems are internally heavily functorized.

Compiler phases often look conceptually like:

```sml
functor ParserFn(...)
functor ElaboratorFn(...)
functor OptimizerFn(...)
functor CodegenFn(...)
```

and a top-level file chooses implementations by instantiating functors.

So people already use the SML module language manually as a kind of configuration/build system.

Your idea merely moves one level upward:

```text
today:

human writes:
    structure Backend = X86Backend
    structure GC = CheneyGC

your approach:

SML build program generates:
    structure Backend = ...
    structure GC = ...
```

The key novelty isn't functorized architecture.

It's **programmatic construction of functorized architectures**.

---

## The research concept I'd use to describe it

There are several overlapping labels, none perfect:

- staged module programming
- module-level metaprogramming
- programmable module linking
- typed component composition
- generative module configuration
- module graph metaprogramming
- staged compilation management

Of those, **module graph metaprogramming** is probably the clearest description of what you're proposing.

You don't really want macros.

You don't really want runtime first-class modules.

You don't merely want higher-order functors.

You want:

```text
ordinary SML program
        |
        | computes
        v
typed module graph
        |
        | elaborates
        v
core SML
        |
        | compiles
        v
artifact
```

---

# Where I think the closest combination lies

If I decomposed your design into known prior art, I'd say:

```text
SML/NJ CM / ML Basis
    compiler-aware dependency management

+

Shake
    build system embedded in a functional language

+

MetaML / Template Haskell
    one language stage constructs another program stage

+

Racket phases
    explicit phase separation

+

Backpack / Racket Units
    component substitution and linking

+

ML higher-order module theory
    semantics of computation over modules
```

Your distinctive move is to combine these into a deliberately restricted architecture:

```text
SML core language
used only at build time
to manipulate typed SML module objects
```

rather than adding arbitrary reflection or first-class runtime modules.

That restriction is likely a strength.

## The papers/systems I would put at the top of the reading list

If your goal is specifically to design Rune's version of this, I'd start with:

1. **SML/NJ Compilation Manager / Matthias Blume** — compiler-aware build graphs.
2. **ML Basis / MLton** — compositional static environments.
3. **Harper–Mitchell–Moggi, higher-order modules** — theory of modules as operands.
4. **Leroy on applicative functors** — identity and sharing semantics.
5. **MetaML / Taha & Sheard** — staging.
6. **Racket phase separation and Units** — compile-time computation plus component linking.
7. **Haskell Backpack** — signatures and module substitution.
8. **Shake** — embedding a build system in a functional host language.
9. **Nix** — reproducible configuration-to-build graphs.
10. **Bazel configured targets/transitions** — managing combinatorial build variants.

The unusually fertile connection for your design is probably **ML Basis + Shake + higher-order module theory**. MLB already knows what an ML compilation environment is; Shake demonstrates how pleasant arbitrary functional computation over a build graph can be; higher-order-module work tells you what semantic traps appear once module-producing computations become nontrivial.

A next useful step would be to design a minimal `BUILD` signature for Rune and then test whether it can express CM, MLB, Backpack-style substitution, debug instrumentation, and your compiler experiment matrix without adding special cases.

----

dune and backpack seem to be most relevant, trying to answer this question for ocaml and haskell. can you give an overview of both. they seem to be declarative? what are the advantages/disadvantages of a declarative language rather than embedding in sml. give concrete examples for each dune/backpack/my propose solution for each of the concrete examples we studied earlier

----

I can give the architectural comparison, but I cannot live-check the current Dune/Backpack manuals because web search is disabled here. The Dune examples below follow the established virtual-library/profile model; I’ll mark Backpack/Cabal snippets as schematic where exact Cabal surface syntax is less important than the unit instantiation semantics.

The short version is:

> **Dune describes a build graph. Backpack describes a module-linking graph. Your proposal computes a module/build graph.**

That distinction becomes quite important for the examples you have in mind.

## 1. Dune: declarative build composition for OCaml

Dune is primarily a build system. A `dune` file describes artifacts, dependencies, compilation flags, preprocessors, generated files, tests, and so forth:

```lisp
(library
 (name compiler)
 (libraries parser ir))

(executable
 (name rune)
 (libraries compiler runtime))
```

The user does not normally write an algorithm saying:

```text
inspect this list
map over it
construct 24 compiler configurations
filter some
transform every module satisfying predicate P
```

Instead you declare desired objects and relationships, and Dune determines the build DAG.

For module substitution, one particularly relevant Dune feature is **virtual libraries**.

Conceptually you can have:

```text
platform/
    Platform.mli       -- required interface
```

with:

```lisp
(library
 (name platform)
 (virtual_modules Platform))
```

and implementations:

```lisp
(library
 (name platform_linux)
 (implements platform))
```

and:

```lisp
(library
 (name platform_windows)
 (implements platform))
```

A consumer depends against the virtual interface:

```lisp
(library
 (name application)
 (libraries platform))
```

and the final build supplies one implementation.

That's very similar to ML functor parameterization, except the substitution is performed at build/linking level rather than by an OCaml functor invocation.

Dune also has profiles, conditional fields, preprocessing/PPX integration, generated rules, aliases for tests/benchmarks, and other configuration mechanisms. But the basic philosophy remains:

```text
declarations
    ↓
Dune computes build graph
    ↓
actions
```

rather than:

```text
user program
    ↓
user computes build graph
```

---

# 2. Backpack: declarative module linking for Haskell

Backpack operates one level closer to what you are proposing.

A Backpack package can say:

> I contain this code, but I require some modules satisfying these signatures.

Suppose:

```haskell
-- Database.hsig

signature Database where

data Connection

connect :: String -> IO Connection
query   :: Connection -> String -> IO [String]
```

And an application contains ordinary Haskell:

```haskell
module Application where

import Database

run = do
    db <- connect "..."
    ...
```

The application package is **indefinite** until the `Database` hole is filled.

You might have implementations:

```text
database-sqlite
    provides Database

database-postgres
    provides Database
```

Then Backpack essentially permits instantiations analogous to:

```text
Application[
    Database := SQLite.Database
]
```

and:

```text
Application[
    Database := Postgres.Database
]
```

The real machinery uses GHC units/package IDs, signatures, `mixins`, module renaming, etc., but this substitution model is the important point.

An instantiated unit gets an identity reflecting its substitutions. Conceptually:

```text
application[
    Database = sqlite:Database
]
```

is different from:

```text
application[
    Database = postgres:Database
]
```

This is particularly interesting for Rune because it is exactly the sort of identity question that appears when your build system starts constructing module configurations.

Backpack therefore has something roughly like:

```text
module signature
       ↓
required module hole

implementation module
       ↓
fills hole

indefinite unit
       ↓
definite instantiated unit
```

This is closer to ML module semantics than Dune itself.

But Backpack's composition language is still basically **declarative substitution**. There isn't normally arbitrary Haskell computation saying:

```haskell
variants =
    [ instantiate compiler
        [Optimizer := o, Backend := b]
    | o <- optimizers
    , b <- backends
    ]
```

as the Backpack linking language itself.

You could of course write Haskell tooling around Cabal/Backpack. But then you've added another meta-level, which is essentially where your idea starts.

---

# 3. What “declarative” buys Dune and Backpack

The biggest benefit is that the build system can understand the graph **without executing arbitrary user computation**.

Suppose Dune reads:

```lisp
(executable
 (name foo)
 (libraries a b c))
```

It immediately knows:

```text
foo → a
foo → b
foo → c
```

This gives it very strong control over dependency discovery, incremental rebuilds, parallel scheduling, caching, sandboxing, reproducibility, IDE queries, error checking, and graph visualization.

With arbitrary SML:

```sml
val program =
    if expensiveComputation () then
        ...
    else
        ...
```

the build system may have to execute the build program before it even knows which nodes exist.

That is the central trade-off.

A declarative system tends to make these properties straightforward:

| Property | Declarative Dune/Backpack | Arbitrary SML meta-program |
|---|---:|---:|
| Discover graph statically | excellent | potentially difficult |
| Parallel scheduling | easy | after graph construction |
| Incremental builds | easy | needs disciplined API |
| Reproducibility | easier | effects must be controlled |
| Remote caching | easier | build computation must be fingerprinted |
| Security/sandboxing | easier | arbitrary SML is more powerful |
| IDE inspection | easy | may require executing meta-program |
| Arbitrary abstraction | limited | excellent |
| Higher-order composition | limited | natural |
| Generate variant matrices | repetitive | trivial |
| Generic transformations | awkward | natural |
| Domain-specific algorithms | DSL keeps growing | ordinary SML |

And the biggest long-term problem with declarative DSLs is predictable:

```text
simple DSL
    ↓
conditions needed
    ↓
variables
    ↓
macros
    ↓
iteration
    ↓
functions
    ↓
user-defined abstraction
    ↓
you have accidentally invented a programming language
```

Embedding in SML avoids that trap.

---

# 4. Example A: compiler variants

Your requirement was something like:

```text
Optimizer:
    old
    new
    none

Backend:
    bytecode
    native

GC:
    cheney
    marksweep
```

and you want to compile/test/benchmark the combinations.

## Dune

You could model the implementation points as virtual libraries.

Conceptually:

```text
optimizer
    virtual module Optimizer

optimizer_old
    implements optimizer

optimizer_new
    implements optimizer

optimizer_none
    implements optimizer
```

and similarly for backend and GC.

The compiler itself depends on:

```lisp
(library
 (name compiler)
 (libraries optimizer backend gc))
```

You could then provide separate final targets:

```lisp
(executable
 (name rune_old_bytecode_cheney)
 (libraries compiler
            optimizer_old
            backend_bytecode
            gc_cheney))

(executable
 (name rune_new_bytecode_cheney)
 (libraries compiler
            optimizer_new
            backend_bytecode
            gc_cheney))

(executable
 (name rune_new_native_marksweep)
 (libraries compiler
            optimizer_new
            backend_native
            gc_marksweep))
```

The precise organization might use subdirectories or generated stanzas, but conceptually this is the pattern.

The pain appears immediately.

For:

```text
3 optimizers ×
2 backends ×
2 collectors
```

you have 12 configurations that somebody needs to enumerate.

Dune can automate portions of that with generated build descriptions/rules, but once you start generating Dune descriptions with another program, you're effectively introducing a meta-build language.

Correctness comparison could then be an alias/rule that executes several variants:

```lisp
(alias
 (name differential-test)
 (deps
   %{exe:rune_old_bytecode_cheney.exe}
   %{exe:rune_new_bytecode_cheney.exe})
 (action
   (run ./compare-compilers.exe ...)))
```

Again: good declarative graph, but composition requires enumeration.

---

## Backpack

This is conceptually cleaner.

Make the compiler an indefinite unit requiring:

```text
Optimizer
Backend
GC
```

Then Backpack instantiations are roughly:

```text
Compiler[
    Optimizer := OptimizerOld,
    Backend   := BytecodeBackend,
    GC        := CheneyGC
]
```

and:

```text
Compiler[
    Optimizer := OptimizerNew,
    Backend   := NativeBackend,
    GC        := MarkSweepGC
]
```

This is very close to:

```sml
CompilerFn
    (structure Optimizer = OptimizerNew
     structure Backend   = NativeBackend
     structure GC        = MarkSweepGC)
```

The important difference is that Backpack treats the holes and fillings as unit/module-linking configuration.

It can support multiple distinct instantiations of the same indefinite code.

But Cabal still needs to describe which instantiations are wanted.

You don't naturally get:

```haskell
sequence
    [ instantiate o b g
    | o <- optimizers
    , b <- backends
    , g <- collectors
    ]
```

inside Backpack itself.

---

## Your SML system

This becomes ordinary functional programming:

```sml
val optimizers =
    [("old",  OptimizerOld),
     ("new",  OptimizerNew),
     ("none", OptimizerNone)]

val backends =
    [("bytecode", BytecodeBackend),
     ("native",   NativeBackend)]

val collectors =
    [("cheney",    CheneyGC),
     ("marksweep", MarkSweepGC)]
```

Then:

```sml
val configurations =
    List.concat
      (map
        (fn (oname, optimizer) =>
          List.concat
            (map
              (fn (bname, backend) =>
                map
                  (fn (gname, gc) =>
                    { name =
                        oname ^ "-" ^
                        bname ^ "-" ^
                        gname,

                      optimizer = optimizer,
                      backend   = backend,
                      gc        = gc })
                  collectors)
              backends))
        optimizers)
```

and:

```sml
fun compilerFor
    {optimizer, backend, gc, ...} =
    Build.apply
        CompilerFn
        (Build.structure_
            [("Optimizer", optimizer),
             ("Backend",   backend),
             ("GC",        gc)])
```

Then:

```sml
val compilers =
    map compilerFor configurations
```

and:

```sml
val results =
    map
        (fn compiler =>
            Build.test compiler)
        compilers
```

The difference is quite stark:

```text
Dune
    enumerate configured targets

Backpack
    enumerate module instantiations

SML meta-build
    compute the set of module instantiations
```

For your compiler experimentation work, that third operation is useful in its own right.

---

# 5. Example B: debug build wraps modules with logging

Suppose:

```text
Parser
Store
Solver
```

should be instrumented in debug builds but not release builds.

## Dune

There are two reasonably natural strategies.

One is **PPX instrumentation**.

You can arrange for selected code to be preprocessed with some logging transformation:

```lisp
(library
 (name solver)
 (preprocess
   (pps logging_ppx)))
```

or use different preprocessing depending on profile.

Conceptually:

```text
debug:
    Solver.ml
       ↓ logging PPX
    instrumented Solver

release:
    Solver.ml
       ↓
    Solver
```

That's powerful for syntax-level instrumentation.

But notice that this isn't:

```text
Module -> Module
```

composition.

It's:

```text
AST -> AST
```

transformation.

The second possibility is explicit implementation substitution.

Have:

```text
Store_core

Store_plain
    wraps Store_core

Store_logged
    wraps Store_core + logging
```

with both satisfying the same virtual interface.

Then:

```text
release → Store_plain
debug   → Store_logged
```

This works well, but you explicitly design each variation point.

Dune can't normally say:

> traverse my entire module graph and wherever module `M` satisfies condition P, replace it by `Log(M)`.

That's outside the normal declarative abstraction.

---

## Backpack

Backpack can express the explicit wrapper surprisingly nicely.

Suppose:

```text
signature Store
```

and base implementation:

```text
StoreBase
```

Then a logging component could itself require an inner store:

```text
LoggedStore
    requires StoreInner
    provides Store
```

Conceptually:

```text
LoggedStore[
    StoreInner := StoreBase
]
```

The debug application gets:

```text
Application[
    Store := LoggedStore[
        StoreInner := StoreBase
    ]
]
```

while release gets:

```text
Application[
    Store := StoreBase
]
```

This is genuine component composition.

In that respect Backpack is considerably closer to your desired semantics than Dune.

But again, somebody must state the composition.

Backpack doesn't inherently perform:

```text
for every module marked traceable:
    wrap module in logger
```

That would require another metaprogram.

---

## Your SML approach

For explicit wrappers:

```sml
fun debugStore store =
    Build.apply LogStore store

fun debugParser parser =
    Build.apply LogParser parser

fun debugSolver solver =
    Build.apply LogSolver solver
```

Then:

```sml
fun debugVersion
    {store, parser, solver} =
    { store  = debugStore store,
      parser = debugParser parser,
      solver = debugSolver solver }
```

More interestingly, if your build API supports compiler-aware traversal:

```sml
fun instrument m =
    case Build.interface m of

        SOME StoreSig =>
            SOME (Build.apply LogStore m)

      | SOME ParserSig =>
            SOME (Build.apply LogParser m)

      | SOME SolverSig =>
            SOME (Build.apply LogSolver m)

      | _ =>
            NONE
```

then:

```sml
val debug =
    Build.transform instrument release
```

That is something neither ordinary Dune nor Backpack really gives you.

There is an important caveat here: a **completely generic logger** around arbitrary module signatures requires either reflection over signatures or compiler-generated wrappers.

If you want to transform:

```sml
signature X =
sig
    val foo : int -> string
    val bar : t -> unit
end
```

automatically into something that logs every call, the build API needs to understand the elaborated signature and synthesize something equivalent to:

```sml
structure LoggedX : X =
struct
    fun foo x =
        (Log.call "foo";
         X.foo x)

    fun bar x =
        (Log.call "bar";
         X.bar x)
end
```

That is beyond ordinary SML functor composition. It becomes compiler-supported **module reflection/transformation**.

That might actually be a worthwhile feature for Rune.

---

# 6. Example C: platform substitution

This is probably Backpack and Dune's strongest case.

Suppose the program needs:

```text
Filesystem
Clock
Networking
```

with Linux and Windows implementations.

## Dune

Virtual libraries fit very naturally:

```text
filesystem
    virtual Filesystem

filesystem_linux
    implements filesystem

filesystem_windows
    implements filesystem
```

Similarly for clock/networking.

Then your Linux final program links:

```lisp
(executable
 (name app_linux)
 (libraries
   application
   filesystem_linux
   clock_linux
   networking_linux))
```

and Windows:

```lisp
(executable
 (name app_windows)
 (libraries
   application
   filesystem_windows
   clock_windows
   networking_windows))
```

Dune can additionally make stanzas conditional on platform variables.

For a relatively fixed set of platform choices, this is excellent.

It's simple, visible, analyzable, and easy to cache.

---

## Backpack

This is almost the textbook Backpack use case.

Application:

```text
requires:
    Filesystem
    Clock
    Network
```

Linux instantiation:

```text
Application[
    Filesystem := Linux.Filesystem,
    Clock      := Linux.Clock,
    Network    := Linux.Network
]
```

Windows:

```text
Application[
    Filesystem := Windows.Filesystem,
    Clock      := Windows.Clock,
    Network    := Windows.Network
]
```

You could even package:

```text
LinuxPlatform
```

as the provider of all three.

From a module semantics perspective, this is very clean.

Backpack's signature checking ensures the replacement really satisfies the required interface.

---

## Your SML system

```sml
datatype platform =
    Linux
  | Windows
  | MacOS
```

Then:

```sml
fun filesystem Linux   = LinuxFilesystem
  | filesystem Windows = WindowsFilesystem
  | filesystem MacOS   = MacFilesystem

fun clock Linux   = LinuxClock
  | clock Windows = WindowsClock
  | clock MacOS   = MacClock

fun network Linux   = LinuxNetwork
  | network Windows = WindowsNetwork
  | network MacOS   = MacNetwork
```

and:

```sml
fun makePlatform p =
    Build.structure_
        [("Filesystem", filesystem p),
         ("Clock",      clock p),
         ("Network",    network p)]
```

followed by:

```sml
fun buildFor p =
    Build.apply ApplicationFn (makePlatform p)
```

All targets:

```sml
val builds =
    map buildFor
        [Linux, Windows, MacOS]
```

For only three platforms, this isn't dramatically better than Dune or Backpack.

The advantage appears as dimensions multiply:

```text
OS
× architecture
× word size
× runtime
× threading implementation
× GC
```

because in SML you naturally write functions describing dependencies between those dimensions rather than enumerate configurations.

For example:

```sml
fun gc (Linux, X86_64) =
      ParallelGC
  | gc (_, Wasm32) =
      SimpleGC
  | gc _ =
      CheneyGC
```

That's where a general-purpose meta-language begins pulling ahead.

---

# 7. Example D: Home / Pro / Enterprise

Suppose editions differ structurally:

```text
Home
    SQLite
    LocalAuth
    BasicReports
    SingleNode

Pro
    PostgreSQL
    LocalAuth
    AdvancedReports
    SingleNode

Enterprise
    PostgreSQL
    LDAP
    AdvancedReports
    Cluster
```

## Dune

Again virtual libraries can model the replacement points:

```text
database
auth
reports
cluster
```

Then the edition targets explicitly choose implementations:

```lisp
(executable
 (name product_home)
 (libraries
   application
   database_sqlite
   auth_local
   reports_basic
   cluster_single))
```

```lisp
(executable
 (name product_pro)
 (libraries
   application
   database_postgres
   auth_local
   reports_advanced
   cluster_single))
```

```lisp
(executable
 (name product_enterprise)
 (libraries
   application
   database_postgres
   auth_ldap
   reports_advanced
   cluster_distributed))
```

For exactly three fixed editions, this is arguably **better than arbitrary SML**.

Why?

Because anyone opening the build description immediately sees:

```text
Home → these four implementations
Pro → these four
Enterprise → these four
```

There is little abstraction hiding the graph.

This is an important advantage of declarative systems that shouldn't be dismissed.

---

## Backpack

The application requires:

```text
Database
Auth
Reports
Cluster
```

and you instantiate it three ways:

```text
Application[
    Database := SQLite,
    Auth     := LocalAuth,
    Reports  := BasicReports,
    Cluster  := SingleNode
]
```

```text
Application[
    Database := PostgreSQL,
    Auth     := LocalAuth,
    Reports  := AdvancedReports,
    Cluster  := SingleNode
]
```

```text
Application[
    Database := PostgreSQL,
    Auth     := LDAP,
    Reports  := AdvancedReports,
    Cluster  := DistributedCluster
]
```

This is probably the cleanest of the three if your only concern is **typed component substitution**.

Backpack is directly expressing the semantics you want.

---

## Your SML approach

```sml
datatype edition =
    Home
  | Pro
  | Enterprise
```

Then:

```sml
fun features Home =
      { database = SQLite,
        auth     = LocalAuth,
        reports  = BasicReports,
        cluster  = SingleNode }

  | features Pro =
      { database = PostgreSQL,
        auth     = LocalAuth,
        reports  = AdvancedReports,
        cluster  = SingleNode }

  | features Enterprise =
      { database = PostgreSQL,
        auth     = LDAP,
        reports  = AdvancedReports,
        cluster  = DistributedCluster }
```

and:

```sml
fun application edition =
    let
        val f = features edition

        val Features =
            Build.structure_
                [("Database", #database f),
                 ("Auth",     #auth f),
                 ("Reports",  #reports f),
                 ("Cluster",  #cluster f)]
    in
        Build.apply ApplicationFn Features
    end
```

For only three editions, this is not much shorter.

But now imagine:

```text
Home
Pro
Enterprise

× Linux
× Windows
× macOS

× debug
× release

× x86-64
× ARM64

× stable optimizer
× experimental optimizer
```

That's:

```text
3 × 3 × 2 × 2 × 2 = 72
```

potential products.

Dune and Backpack want you to describe configured objects.

SML lets you describe the **function that generates configured objects**.

That is the fundamental difference.

---

# 8. Combining all four examples is where your system wins

You can write:

```sml
type config =
    { platform  : platform,
      edition   : edition,
      mode      : mode,
      optimizer : optimizer }
```

Then:

```sml
fun makeProgram cfg =
    let
        val Platform =
            makePlatform (#platform cfg)

        val Features =
            makeFeatures (#edition cfg)

        val Compiler =
            optimizerModule (#optimizer cfg)

        val base =
            Build.apply
                ApplicationFn
                (Build.structure_
                    [("Platform",  Platform),
                     ("Features",  Features),
                     ("Compiler",  Compiler)])
    in
        case #mode cfg of
            Release => base
          | Debug   => instrument base
    end
```

Now your build matrix is merely:

```sml
val configurations =
    cartesian4
        platforms
        editions
        modes
        optimizers
```

and you can filter:

```sml
val supported =
    List.filter validCombination configurations
```

For example:

```sml
fun validCombination
    { platform = Windows,
      optimizer = ExperimentalARMOptimizer,
      ... } =
      false

  | validCombination _ =
      true
```

or derive one choice from another.

This is exactly where general-purpose computation becomes compelling.

---

# 9. The main weakness of your current proposal

If you literally expose arbitrary SML:

```sml
Build.source "x.sml"
```

while also allowing:

```sml
TextIO.openIn ...
OS.Process.system ...
Time.now ()
Random.rand ...
```

then you lose many of Dune's strongest properties.

Consider:

```sml
fun chooseBackend () =
    if fileExists "/some/random/file"
    then BackendA
    else BackendB
```

How does Rune know that `/some/random/file` is a build dependency?

Or:

```sml
if Time.now () > deadline
then CompilerA
else CompilerB
```

Now builds aren't reproducible.

Or:

```sml
while true do ()
```

Now graph construction doesn't terminate.

Dune avoids most of this because its graph description isn't an arbitrary effectful program.

---

# 10. I would therefore not choose “Dune vs embedded SML”

I would combine them.

Have SML as the **host language**, but make build construction occur through a controlled embedded DSL.

Something like:

```sml
structure Build :
sig
    type 'a t

    type module
    type executable

    val pure :
        'a -> 'a t

    val map :
        ('a -> 'b) ->
        'a t ->
        'b t

    val source :
        Path.t ->
        module t

    val target :
        Target.t ->
        Target.info t

    val env :
        string ->
        string option t

    val apply :
        module ->
        module ->
        module

    val compile :
        module ->
        executable t
end
```

The important division becomes:

```text
ordinary pure SML
    arbitrary computation
    map/fold/pattern matching/functions
              |
              v
      constructs Build values
              |
              v
     declarative build graph
              |
              v
       Rune build engine
```

So:

```sml
val configs =
    cartesian optimizers backends
```

is ordinary pure SML.

But filesystem observation must go through:

```sml
Build.source
Build.env
Build.target
```

rather than arbitrary `OS.FileSys`.

That lets the build engine record the dependency.

This is essentially:

> **Shake-style embedding with Dune-style graph semantics over Backpack-like typed module components.**

That combination is, I think, much stronger than simply making the whole unrestricted SML Basis Library available to build scripts.

---

# 11. You might even make graph construction applicative

There is a further subtle design choice.

If build descriptions use only an applicative interface:

```sml
val pure : 'a -> 'a build

val map2 :
    ('a * 'b -> 'c) ->
    'a build ->
    'b build ->
    'c build
```

then dependencies can often be discovered without executing earlier build results.

A monadic interface:

```sml
val bind :
    'a build ->
    ('a -> 'b build) ->
    'b build
```

allows later graph structure to depend on earlier results:

```sml
Build.bind detectCompiler
    (fn compiler =>
        if compiler = GCC
        then ...
        else ...)
```

which is more expressive but makes static dependency discovery harder.

This is exactly the same tension studied in modern build-system design:

```text
Applicative
    less expressive
    more static analysis

Monadic
    more expressive
    dynamic dependencies
```

For Rune, I'd probably support both but make the distinction visible.

---

# 12. The three systems occupy interestingly different positions

| | Dune | Backpack | Rune proposal |
|---|---|---|---|
| Main abstraction | targets/libraries | units/modules/signatures | modules + arbitrary SML computation |
| Language | declarative DSL | declarative module linking via Cabal/GHC | embedded SML |
| Typed module substitution | some, via OCaml + virtual libs | **central feature** | **central feature** |
| Module holes | virtual modules | signatures | signatures/functor parameters |
| Multiple instantiations | build configuration | first-class concept | computed freely |
| Higher-order build abstraction | limited | limited | ordinary SML functions |
| Graph transformation | limited | limited | natural |
| Variant Cartesian products | awkward | explicit | trivial |
| Static graph visibility | excellent | excellent | depends on design |
| Incremental build reasoning | excellent | excellent | must be designed |
| Generic instrumentation | PPX helps | difficult | natural with compiler support |
| Reproducibility | strong | strong | must restrict effects |

My conclusion for Rune would therefore be slightly different from “use SML instead of Dune/Backpack.”

I would aim for:

```text
                  Rune build system

          SML as meta-programming language
                       |
          +------------+-------------+
          |                          |
     pure functions              controlled
     over configs                build API
          |                          |
          +------------+-------------+
                       |
              typed module graph
                       |
             Backpack-like holes
             and instantiation
                       |
               Dune-like engine
                       |
        dependency analysis / caching
        incremental builds / sandbox
        parallelism / cross compilation
```

That preserves the two really strong ideas from the existing systems: **Backpack's explicit typed substitution** and **Dune's declarative, inspectable build DAG**, while adding the feature neither really provides: **higher-order computation over the space of module configurations**.

For the particular Rune use case of building dozens of compiler configurations and then systematically running differential correctness tests and benchmarks across them, that last capability is not cosmetic. It is the part that turns the build description into a programmable experimental framework rather than a collection of named targets.
