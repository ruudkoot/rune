(* Finite memoized or strict list spines/heads for source-faithful ports. *)
functor BenchCellSequenceFn (D : BENCH_SUSPEND) =
struct
  datatype 'a node = Nil | Cons of 'a D.t * 'a node D.t
  type 'a sequence = 'a node D.t
  fun value x = D.delay(fn () => x)
  fun empty () = D.delay(fn () => Nil)
  fun cons x xs = D.delay(fn () => Cons(x,xs))
  fun fromList xs = D.delay(fn () => case xs of [] => Nil | x::rest => Cons(value x,fromList rest))
  fun head xs = case D.force xs of Nil => raise Empty | Cons(x,_) => D.force x
  fun tail xs = case D.force xs of Nil => raise Empty | Cons(_,rest) => rest
  fun delayedTail xs = D.delay(fn () => D.force(tail xs))
  fun fromCell cell = D.delay(fn () => D.force(D.force cell))
  fun map f xs = D.delay(fn () => case D.force xs of Nil => Nil
    | Cons(x,rest) => Cons(D.delay(fn () => f(D.force x)),map f rest))
  fun append xs ys = D.delay(fn () => case D.force xs of Nil => D.force ys
    | Cons(x,rest) => Cons(x,append rest ys))
  fun take 0 _ = empty()
    | take n xs = D.delay(fn () => case D.force xs of Nil => Nil
        | Cons(x,rest) => Cons(x,take(n-1)rest))
  fun replicate 0 _ = empty()
    | replicate n x = D.delay(fn () => Cons(x,replicate(n-1)x))
  fun init xs = D.delay(fn () => case D.force xs of Nil => raise Empty
    | Cons(x,rest) => case D.force rest of Nil => Nil | _ => Cons(x,init rest))
  fun zipWith3 f xs ys zs = D.delay(fn () => case D.force xs of Nil => Nil
    | Cons(x,xr) => case D.force ys of Nil => Nil
      | Cons(y,yr) => case D.force zs of Nil => Nil
        | Cons(z,zr) => Cons(D.delay(fn () => f(D.force x,D.force y,D.force z)),zipWith3 f xr yr zr))
  fun zip3 xs ys zs = D.delay(fn () => case D.force xs of Nil => Nil
    | Cons(x,xr) => case D.force ys of Nil => Nil
      | Cons(y,yr) => case D.force zs of Nil => Nil
        | Cons(z,zr) => Cons(D.delay(fn () => (x,y,z)),zip3 xr yr zr))
  fun equal eq xs ys = case D.force xs of Nil => (case D.force ys of Nil => true | _ => false)
    | Cons(x,xr) => case D.force ys of Nil => false
      | Cons(y,yr) => eq(D.force x,D.force y) andalso equal eq xr yr
  fun toList xs = case D.force xs of Nil => [] | Cons(x,rest) => D.force x :: toList rest
end
