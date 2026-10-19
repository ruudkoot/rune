structure BenchMandelDouble =
struct
  structure S = BenchStream
  structure L = BenchLazy
  structure I = IntInf
  fun add ((x : real, y : real), (a, b)) = (x + a, y + b)
  fun multiply ((x : real, y), (a, b)) = (x * a - y * b, x * b + y * a)
  fun generic c z = add (multiply (z, z), c)
  fun oldStep (cr, ci) (x, y) = ((x * x - y * y) + cr, 2.0 * (x * y) + ci)
  fun magnitude (x, y) =
    let fun exponent r = if Real.== (r, 0.0) then 0 else #exp (Real.toManExp r)
        val k = Int.max (exponent x, exponent y)
        val a = Real.fromManExp {man = x, exp = ~k}
        val b = Real.fromManExp {man = y, exp = ~k}
    in Real.fromManExp {man = Math.sqrt (a * a + b * b), exp = k} end
  fun orbit step c =
    let val f = fn z => step (L.force c) z
    in S.fix (fn root => S.Cons (c, S.map f root)) end
  fun take 0 _ = S.empty ()
    | take n xs = L.delay (fn () => case L.force xs of S.Nil => S.Nil
      | S.Cons (x, rest) => S.Cons (x, take (n - 1) rest))
  fun lazyNew step limit radius c =
    let fun walk xs = case L.force xs of S.Nil => 0
          | S.Cons (x, rest) => if magnitude (L.force x) > radius then 0 else 1 + walk rest
    in walk (take limit (orbit step c)) end
  fun lazyOld step limit (radiusSquared : real) c =
    let fun walk xs n = case L.force xs of S.Nil => raise Fail "empty Mandel orbit"
          | S.Cons (value, rest) =>
              let val (x, y) = L.force value
              in if radiusSquared <= x * x + y * y orelse n = 0 then 0
                 else 1 + walk rest (n - 1) end
    in walk (orbit step c) limit end
  fun prefix step _ 0 _ = []
    | prefix step c 1 z = [z]
    | prefix step c n z = z :: prefix step c (n - 1) (step c z)
  fun strictNew step limit radius c =
    let fun walk [] = 0
          | walk (z :: rest) = if magnitude z > radius then 0 else 1 + walk rest
    in walk (prefix step c limit c) end
  fun strictOld step limit (radiusSquared : real) c =
    let fun walk [] _ = raise Fail "empty old Mandel orbit"
          | walk ((x, y) :: rest) n =
              if radiusSquared <= x * x + y * y orelse n = 0 then 0 else 1 + walk rest (n - 1)
    in walk (prefix step c (limit + 1) c) limit end
  fun range first last = L.delay (fn () => if I.> (first, last) then S.Nil
    else S.Cons (L.delay (fn () => first), L.delay (fn () => L.force (range (I.+ (first, 1)) last))))
  fun strictRange first last = if I.> (first, last) then [] else first :: strictRange (I.+ (first, 1)) last
  fun mapDelayed f xs = L.delay (fn () => case L.force xs of S.Nil => S.Nil
    | S.Cons (x, rest) => S.Cons (L.delay (fn () => f x), mapDelayed f rest))
  fun coordinate (minX, minY, maxX, maxY) width height s t =
    (minX + (Real.fromLargeInt s * (maxX - minX)) / Real.fromLargeInt width,
     minY + (Real.fromLargeInt t * (maxY - minY)) / Real.fromLargeInt height)
  datatype 'a pixmap = Pixmap of I.int * I.int * int * 'a
  fun rgb limit count = let val other = limit - count in (count, other, other) end
  fun makeLazy old viewport width height limit =
    let val (minX, minY, maxX, maxY) = viewport
        val span = Real.max (maxX - minX, maxY - minY)
        val radius = span / 2.0
        val step = if old then oldStep else generic
        val points = S.concatMap (fn t => S.map (fn s => coordinate viewport width height s t)
          (range 1 width)) (range 1 height)
        val pixels = mapDelayed (fn c => rgb limit (if old then lazyOld step limit span c
          else lazyNew step limit radius c)) points
    in Pixmap (width, height, limit, pixels) end
  fun makeStrict old viewport width height limit =
    let val (minX, minY, maxX, maxY) = viewport
        val span = Real.max (maxX - minX, maxY - minY)
        val radius = span / 2.0
        val step = if old then oldStep else generic
        val points = List.concat (List.map (fn t => List.map (fn s => coordinate viewport width height s t)
          (strictRange 1 width)) (strictRange 1 height))
        val pixels = List.map (fn c => rgb limit (if old then strictOld step limit span c
          else strictNew step limit radius c)) points
    in Pixmap (width, height, limit, pixels) end
  fun appLazy f = S.foldl (fn (pixel, ()) => f pixel) ()
  fun appStrict f = List.app f
  fun render old strict viewport width height limit emit =
    let fun output app (Pixmap (w, h, cap, pixels)) =
          (emit (I.toString w ^ " " ^ I.toString h ^ " " ^ Int.toString cap ^ "\n");
           app (fn (r, g, b) => emit (Int.toString r ^ " " ^ Int.toString g ^ " " ^ Int.toString b ^ "\n")) pixels)
    in if strict then output appStrict (makeStrict old viewport width height limit)
       else output appLazy (makeLazy old viewport width height limit) end
end
