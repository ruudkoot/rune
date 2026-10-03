- haskell 98 frontend
- additional opcodes or new bytecode (benchmark)
- small heap-layout changed
- garbage collection is trickier:
    - Marlow and Peyton Jones tried local heaps for GHC (ISMM 2011), and GHC didn't adopt them. Its minor collections still stop every core.
- lazy ml language extensions
- is lazy code required to be effect free?
    - A thread takes no lock when it starts a thunk. Thunks are marked "being evaluated" (blackholed) only when the thread pauses, with one compare-and-swap per pending thunk (ThreadPaused.c:337).
    - Until then, two cores can evaluate the same thunk at once. GHC accepts the duplicated work instead of synchronising (Harris, Marlow and Peyton Jones 2005).

---

## Laziness on multicore and NUMA machines (Claude, 2026-09-28)

Checked against GHC's runtime under `/home/ruud/reference/ghc` (the paths below are relative to it). The heap-layout side is in `heap-layout.md`, *A lazy front end*.

**In short:** on one thread, laziness adds no locks, atomics or fences. The costs appear only when an *unevaluated* thunk is shared between threads running in parallel, because a thunk is a hidden mutable cell that is written once. Once evaluated, lazy data is immutable and shares across cores as well as strict data does. Haskell 98 has no threads (concurrency is an extension), so a Haskell 98 front end alone never shares a thunk between cores. The question arises when Rune's green threads share lazy data.

**What sharing thunks costs, cheapest first:**
- **Memory ordering (cheap).**
    - An update is a release-store of the value and of the new header. A read through an indirection is an acquire-load (`rts/include/stg/SMP.h`, Note [Heap memory barriers]; `rts/Updates.h:495-496`).
    - These are plain moves on x86 and `stlr`/`ldar` on aarch64, with no full fence. Rune's aarch64 JIT (jit M12) would emit them at every force and update.
- **Who evaluates a shared thunk (moderate).**
    - There is no lock or atomic on entry. A thread's pending thunks are blackholed only when it pauses, with one compare-and-swap each (`rts/ThreadPaused.c:337`).
    - Until then, two cores may evaluate the same thunk, and GHC accepts the duplicated work (Harris, Marlow and Peyton Jones 2005).
- **Waiting for a thunk another core is evaluating (a real synchronisation point).**
    - The waiting thread sends a message to the owner's core, which takes that core's lock (`rts/Messages.c`, `sendMessage`). The update wakes it.
    - The lock is per core, not global. But this is traffic a strict program does not have, because a strict producer finishes before it publishes.
- **The collector (the part that scales badly).**
    - **Generational:** an update of an old thunk is an old-to-young pointer and a remembered-set entry (`rts/Updates.h:485-489`). GHC keeps these per core, so this is fine.
    - **Concurrent marking (the no-pause collector):** every update of an old thunk during marking pushes the thunk's free variables onto the mark queue (`updateRemembSetPushThunk`, `rts/Updates.h:486-487`).
    - **Per-core local heaps** are what NUMA and high core counts want: a core collects its young objects without stopping the others.
        - They rely on the shared heap never pointing into a local one. Doligez and Leroy's rule: immutable objects may be copied, and mutable ones live in the shared heap.
        - A thunk is mutable. So updating a shared thunk with a value built locally first copies that value's reachable graph into the shared heap.
        - Marlow and Peyton Jones tried local heaps for GHC (2011). GHC did not adopt them, and its minor collections still stop every core.
    - **NUMA placement:** a thunk is evaluated where it is forced, not where it was made.
        - It lives in its creator's memory, the update writes it from another socket, and the value lives in the forcer's memory.
        - Placement follows demand, which is harder to predict than a strict producer and consumer.
    - **False sharing:** thunks that one thread allocated side by side, and that different threads force, share cache lines. This is second order.

**Effects in lazy code** (the question above, "is lazy code required to be effect free?"): duplicate evaluation is harmless only because a pure thunk gives the same answer twice.
- **What GHC does for effects.**
    - `unsafePerformIO` runs `noDuplicate#` first (`libraries/ghc-internal/src/GHC/Internal/IO/Unsafe.hs:127`).
    - That calls `threadPaused` to claim every thunk under evaluation on the thread's stack: a stack walk and a compare-and-swap per thunk, skipped when only one core runs (`rts/PrimOps.cmm`, `stg_noDuplicatezh`).
    - `unsafeDupablePerformIO` omits this. It warns that the action "may be performed multiple times (on a multiprocessor)" and may even be run partially.
- **For a lazy ML extension whose suspensions may have effects,** one of these must hold:
    - Lazy code is effect-free, checked by the type system or an effect analysis, so duplication stays harmless.
    - Suspensions with effects are claimed at entry by a compare-and-swap. That is the cost GHC avoids for pure thunks, paid on every force of such a suspension when it is shared.
    - Suspensions are never shared between threads (below), so neither question arises.

**For Rune:**
- **Cheapest: thunks confined to one thread or process.**
    - With the isolated processes of `~/notes/virtual-machine.md` (per-process heaps, messages copied), laziness costs no synchronisation, and effects in thunks are as safe as on a single thread.
    - What must be decided is what sending an unevaluated value means. It can be forced to normal form before the copy (then an infinite list cannot be sent, and a send can diverge). Or the thunk can be copied (its work and free variables are duplicated, and its effects run twice).
- **If lazy data is shared:** GHC's protocol is the proven one (no lock at entry, blackholing when a thread pauses, release/acquire, per-core messages). Its price is paid in the collector: promotion on update into the shared heap, and the pushes of the marking barrier.
- **The layout allows either.**
    - With young and old (or local and shared) told apart by address (heap-layout D7), "is this thunk shared?" is a range test, with no header bit.
    - `K_THUNK`'s state field (reserved in heap-layout M5) holds a claimed state, like GHC's WHITEHOLE.
    - A compare-and-swap of the header is the claim.
- **Where this belongs:** in the threading and collector roadmaps (heap-layout.md, D8 and *Prerequisites and flags*), neither of which exists yet.

**References:**
- Harris, Marlow and Peyton Jones. "Haskell on a shared-memory multiprocessor." Haskell Workshop 2005. doi:10.1145/1088348.1088354
- Marlow and Peyton Jones. "Multicore garbage collection with local heaps." ISMM 2011. doi:10.1145/1993478.1993482
- Doligez and Leroy. "A concurrent, generational garbage collector for a multithreaded implementation of ML." POPL 1993. doi:10.1145/158511.158611

---

## Java on the proposed heap layout (Claude, 2026-09-28)

The owner asked whether Rune could support Java with the layout `heap-layout.md` proposes. Checked against that roadmap's decisions and HotSpot under `/home/ruud/reference/java/jdk` (the HotSpot paths below are relative to it).

**In short:** mostly yes, on 64-bit machines. Java's objects fit the layout well. The trouble is in the frames: under self-describing slots (D5 A) and 63-bit integers (D2 B), a `long` or `double` in a slot is boxed or encoded, and on 32-bit machines an `int` is too. The header must also carry three things the roadmap left out because SML has none of them: a class, an identity-hash state and a lock state.

**What fits as decided:**
- **Raw typed fields (D1 B).** Java suits them better than SML does. Every Java field has a static type, and generics are erased to boxed `Integer` and `Long` objects, so no primitive value sits at a polymorphic position. Every primitive field can be raw, and every reference is a pointer word.
- **`null`.** The word already has one: 0 is a pointer (the M4 prototype's `vm/value.h`).
- **`int` on 64-bit machines.** Any 32-bit value is a 63-bit immediate. Java's wrap-around arithmetic is a question for the bytecode's instructions, not the layout.
- **The rest:**
    - the bump allocation (D6);
    - the single store operation where M7's barrier goes (Java writes to old objects constantly);
    - the pin bit (D9);
    - M8's flat arrays, though Java also needs 2- and 4-byte elements (`char[]`, `short[]`, `int[]`, `float[]`), not only bytes and reals.
- **Headerless pairs (D4 C)** give Java nothing and cost it nothing. Every Java object needs a header, so its pointers use code 00.

**What the header must carry.** The roadmap spends these bits on the collectors (*What is different for SML*: "No identity hash, no locks, no finalisers"; D8: "no lock word, no identity hash"). Java needs, in every object:
- **Its class,** for dispatch, `instanceof`, casts, `getClass` and the pointer map.
    - That is a class index into a table: the per-program layout table (D4 D), on 64-bit machines too.
    - The table grows as classes load at run time, not only per compiled unit.
    - HotSpot's compact header gives the class 22 bits (`src/hotspot/share/oops/markWord.hpp:50`).
- **An identity-hash state:** unhashed, hashed or hashed-and-moved, in two bits (Bacon, Fink and Grove 2002, section 3.3).
    - The hash is the address. When the copier moves a hashed object, it appends the old address as an extra word.
    - In their measurements no benchmark took the default hash of more than 1.3% of its objects, so the extra word is rare.
- **A lock state:** two bits. HotSpot keeps fast locks on a per-thread lock stack and contended ones in a side table (`src/hotspot/share/runtime/lockStack.hpp`, `objectMonitorTable.hpp`; the states at `markWord.hpp:52-58`).

**How that fits D4's headers:**
- **64-bit machines (A).** After the kind (4 bits) and the collectors' bits (4), 56 bits are left. Java's kinds may cut them their own way:
    - **an object:** class (24 bits), size in words (24), hash (2), lock (2), four spare. `obj_size` still comes from the header alone.
    - **an array:** an element code (a primitive type or a reference), hash, lock, and for a reference array the element class. A 31-bit length does not fit beside a 22-bit class, so the length takes the word after the header, as in HotSpot (`src/hotspot/share/oops/arrayOop.hpp:85-88`).
- **32-bit machines (B with D).** The 12-bit layout index (4,096 entries) is too small: `java.base` alone has 3,119 source files, before nested classes are counted. Java's kinds would:
    - give 22 bits to the class and 2 to the hash state;
    - take an object's size from the table, and every array's length from the word after the header;
    - keep the lock state in the side table alone, a lookup at every `monitorenter`.
- **The kind budget is nearly full.** The M4 prototype uses 11 of the 15 kind values (`vm/value.h`, `enum ObjKind`), and the lazy front end reserves `K_THUNK` and `K_IND`. Java's object and array would take the last two, before M8 adds any compact kinds.

**The real conflict: slots.**
- **`long`.** Under D2 B a Java `long` is an `Int64`, and under D5 A an `Int64` is boxed wherever it crosses a slot: an argument, a result, a frame of either interpreter.
    - That is the SplitMix note under D2, applied to every `long` in every Java frame.
    - A's switch helps only the longs that fit 63 bits. Hashes, random numbers and the `Long.MIN_VALUE` sentinel do not.
- **`double`.** Under D3 C an interpreter slot holds Koka's encoding, so every slot write is an encode and every read a decode. A double outside [2^-510, 2^512) is boxed, and that includes `Double.MAX_VALUE`, the common starting value of a minimum search.
- **Way out 1: two slots.** The JVM already gives each `long` and `double` two local variables and two units of operand stack (JVMS 2.6.1, 2.6.2).
    - If each slot holds 32 bits as an immediate, nothing is boxed or encoded, every bit survives, and D5 A holds.
    - The interpreter pays a shift and an or to join the halves, and a shift and a mask to split them.
    - The JIT keeps the value whole in a register and splits it at safepoints, where jit M9's write-back already runs.
- **Way out 2: maps.** Class files carry the verifier's types (the `StackMapTable`, JVMS 4.7.4, which the verifier has required since Java 7, class file version 51).
    - One linear pass gives a map at every safepoint.
    - *The architecture* already routes roots through the interface, "whether they are the tagged slots or a map".
    - But *A lazy front end* asks any new loop to keep D5 A, and Java would be the first exception.
- **32-bit machines and wasm32.** The immediate is 31 bits. A Java `int` does not fit (half of all hash codes lie outside it), and neither does a 32-bit half. Only maps work there.

**Beyond the layout:**
- **Threads.** Java shares memory: any object may be published to any thread.
    - That settles D8's open question for Java code: a shared old space (OCaml 5, GHC), not per-process heaps.
    - Java objects cannot be copied between heaps either, since all of them are mutable and have identity.
    - Java's virtual threads (JEP 444) do match the millions of green threads in `~/notes/virtual-machine.md`.
    - A volatile `long` on a 32-bit machine needs 64-bit atomics (JLS 17.7).
- **The collector.** Weak, soft and phantom references and finalisers need a hook on the referent field, keyed by a flag in the class table, as HotSpot's `InstanceRefKlass` does (`src/hotspot/share/oops/instanceRefKlass.hpp`).
- **The heap is the smaller job.** The class library (its native methods, `Unsafe`), loading classes at run time, reflection and `invokedynamic` would cost far more.

**For Rune, if Java is a real goal:**
- **At M5:** reserve two kinds for Java, and let a kind cut the header's 56 bits its own way.
- **At M4:** benchmark a `long` and `double` kernel under D5 A, the two-slot scheme and maps (D5 B).
- **D's index:** size it at 22 bits or more wherever it is built.
- **Where this belongs:** in `heap-layout.md` (D4, D5, M4, M5) if the owner takes it up, and in the threading and collector roadmaps (D8), which do not exist yet.

**References:**
- Bacon, Fink and Grove. "Space- and time-efficient implementation of the Java object model." ECOOP 2002. doi:10.1007/3-540-47993-7_5 (`/home/ruud/reference/papers/Bacon02Space.pdf`)
- Lindholm, Yellin, Bracha, Buckley and Smith. *The Java Virtual Machine Specification*, Java SE 21 edition: sections 2.6.1, 2.6.2 and 4.7.4.
- Gosling, Joy, Steele, Bracha, Buckley, Smith and Bierman. *The Java Language Specification*, Java SE 21 edition: section 17.7.
- JEP 444, Virtual Threads (JDK 21). JEP 450, Compact Object Headers (JDK 24); `UseCompactObjectHeaders` defaults to true in the reference tree (`src/hotspot/share/runtime/globals.hpp:131`).
