(* ListPair

   Implements: LIST_PAIR *)
structure ListPair =
struct
  exception UnequalLengths

  fun zip (x :: xs, y :: ys) = (x, y) :: zip (xs, ys)
    | zip _ = []

  fun zipEq (x :: xs, y :: ys) = (x, y) :: zipEq (xs, ys)
    | zipEq ([], []) = []
    | zipEq _ = raise UnequalLengths

  fun unzip [] = ([], [])
    | unzip ((x, y) :: rest) =
      let val (xs, ys) = unzip rest in (x :: xs, y :: ys) end

  fun app f (x :: xs, y :: ys) = (f (x, y); app f (xs, ys))
    | app f _ = ()

  fun appEq f (x :: xs, y :: ys) = (f (x, y); appEq f (xs, ys))
    | appEq f ([], []) = ()
    | appEq f _ = raise UnequalLengths

  fun map f (x :: xs, y :: ys) = f (x, y) :: map f (xs, ys)
    | map f _ = []

  fun mapEq f (x :: xs, y :: ys) = f (x, y) :: mapEq f (xs, ys)
    | mapEq f ([], []) = []
    | mapEq f _ = raise UnequalLengths

  fun foldl f init (x :: xs, y :: ys) = foldl f (f (x, y, init)) (xs, ys)
    | foldl f init _ = init

  fun foldr f init (x :: xs, y :: ys) = f (x, y, foldr f init (xs, ys))
    | foldr f init _ = init

  fun foldlEq f init (x :: xs, y :: ys) = foldlEq f (f (x, y, init)) (xs, ys)
    | foldlEq f init ([], []) = init
    | foldlEq f init _ = raise UnequalLengths

  fun foldrEq f init (x :: xs, y :: ys) = f (x, y, foldrEq f init (xs, ys))
    | foldrEq f init ([], []) = init
    | foldrEq f init _ = raise UnequalLengths

  fun exists p (x :: xs, y :: ys) = p (x, y) orelse exists p (xs, ys)
    | exists p _ = false

  fun all p (x :: xs, y :: ys) = p (x, y) andalso all p (xs, ys)
    | all p _ = true

  fun allEq p (x :: xs, y :: ys) = p (x, y) andalso allEq p (xs, ys)
    | allEq p ([], []) = true
    | allEq p _ = false
end
