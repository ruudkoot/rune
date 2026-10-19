structure BenchOcamlLazyTests =
struct
  structure P = BenchOcamlPrimes
  structure L = BenchLazy
  val demands = ref 0
  val stream = P.Cons(2,L.delay(fn () => (demands := !demands+1;
    P.Cons(3,L.delay(fn () => raise Fail "excess demand")))))
  val _ = T.check("ocaml-primes/take-forces-next-tail",fn () =>
    P.take 1 stream = [2] andalso !demands=1)
  val _ = T.check("ocaml-primes/tail-is-memoized",fn () =>
    P.head(P.tail stream)=3 andalso P.head(P.tail stream)=3 andalso !demands=1)
  val _ = T.check("ocaml-primes/removing-filter",fn () =>
    P.take 3 (P.filter(fn n => n mod 2=0)(P.from 2)) = [3,5,7])
  val _ = T.check("ocaml-primes/first-primes",fn () =>
    P.take 8 P.primes = [2,3,5,7,11,13,17,19])
  val list = BenchOcamlLazyList.create 4
  fun pending cell = case !cell of L.Pending _ => true | _ => false
  val _ = T.check("ocaml-list/unforced-heads",fn () =>
    List.length list=5 andalso List.all pending (List.take(list,4)))
  val _ = T.check("ocaml-list/heads-use-original-zero",fn () =>
    L.force(List.hd list)=1 andalso List.all pending (List.take(List.tl list,3)))
  val _ = T.check("ocaml-list/second-head-independent",fn () =>
    L.force(List.nth(list,1))=1 andalso List.all pending (List.take(List.drop(list,2),2)))
  val _ = T.check("ocaml-list/empty-extension",fn () =>
    BenchOcamlLazyList.consume(BenchOcamlLazyList.create 0)=(1,0))
end
