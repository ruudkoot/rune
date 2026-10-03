(* The old list remains unchanged: every new head refers to the same zero. *)
structure BenchOcamlLazyList =
struct
  fun addLazy list 0 = list
    | addLazy list n =
        let val newHead = BenchLazy.delay(fn () => 1+BenchLazy.force(List.hd list))
        in newHead :: addLazy list (n-1) end
  fun create n = addLazy [BenchLazy.delay(fn () => 0)] n
  fun consume list =
    let val length = List.length list
        val first = List.hd list
        val value = BenchLazy.force first
    in (length,value) end
end
