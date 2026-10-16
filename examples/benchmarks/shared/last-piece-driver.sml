functor BenchLastPieceDriverFn (K : sig
  type tree
  val solve : int -> tree
  val render : tree -> (string -> unit) -> int
end) =
struct
  structure Check = LastPieceCheckFn (K)
  fun run [argument, reference] =
    let val n = BenchInput.between (0, 13) (BenchInput.integer argument)
        val (solutions, bytes) = Check.run n reference
    in Int.toString n ^ ":" ^ Int.toString solutions ^ ":" ^ Int.toString bytes end
    | run _ = raise Fail "Last Piece expects remaining-piece count and complete output reference"
end
