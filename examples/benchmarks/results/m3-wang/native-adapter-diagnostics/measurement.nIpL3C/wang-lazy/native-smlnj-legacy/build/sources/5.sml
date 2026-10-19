functor BenchWangFn (D : BENCH_SUSPEND) =
struct
  datatype 'a node = Nil | Cons of 'a D.t * 'a node D.t
  type 'a seq = 'a node D.t
  type row = real D.t * real D.t * real D.t * real D.t
  type rowcell = row D.t
  fun empty () = D.delay (fn () => Nil)
  fun cons (x, xs) = D.delay (fn () => Cons (x, xs))
  fun head xs = case D.force xs of Nil => raise Empty | Cons (x, _) => x
  fun tail xs = case D.force xs of Nil => raise Empty | Cons (_, xs) => xs
  fun last xs = case D.force xs of Nil => raise Empty | Cons (x, xs) =>
    (case D.force xs of Nil => x | _ => last xs)
  fun init xs = D.delay (fn () => case D.force xs of Nil => raise Empty
    | Cons (x, xs) => case D.force xs of Nil => Nil | _ => Cons (x, init xs))
  fun map f xs = D.delay (fn () => case D.force xs of Nil => Nil
    | Cons (x, xs) => Cons (f x, map f xs))
  fun append xs after = D.delay (fn () => case D.force xs of Nil => D.force (after ())
    | Cons (x, xs) => Cons (x, append xs after))
  fun replicate 0 x = empty ()
    | replicate n x = D.delay (fn () => Cons (x, replicate (n-1) x))
  fun zip2 xs ys = D.delay (fn () => case (D.force xs, D.force ys) of
      (Cons (x, xs), Cons (y, ys)) => Cons (D.delay (fn () => (x,y)), zip2 xs ys)
    | _ => Nil)
  fun zip3 xs ys zs = D.delay (fn () => case (D.force xs, D.force ys, D.force zs) of
      (Cons (x,xs), Cons (y,ys), Cons (z,zs)) => Cons (D.delay (fn () => (x,y,z)), zip3 xs ys zs)
    | _ => Nil)
  fun a (r : rowcell) = D.force (#1 (D.force r))
  fun b (r : rowcell) = D.force (#2 (D.force r))
  fun c (r : rowcell) = D.force (#3 (D.force r))
  fun rhs (r : rowcell) = D.force (#4 (D.force r))
  fun real x = D.delay (fn () => x)
  fun row (a,b,c,r) = D.delay (fn () => (real a,real b,real c,real r))
  fun el21 xs = D.delay (fn () => case D.force xs of Nil => raise Empty
    | Cons (x, more) => case D.force more of Nil => Cons (x,empty ())
      | Cons (y, rest) =>
          let val factor = D.delay (fn () => a y / b x)
              val changed = D.delay (fn () =>
                (D.delay (fn () => ~(D.force factor * a x)),
                 D.delay (fn () => b y - D.force factor * c x),
                 #3 (D.force y),
                 D.delay (fn () => rhs y - D.force factor * rhs x)))
          in Cons (x,el21 (cons (changed,rest))) end)
  fun el22 xs = D.delay (fn () => case D.force xs of Nil => raise Empty
    | Cons (x, more) => case D.force more of Nil => raise Empty
      | Cons (y, rest) => case D.force rest of Nil => Cons (x,cons (y,empty ()))
        | _ =>
          let val result = el22 more
              val next = D.delay (fn () => D.force (head result))
              val factor = D.delay (fn () => c x / b next)
              val changed = D.delay (fn () =>
                (D.delay (fn () => a x - D.force factor * a next),
                 #2 (D.force x),D.delay (fn () => ~(D.force factor * c next)),
                 D.delay (fn () => rhs x - D.force factor * rhs next)))
          in Cons (changed,result) end)
  fun el23 xs = D.delay (fn () => case D.force xs of Nil => raise Empty
    | Cons (x,more) => case D.force more of Nil => Cons (x,empty ())
      | _ =>
          let val result = el23 more
              val next = D.delay (fn () => D.force (head result))
              val factor = D.delay (fn () => c x / b next)
              val changed = D.delay (fn () => (#1 (D.force x),#2 (D.force x),real 0.0,
                D.delay (fn () => rhs x - D.force factor * rhs next)))
          in Cons (changed,result) end)
  fun el2 xs = el22 (el21 xs)
  fun eldia xs = el23 (el21 xs)
  fun el1 pair = D.delay (fn () =>
    let val (x,y) = D.force pair
        val factor = D.delay (fn () => c y / b x)
    in (#1 (D.force y),D.delay (fn () => b y - D.force factor * a x),
        D.delay (fn () => ~(D.force factor * c x)),
        D.delay (fn () => rhs y - D.force factor * rhs x)) end)
  fun el31 xs anchor = D.delay (fn () => case D.force xs of
      Nil => Cons (D.delay (fn () => rhs anchor / b anchor),empty ())
    | Cons (x,more) =>
        Cons (D.delay (fn () => b x / (rhs x - (c x / b anchor) * rhs anchor)),el31 more anchor))
  fun el3 (left,xs,right) = D.delay (fn () => case D.force xs of
      Nil => Cons (D.delay (fn () => rhs right / b right),empty ())
    | Cons (x,more) =>
        Cons (D.delay (fn () => b x / ((rhs x - (a x / b left) * rhs left)
          - (c x / b right) * rhs right)),el3 (left,more,right)))
  fun matrix n =
    let val first = row (0.0,3.0,2.0,5.0)
        val middle = row (2.0,3.0,2.0,7.0)
        val final = row (2.0,3.0,0.0,5.0)
        val firstBlock = D.delay (fn () => cons (first,replicate n middle))
        val middleBlock = D.delay (fn () => replicate (n+1) middle)
        val lastBlock = D.delay (fn () => append (replicate n middle)
          (fn () => cons (final,empty ())))
    in cons (firstBlock,append (replicate (n-2) middleBlock)
         (fn () => cons (lastBlock,empty ()))) end
  fun solution input =
    let val matrix1 = map (fn block => D.delay (fn () => el2 (D.force block))) input
        val firstRows1 = map (fn block => D.delay (fn () => D.force (head (D.force block)))) (tail matrix1)
        val lastRows1 = map (fn block => D.delay (fn () => D.force (last (D.force block)))) matrix1
        val pairs = zip2 firstRows1 (init lastRows1)
        val lastRows3 = eldia (append (map el1 pairs) (fn () => cons (last lastRows1,empty ())))
        val matrix2 = map (fn block => D.delay (fn () => init (D.force block))) matrix1
        val triples = zip3 lastRows3 matrix2 (tail lastRows3)
        val firstResult = D.delay (fn () => el31 (D.force (head matrix2)) (head lastRows3))
    in cons (firstResult,map (fn triple => D.delay (fn () =>
         let val (left,block,right) = D.force triple in el3 (left,D.force block,right) end)) triples) end
  fun values n = solution (matrix n)
  fun checkValue value =
    if Real.isFinite value andalso Real.abs (value-1.0) <= 1.0E~10 then ()
    else raise Fail "incorrect result: numerical solution differs from one"
  structure L = BenchLazy
  structure S = BenchStream
  fun text value = S.fromList (String.explode value)
  fun concatenate [] = S.empty ()
    | concatenate [last] = L.delay (fn () => L.force (last ()))
    | concatenate (first::rest) = L.delay (fn () =>
        L.force (S.append (first ()) (concatenate rest)))
  fun render n =
    let val checked = ref 0
        fun showOne value = L.delay (fn () =>
          let val x = D.force value
              val _ = checkValue x
              val _ = checked := !checked + 1
          in L.force (text (if Real.abs(x-1.0) <= 0.0005 then "1"
               else Real.fmt (StringCvt.GEN (SOME 17)) x)) end)
        fun prefix token show values = L.delay (fn () =>
          case D.force values of Nil => S.Nil | Cons (value,rest) =>
            L.force (S.append (S.append (text token) (show value)) (prefix token show rest)))
        fun showRow row = concatenate [fn () => text "[",
          fn () => S.tail (prefix "," showOne (D.force row)),fn () => text "]"]
        val output = concatenate [fn () => text "[",
          fn () => S.tail (S.tail (prefix ",\n" showRow (values n))),fn () => text "]"]
    in (output,checked) end
  fun digest (source,total,count) = case L.force source of
      S.Nil => (total+count,count)
    | S.Cons (value,rest) => digest (rest,total+Char.ord(L.force value),count+1)
  fun run n =
    let val (source,checked) = render n
        val (code,size) = digest (source,0,0)
        val _ = if !checked = n*(n+1) then ()
          else raise Fail "incorrect result: numerical value count differs"
    in Int.toString code ^ "/" ^ Int.toString size end
end
