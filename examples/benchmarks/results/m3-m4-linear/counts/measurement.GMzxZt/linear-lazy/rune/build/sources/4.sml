(* Memoized call-by-need list heads and spines for translated Haskell streams. *)
structure BenchStream =
struct
  datatype 'a node = Nil | Cons of 'a BenchLazy.delay * 'a node BenchLazy.delay
  type 'a stream = 'a node BenchLazy.delay
  fun empty () = BenchLazy.delay (fn () => Nil)
  fun cons (head, tail) = BenchLazy.delay (fn () => Cons (head, tail))
  fun singleton x = cons (BenchLazy.delay (fn () => x), empty ())
  fun fix make =
    let val holder = ref NONE
        val root = BenchLazy.delay (fn () => make (valOf (!holder)))
        val _ = holder := SOME root
    in root end
  fun head xs = case BenchLazy.force xs of
      Nil => raise Empty
    | Cons (x, _) => BenchLazy.force x
  fun tail xs = case BenchLazy.force xs of Nil => raise Empty | Cons (_, rest) => rest
  fun iterate f x =
    cons (x, BenchLazy.delay (fn () => BenchLazy.force
      (iterate f (BenchLazy.delay (fn () => f (BenchLazy.force x))))))
  fun fromList xs = BenchLazy.delay (fn () => case xs of [] => Nil
    | x::rest => Cons (BenchLazy.delay (fn () => x), fromList rest))
  fun map f xs = BenchLazy.delay (fn () => case BenchLazy.force xs of Nil => Nil
    | Cons (x, rest) => Cons (BenchLazy.delay (fn () => f (BenchLazy.force x)), map f rest))
  fun zipWith f xs ys = BenchLazy.delay (fn () => case BenchLazy.force xs of Nil => Nil
    | Cons (x, xr) => case BenchLazy.force ys of Nil => Nil
      | Cons (y, yr) => Cons (BenchLazy.delay (fn () => f (BenchLazy.force x, BenchLazy.force y)), zipWith f xr yr))
  fun append xs ys = BenchLazy.delay (fn () => case BenchLazy.force xs of Nil => BenchLazy.force ys
    | Cons (x, rest) => Cons (x, append rest ys))
  fun concatMap f xs = BenchLazy.delay (fn () => case BenchLazy.force xs of Nil => Nil
    | Cons (x, rest) => BenchLazy.force (append (f (BenchLazy.force x)) (concatMap f rest)))
  fun filter p xs = BenchLazy.delay (fn () => case BenchLazy.force xs of Nil => Nil
    | Cons (x, rest) => if p (BenchLazy.force x) then Cons(x,filter p rest)
      else BenchLazy.force(filter p rest))
  fun dropWhile p xs = BenchLazy.delay (fn () => case BenchLazy.force xs of Nil => Nil
    | Cons (x,rest) => if p(BenchLazy.force x) then BenchLazy.force(dropWhile p rest)
      else Cons(x,rest))
  fun foldrStream f base xs = BenchLazy.delay (fn () => case BenchLazy.force xs of Nil => BenchLazy.force base
    | Cons(x,rest) => BenchLazy.force(f(BenchLazy.force x,foldrStream f base rest)))
  fun zipWith3 f xs ys zs = BenchLazy.delay (fn () => case BenchLazy.force xs of Nil => Nil
    | Cons(x,xr) => case BenchLazy.force ys of Nil => Nil
      | Cons(y,yr) => case BenchLazy.force zs of Nil => Nil
        | Cons(z,zr) => Cons(BenchLazy.delay(fn()=>f(BenchLazy.force x,BenchLazy.force y,BenchLazy.force z)),zipWith3 f xr yr zr))
  fun span p xs =
    let val split=BenchLazy.delay(fn()=>case BenchLazy.force xs of Nil=>(empty(),empty())
          | Cons(x,rest)=>if p(BenchLazy.force x) then
              let val(prefix,suffix)=span p rest in (cons(x,prefix),suffix)end
            else (empty(),xs))
    in (BenchLazy.delay(fn()=>BenchLazy.force(#1(BenchLazy.force split))),
        BenchLazy.delay(fn()=>BenchLazy.force(#2(BenchLazy.force split))))end
  fun nth xs n = if n < 0 then raise Subscript else
    case BenchLazy.force xs of Nil => raise Subscript
    | Cons (x, rest) => if n=0 then BenchLazy.force x else nth rest (n-1)
  fun take 0 _ = []
    | take n xs = if n < 0 then raise Size else case BenchLazy.force xs of Nil => []
      | Cons (x, rest) => BenchLazy.force x :: take (n-1) rest
  fun foldl f init xs = case BenchLazy.force xs of Nil => init
    | Cons (x, rest) => foldl f (f (BenchLazy.force x, init)) rest
  fun foldPrefix f init 0 _ = init
    | foldPrefix f init n xs = case BenchLazy.force xs of Nil => raise Subscript
      | Cons (x, rest) => foldPrefix f (f (BenchLazy.force x, init)) (n-1) rest
end
