signature BENCH_SUSPEND =
sig
  type 'a t
  val delay : (unit -> 'a) -> 'a t
  val force : 'a t -> 'a
end
structure BenchNeed : BENCH_SUSPEND =
struct
  type 'a t = 'a BenchLazy.delay
  val delay = BenchLazy.delay
  val force = BenchLazy.force
end
structure BenchStrict : BENCH_SUSPEND =
struct
  type 'a t = 'a
  fun delay f = f ()
  fun force x = x
end
