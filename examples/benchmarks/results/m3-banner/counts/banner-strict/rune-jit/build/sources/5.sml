signature BENCH_BANNER_SUSPEND =
sig
 include BENCH_SUSPEND
 val knot : ('a t -> 'a) -> 'a t
end
structure BenchBannerNeed : BENCH_BANNER_SUSPEND =
struct
 type 'a t='a BenchLazy.delay
 val delay=BenchLazy.delay
 val force=BenchLazy.force
 fun knot build=
   let val cell=ref(BenchLazy.Pending(fn()=>raise Fail "uninitialized banner knot"))
       val _=cell:=BenchLazy.Pending(fn()=>build cell)
   in cell end
end
structure BenchBannerStrict : BENCH_BANNER_SUSPEND =
struct
 type 'a t='a
 fun delay f=f()
 fun force x=x
 fun knot build=let fun loop()=build(loop())in loop()end
end
