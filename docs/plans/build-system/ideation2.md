i think dependecy injections is a very powerful technique to build testable, observable and composable software. how can i make optimal use of it in rune (higher-order functors) and rune's build system (the one we discussed in an earlier conversation

----

Yes. For Rune, dependency injection should be a core composition discipline, not primarily a runtime container.

The optimal split is:

| Concern | Best Rune mechanism |
|---|---|
| Implementation dependencies | Structures and functors |
| Reusable component construction | Higher-order functors |
| Runtime-selected plugins | First-class modules or records |
| Request-specific values | Ordinary function arguments or effects |
| Production/test/platform variants | Build-system substitution |
| Logging, tracing, clocks, randomness | Explicit capability modules |
| Whole-program instrumentation | Build-time `rewrite` |
| Dependency graph and validation | Typed build IR |

The central abstraction is:

\[
\text{component} : \text{Dependencies} \rightarrow \text{Component}
\]

A higher-order decorator is:

\[
(\text{Dependencies} \rightarrow \text{Component})
\rightarrow
(\text{Dependencies} \rightarrow \text{Component})
\]

That maps almost perfectly onto Rune’s higher-order functors.

## 1. Use functors as the primary dependency-injection mechanism

Define narrow capability signatures:

```sml
signature CLOCK =
sig
  type instant
  val now : unit -> instant
end

signature ORDER_STORE =
sig
  type id
  type order

  val load : id -> order option
  val save : order -> unit
end

signature TRACE =
sig
  val event : Event.t -> unit
  val span : string -> (unit -> 'a) -> 'a
end
```

Then define the dependencies of a component explicitly:

```sml
signature ORDER_DEPS =
sig
  structure Clock : CLOCK
  structure Store : ORDER_STORE
  structure Trace : TRACE
end
```

The component becomes a functor:

```sml
signature ORDER_SERVICE =
sig
  type id
  val submit : string -> id
end

functor MakeOrderService
  (D : ORDER_DEPS)
  : ORDER_SERVICE where type id = D.Store.id =
struct
  type id = D.Store.id

  fun submit description =
    D.Trace.span "order.submit" (fn () =>
      let
        val timestamp = D.Clock.now ()
        val order = (* construct order *)
        val id = D.Store.save order
        val _ = D.Trace.event (Event.OrderSubmitted id)
      in
        id
      end)
end
```

The implementation does not know whether it is using PostgreSQL, an in-memory store, a fake clock, or a recording tracer.

The important property is that the dependency contract is typed and visible. No string keys, reflection, global service locator, or hidden imports are required.

## 2. Keep dependency bundles narrow

Avoid passing one enormous `World` structure to every component:

```sml
structure World =
struct
  structure Database = ...
  structure Filesystem = ...
  structure Network = ...
  structure Clock = ...
  structure Logger = ...
  structure Metrics = ...
  structure Random = ...
  structure Scheduler = ...
end
```

That makes every component appear to depend on everything.

Instead, define bounded dependency signatures:

```sml
signature ORDER_DEPS =
sig
  structure Clock : CLOCK
  structure Store : ORDER_STORE
  structure Trace : TRACE
end

signature IMAGE_DEPS =
sig
  structure Files : FILES
  structure Trace : TRACE
end
```

A root assembly module may construct a common runtime, but components should receive only projections of it.

This also gives Rune a useful architectural check: a component’s module signature becomes its dependency declaration.

## 3. Make higher-order functors the decorator and composition system

A normal component factory has the form:

```sml
ORDER_DEPS -> ORDER_SERVICE
```

Define that explicitly as a functor signature:

```sml
signature ORDER_FACTORY =
  functor (D : ORDER_DEPS) ->
    ORDER_SERVICE where type id = D.Store.id
```

A decorator is then a higher-order functor:

```sml
signature ORDER_DECORATOR =
  functor (F : ORDER_FACTORY) -> ORDER_FACTORY
```

For example:

```sml
functor WithTracing
  (F : ORDER_FACTORY)
  : ORDER_FACTORY =
  functor (D : ORDER_DEPS) =
  struct
    structure Base = F(D)

    type id = Base.id

    fun submit description =
      D.Trace.span "decorated.submit" (fn () =>
        Base.submit description)
  end
```

A decorator that has its own dependency can be parameterized too:

```sml
functor WithCache
  (C : CACHE)
  (F : ORDER_FACTORY)
  : ORDER_FACTORY =
  functor (D : ORDER_DEPS) =
  struct
    structure Base = F(D)
    type id = Base.id

    (* cache around Base.submit *)
  end
```

Composition becomes ordinary module composition:

```sml
functor Compose
  (A : ORDER_DECORATOR)
  (B : ORDER_DECORATOR)
  : ORDER_DECORATOR =
  functor (F : ORDER_FACTORY) =
    A(B(F))
```

Then an application can be assembled as:

```sml
structure Factory =
  WithMetrics(
    WithTracing(
      WithRetry(
        MakeOrderService)))

structure Orders =
  Factory(ProductionDeps)
```

This gives Rune a principled way to express:

- tracing;
- metrics;
- caching;
- retries;
- authorization;
- transactions;
- fault injection;
- profiling;
- memoization;
- audit logging;
- resource management.

The decorators are independently reusable and can be reordered by the build system.

## 4. Separate three kinds of dependencies

Not every dependency should become a module.

### Static implementation dependencies

Use modules and functors when the dependency determines:

- types;
- representation;
- algorithms;
- resource implementation;
- optimization opportunities;
- nominal identities.

Examples:

```sml
Store
Filesystem
Map implementation
Scheduler
Parser
Database backend
```

### Per-call data

Use ordinary function arguments for things that vary on each invocation:

```sml
submit : User.t * OrderRequest.t -> OrderId.t
```

Do not inject `User`, `OrderRequest`, or configuration values through modules.

### Dynamic contextual capabilities

Use explicit records, effects, or first-class modules when the implementation must change at runtime.

Examples:

- a plugin selected from a configuration file;
- a customer-specific backend;
- a dynamically loaded codec;
- a request-local tracing context;
- a runtime-selected payment provider.

Rune’s planned first-class modules—`pack`, `unpack`, and existential module packages—are appropriate here. They should not replace ordinary functor injection for statically known dependencies.

A good rule is:

> Modules select implementations. Values carry data. Effects carry dynamically scoped operations.

## 5. Treat observability as a first-class capability

Logging should not be scattered through application code as unstructured strings.

Define a typed event algebra:

```sml
datatype Event.t =
    OrderSubmitted of OrderId.t
  | OrderLoaded of OrderId.t
  | StoreFailure of Error.t
  | PaymentAttempted of PaymentId.t
```

Then inject a typed observer:

```sml
signature TRACE =
sig
  val event : Event.t -> unit
  val span : string -> (unit -> 'a) -> 'a
end
```

Different builds can provide different implementations:

```sml
structure NoTrace : TRACE = ...
structure RecordingTrace : TRACE = ...
structure ConsoleTrace : TRACE = ...
structure OpenTelemetryTrace : TRACE = ...
structure ReplayTrace : TRACE = ...
```

This gives you:

- assertions over emitted events;
- deterministic replay;
- production tracing;
- benchmark builds with tracing disabled;
- failure diagnosis;
- event-based integration tests.

The build system can also apply cross-cutting instrumentation using `Build.rewrite`. The distinction should be:

- decorator functors for typed, local, architectural instrumentation;
- `rewrite` for broad compiler-level instrumentation;
- ordinary injected `Trace` modules for runtime observation.

## 6. Inject determinism explicitly

For serious testing, inject more than a database mock:

```sml
signature RANDOM =
sig
  val next_int : int -> int
end

signature SCHEDULER =
sig
  val yield : unit -> unit
  val sleep : Duration.t -> unit
end
```

Useful test providers include:

```sml
FakeClock
SeededRandom
VirtualScheduler
InMemoryStore
RecordingTrace
FailingStore
LatencyInjectingStore
```

This lets Rune test:

- timeouts;
- retries;
- race conditions;
- backoff;
- random algorithms;
- failure recovery;
- event ordering;
- distributed-style behaviour.

For concurrent systems, a deterministic scheduler is often more valuable than a mock database.

## 7. Make the build system a typed dependency-injection assembler

The Rune build language should act as a typed module linker and variant generator.

The earlier `Build.source`, `Build.apply`, `Build.seal`, `Build.replace`, `Build.rewrite`, `Build.test`, and `Build.benchmark` primitives are a good foundation. I would add thin abstractions such as:

```sml
Build.require
Build.provide
Build.resolve
Build.profile
Build.share
Build.contract
```

A production build might look conceptually like:

```sml
val base =
  Build.source "orders/service.rune"

val observed =
  Build.apply
    (Build.source "infra/with-tracing.rune")
    base
  |> Build.apply
    (Build.source "infra/with-metrics.rune")

val productionDeps =
  Build.structure {
    Clock  = Build.source "platform/posix-clock.rune",
    Store  = Build.source "database/sql-store.rune",
    Trace  = Build.source "observability/otlp-trace.rune"
  }

val production =
  Build.apply observed productionDeps
```

The test build reuses exactly the same component graph:

```sml
val testDeps =
  Build.structure {
    Clock  = Build.source "test/fake-clock.rune",
    Store  = Build.source "test/memory-store.rune",
    Trace  = Build.source "test/recording-trace.rune"
  }

val test =
  Build.apply observed testDeps
```

A benchmark build might use:

```sml
val benchmarkDeps =
  Build.structure {
    Clock  = Build.source "test/fixed-clock.rune",
    Store  = Build.source "benchmark/null-store.rune",
    Trace  = Build.source "observability/no-trace.rune"
  }
```

The key is that these are different roots over the same typed component graph, not three independently maintained implementations.

## 8. Represent module requirements explicitly in the build IR

The build system should record more than source-file dependencies.

Each compiled module or component should export something like:

```text
provides:
  ORDER_SERVICE

requires:
  CLOCK
  ORDER_STORE
  TRACE

type equalities:
  ORDER_SERVICE.id = ORDER_STORE.id

capabilities:
  time
  persistent-storage
  observability

events:
  OrderSubmitted
  StoreFailure

optimization catalog:
  inline submit
  specialize Store.id
  fuse tracing wrapper
```

Most of the requirements can be inferred from the elaborated module signature. Explicit annotations are still useful for:

- opaque external libraries;
- security policies;
- effect/capability declarations;
- build-time platform constraints;
- documentation;
- plugin boundaries.

The resolver should then perform:

1. signature compatibility checking;
2. `where type` and sharing-constraint solving;
3. capability-policy checking;
4. cycle detection;
5. provider selection;
6. decorator application;
7. sealing;
8. caching and provenance recording.

This is essentially Backpack-style typed substitution combined with Dune-like graph construction, while retaining Rune’s programmable build language.

## 9. Use applicative and generative functors deliberately

Dependency injection makes module identity especially important.

Use applicative functors for shared production dependencies:

```sml
structure Runtime = MakeRuntime(ProductionConfig)

structure Orders   = MakeOrders(Runtime)
structure Payments = MakePayments(Runtime)
```

Both components can share the same type identities and provider definitions.

Do not independently apply the provider functor in several places:

```sml
structure Orders   = MakeOrders(MakeRuntime(Config))
structure Payments = MakePayments(MakeRuntime(Config))
```

That can duplicate state, initialization, bytecode, and nominal types.

The build system should therefore have an explicit sharing operation or preserve named module handles:

```sml
val runtime = Build.share (Build.apply makeRuntime config)
```

Use generative applications for:

- isolated test fixtures;
- fresh temporary stores;
- independent plugin instances;
- per-test nominal types;
- intentionally separate state.

This is one of the strongest reasons for Rune’s explicit distinction between applicative and generative module application.

## 10. Use dependency injection for provider contract testing

A particularly powerful pattern is to write tests against a signature rather than a specific implementation:

```sml
functor StoreContract
  (S : ORDER_STORE) =
struct
  (* tests for save/load consistency,
     missing values, overwrite behaviour, etc. *)
end
```

Then instantiate the same contract suite with:

```sml
structure _ = StoreContract(MemoryStore)
structure _ = StoreContract(SqlStore)
structure _ = StoreContract(RecordingStore)
```

The build system could expose this directly:

```sml
Build.contract
  { signature = ORDER_STORE
  , tests = Build.source "tests/store-contract.rune"
  , providers = [MemoryStore, SqlStore, RecordingStore]
  }
```

This avoids the classic failure mode where mocks satisfy the interface but behave differently from the real provider.

## 11. Add lifecycle and ownership to dependency metadata

Some injected dependencies are pure modules. Others own resources.

Rune should distinguish, either in signatures or build metadata:

```text
scope:
  pure
  shared
  per-instance
  per-request
  externally-owned
```

For example:

- `FakeClock`: pure or test-scoped;
- database pool: shared;
- transaction: per-request;
- request trace span: per-operation;
- temporary directory: owned by a fixture.

Resource interfaces should provide structured lifetime management:

```sml
signature RESOURCE =
sig
  type resource

  val acquire :
    Config.t -> resource

  val release :
    resource -> unit

  val using :
    resource -> (resource -> 'a) -> 'a
end
```

This prevents dependency injection from degenerating into uncontrolled global initialization.

## 12. Use build-time injection for optimization and platform selection

This fits especially well with your earlier Rune build-system proposal.

The same abstract dependency can have several implementations:

```text
MAP:
  generic-map
  integer-specialized-map
  string-specialized-map
  compact-map
  concurrent-map
```

The build system can select one based on:

- target architecture;
- key type;
- optimization profile;
- available runtime features;
- licensing or edition;
- trusted closed-world knowledge.

The application still depends on the abstract signature:

```sml
structure Map : MAP
```

The build resolver selects the implementation and can use its optimization catalog. This gives you specialization without exposing implementation choices throughout the source code.

## 13. Suggested Rune architecture

I would organize Rune’s DI story into four layers:

```text
Pure functions
    ↓
Component functors over narrow capability signatures
    ↓
Higher-order decorators and component factories
    ↓
Build-time root assembly and variant selection
```

Runtime first-class modules sit beside this architecture, only at boundaries where implementation choice is genuinely dynamic.

The most important design rules are:

- make dependencies explicit in functor parameters;
- keep signatures narrow;
- preserve type equalities with dependent functors and `where type`;
- use higher-order functors for decorators and composition;
- assemble providers once at the build root;
- use build-time typed substitution for profiles and platforms;
- use first-class modules only for runtime dynamism;
- inject clocks, randomness, schedulers, tracing, and fault models;
- test provider implementations with shared contract suites;
- treat observability as typed events rather than ad hoc logging;
- preserve module identity and sharing in the build graph.

The result is a system where the same Rune component can be instantiated as:

```text
production
debug
unit-test
integration-test
deterministic-simulation
benchmark
replay
fault-injection
platform-specific
```

without changing its application logic.

The earlier Rune design—higher-order dependent functors, explicit module identity, typed build IR, `replace`/`rewrite`, optimization catalogs, and programmable build scripts—is particularly well suited to this. The build system becomes a statically checked dependency-injection container, while the module system remains the mechanism that gives the injection its type safety and compositional structure.


----


do an adversarial review on the above to make sure you are not just saying things to pleas me

----


The previous answer was directionally sound, but it was too enthusiastic and conflated several distinct ideas. I would keep the architecture, but weaken several claims substantially.

## The main problem: four mechanisms were conflated

These are related but not identical:

| Problem | Best mechanism |
|---|---|
| Abstracting over implementation and types | Modules/functors |
| Supplying implementations | Explicit root wiring |
| Runtime variation | Records, effects, or first-class modules |
| Selecting build variants | Build-system configuration/linking |

Calling the build system a “dependency-injection container” is rhetorically appealing but technically misleading. Rune’s build system should primarily be a typed module linker and variant generator. It may perform dependency injection, but it should not behave like a general-purpose runtime container.

## What I would retain

The strongest part of the proposal is:

```text
component : Dependencies -> Component
decorator : (Dependencies -> Component)
          -> (Dependencies -> Component)
```

Higher-order functors are genuinely well suited to expressing:

- component factories;
- adapters;
- tracing wrappers;
- caches;
- retry policies;
- algorithm selection;
- platform-specific providers;
- test implementations;
- compiler or runtime families.

Rune’s richer module calculus, especially dependent functors and explicit type sharing, makes this more practical than in SML’97.

The build system should also be able to instantiate the same abstract component graph as:

```text
production
unit test
integration test
benchmark
replay
fault injection
platform-specific
```

That is a strong design.

## What was overstated

### 1. Functors should not be the default for every dependency

The previous answer implied that every effectful component should be parameterized by a module bundle. That can create excessive module plumbing.

For pure computation, ordinary functions are usually better:

```sml
val calculateTotal :
  Order.t * TaxPolicy.t -> Money.t
```

For a small behavioural dependency, a record of functions may be more convenient:

```sml
type clock =
  { now : unit -> Instant.t }
```

Functors are justified when the dependency involves:

- associated types;
- representation abstraction;
- compile-time specialization;
- a large coherent implementation;
- resource ownership;
- nominal type identity;
- multiple operations that must share invariants.

A useful Rune rule would be:

> Use functions for data and local behaviour, records for small runtime capabilities, functors for static implementation families and associated types.

Otherwise, “dependency injection” becomes ceremony.

### 2. A giant dependency signature is still a service locator in disguise

The previous answer warned against a giant `World`, but its `ORDER_DEPS` pattern can gradually become exactly that:

```sml
signature ORDER_DEPS =
sig
  structure Clock : CLOCK
  structure Store : STORE
  structure Trace : TRACE
  structure Random : RANDOM
  structure Scheduler : SCHEDULER
  ...
end
```

The important property is not whether the environment is a structure or a record. The important property is whether each component receives only what it actually needs.

Rune should support dependency projection or sub-signatures:

```sml
signature ORDER_DEPS =
sig
  structure Clock : CLOCK
  structure Store : ORDER_STORE
end
```

and separately:

```sml
signature OBSERVABLE_ORDER_DEPS =
sig
  include ORDER_DEPS
  structure Trace : TRACE
end
```

A compiler or build tool could check that a component does not access undeclared capabilities.

### 3. Higher-order decorators are not automatically composable

The previous answer presented decorators as if they compose cleanly:

```sml
A(B(F))
```

They do compose syntactically, but their semantics may not compose well.

Examples:

- retrying a transaction can duplicate side effects;
- caching before authorization differs from caching after authorization;
- tracing outside a retry records one span, while tracing inside records every attempt;
- metrics may count calls, attempts, successful results, or failures;
- transactions and resource scopes have ordering constraints.

Therefore Rune should not treat all decorators as interchangeable functions. It may need metadata such as:

```text
effects:
  may-retry
  observes-failure
  owns-resource

ordering:
  must-enclose transaction
  must-run-after authorization
```

At minimum, decorator composition should be explicit and order-sensitive. The build system should not automatically reorder decorators merely because their types match.

### 4. Some of the sample code was technically defective

The examples were illustrative, but several details were wrong or underspecified:

- `ORDER_STORE.save` was declared as returning `unit`, but the service used its result as an order ID.
- `WithTracing` duplicated tracing already performed inside `MakeOrderService`.
- `WithCache` did not specify how cache invalidation, concurrency, or failures work.
- The `ORDER_FACTORY` syntax is not SML’97 and depends on Rune’s proposed higher-order module syntax.
- `D.Trace.span : string -> (unit -> 'a) -> 'a` says nothing about exception recording, cancellation, asynchronous work, or tracing-context propagation.
- `Event.OrderSubmitted id` requires an explicit shared event and identifier type design.

These are not fatal problems, but the original response presented them too confidently.

### 5. Observability is more difficult than injecting a `Trace` module

Injecting tracing is useful, but this interface is too simplistic for serious systems:

```sml
val event : Event.t -> unit
val span : string -> (unit -> 'a) -> 'a
```

Questions it leaves unanswered:

- What happens if the tracer fails?
- Is event emission synchronous?
- Can it apply backpressure?
- How are trace IDs propagated across tasks?
- How are exceptions and cancellations represented?
- How are asynchronous spans closed?
- Is sampling controlled by the tracer or by the application?
- Are events domain events, diagnostic events, or telemetry records?

A better design separates at least:

```text
domain events
diagnostic logs
metrics
distributed traces
audit records
```

They may share context, but they should not necessarily share one interface.

Also, typed domain events can create unwanted coupling between application code and telemetry schema. For some systems, a generic structured logging interface is preferable.

### 6. Build-time “capability checking” is not automatically sound

The previous answer proposed build metadata such as:

```text
capabilities:
  time
  persistent-storage
  observability
```

This is useful, but the build system cannot reliably infer semantic capabilities merely from module signatures. A module can perform network I/O internally without its signature revealing that fact.

Therefore these annotations must be treated as:

- explicit declarations;
- compiler-enforced only where the compiler has evidence;
- potentially trusted metadata at package boundaries.

Do not imply that a build graph alone provides a security boundary. For security, Rune would need capabilities enforced by the runtime, OS, sandbox, or a verified effect system.

### 7. Lifecycle should not be primarily a build-system concern

The previous answer suggested metadata such as:

```text
scope:
  shared
  per-instance
  per-request
```

This is useful documentation, but the build system cannot enforce request lifetimes by itself.

A database pool, transaction, request context, and temporary file have runtime lifetimes. Correct handling may require:

- structured resource combinators;
- cancellation-aware cleanup;
- affine or linear types;
- regions;
- runtime ownership checks;
- explicit async finalization.

`RESOURCE.using` is a good API pattern, but it is not sufficient to guarantee safety in the presence of exceptions, cancellation, or concurrency.

### 8. First-class modules are not only for runtime-selected plugins

The previous answer restricted first-class modules mostly to runtime dynamism. They are also useful for:

- packaging heterogeneous implementations;
- existentially hiding associated types;
- passing module packages through generic data structures;
- plugin registries;
- staged systems where selection is delayed but still statically checked;
- representing multiple implementations in test infrastructure.

Conversely, many runtime-selection problems do not need first-class modules; a record of functions or an explicit object-like value may be simpler.

So the distinction should be based on whether associated types and module abstraction are needed, not merely whether selection occurs at runtime.

## The build-system recommendation needs to be more conservative

I would not begin with an automatic provider resolver:

```sml
Build.resolve {
  Clock = ...
  Store = ...
}
```

Automatic resolution creates difficult questions:

- What happens when two providers match?
- How are priorities chosen?
- Can resolution depend on target architecture?
- Is the result reproducible?
- Does adding a package silently change the selected provider?
- How are type equalities solved?
- How are cyclic provider dependencies diagnosed?
- How do users inspect the final graph?

The safer default is explicit root wiring:

```sml
val production =
  Build.apply serviceFactory productionDeps

val test =
  Build.apply serviceFactory testDeps
```

A `resolve` convenience layer could later be added, but it should elaborate into an explicit graph and produce a complete manifest showing every selected provider.

The build language should be:

- programmable enough to generate variants;
- explicit enough to inspect;
- deterministic;
- cacheable;
- reproducible;
- resistant to ambient hidden dependencies.

The previous answer was right to combine ideas from Dune and Backpack, but the division should be:

- Backpack-like typed module holes and substitutions;
- Dune-like explicit, cacheable build graphs;
- Rune computation for generating graph variants;
- explicit root assembly rather than magical runtime-style resolution.

## A more defensible Rune design

I would revise the proposal to this:

### Core Rune

Provide:

- ordinary functors;
- higher-order functors;
- functor signatures;
- dependent result signatures;
- `where type` and sharing constraints;
- transparent and opaque sealing;
- explicit module aliases;
- generative and applicative application;
- first-class modules later, at carefully defined boundaries.

Do not add a general DI framework to the language.

### Application architecture

Use:

```text
pure functions
  → small capability records
  → functors for static implementation families
  → higher-order functors for architectural composition
  → explicit root assembly
```

### Build system

Provide:

```text
Build.source
Build.apply
Build.seal
Build.replace
Build.rewrite
Build.profile
Build.share
Build.test
Build.benchmark
```

Add typed holes or requirements, but keep provider selection explicit initially.

The build system should record:

- required signatures;
- provided signatures;
- type-sharing constraints;
- target/profile;
- source provenance;
- selected implementation;
- compiler options;
- optimization decisions.

It should not pretend that all effects, security properties, or resource lifetimes are inferred automatically.

### Testing

Use several layers:

1. Pure-function tests.
2. Functor-level component tests with deterministic capabilities.
3. Provider contract tests.
4. Integration tests with real providers.
5. End-to-end tests with production-like wiring.

Dependency injection enables these tests, but does not replace property testing, model-based testing, race testing, or contract testing.

## Bottom line

The earlier answer was not merely flattery, but it did overstate the coherence and maturity of the design.

The genuinely strong conclusion is:

> Rune’s higher-order module system can provide excellent static dependency injection and reusable architectural composition.

The weaker or premature conclusions were:

- that functors should handle most dependencies;
- that the build system should behave like a DI container;
- that typed capability metadata is automatically enforceable;
- that decorators compose semantically without additional constraints;
- that injecting a trace module solves observability;
- that lifecycle scopes belong naturally in the build system.

I would pursue the idea, but with a deliberately small first version:

1. explicit functor parameters;
2. narrow capability signatures;
3. explicit root wiring;
4. higher-order decorators;
5. deterministic test providers;
6. typed build-graph manifests;
7. no automatic provider resolution initially;
8. no assumption that DI replaces effects, resource ownership, or concurrency testing.

That would give Rune the real benefits of dependency injection without turning the language and build system into an over-engineered framework.