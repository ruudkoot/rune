(* McIlroy's Ps algebra: memoized coefficients and spines, finite Pz retained. *)
signature BENCH_POWER_NUMBER =
sig
  type t
  val zero : t
  val one : t
  val fromInt : int -> t
  val equal : t * t -> bool
  val add : t * t -> t
  val negate : t -> t
  val multiply : t * t -> t
  val divide : t * t -> t
  val show : t -> string
end

functor BenchPowerFn (N : BENCH_POWER_NUMBER) =
struct
  structure L = BenchLazy
  structure S = BenchStream
  type series = N.t S.stream
  val zero : series = S.empty ()
  fun coefficient (x : N.t) = L.delay (fn () => x)
  fun cons (x, xs) = S.cons (coefficient x, xs)
  fun constant x = if N.equal (x,N.zero) then zero else cons (x,zero)
  val one = constant N.one
  val x = cons (N.zero,one)
  fun negate fs = S.map N.negate fs
  fun add fs gs = L.delay (fn () => case L.force fs of
      S.Nil => L.force gs
    | S.Cons (f,ft) => case L.force gs of
        S.Nil => S.Cons (f,ft)
      | S.Cons (g,gt) => S.Cons
          (L.delay (fn () => N.add (L.force f,L.force g)),add ft gt))
  fun subtract fs gs = add fs (negate gs)
  fun scale c fs = S.map (fn f => N.multiply (L.force c,f)) fs
  fun multiply fs gs = L.delay (fn () => case L.force fs of
      S.Nil => S.Nil
    | S.Cons (f,ft) => case L.force gs of
        S.Nil => S.Nil
      | S.Cons (g,gt) => S.Cons
          (L.delay (fn () => N.multiply (L.force f,L.force g)),
           add (add (scale f gt) (scale g ft))
             (multiply (multiply x ft) gt)))
  fun square fs = multiply fs fs
  fun divide fs gs = L.delay (fn () => case L.force fs of
      S.Nil => (case L.force gs of
          S.Nil => raise Fail "power series 0/0"
        | S.Cons (g,gt) =>
            if N.equal (L.force g,N.zero) then L.force (divide zero gt) else S.Nil)
    | S.Cons (f,ft) =>
        (* Haskell tests the numerator's zero pattern before inspecting gs. *)
        let val numeratorZero = N.equal (L.force f,N.zero)
        in case L.force gs of
            S.Nil => raise Fail "power series division by zero"
          | S.Cons (g,gt) =>
              if numeratorZero andalso N.equal (L.force g,N.zero)
              then L.force (divide ft gt)
              else let val q = L.delay (fn () => N.divide (L.force f,L.force g))
                   in S.Cons (q,divide (subtract ft (scale q gt)) gs) end
        end)
  fun compose fs gs = L.delay (fn () => case L.force fs of
      S.Nil => S.Nil
    | S.Cons (f,ft) => case L.force gs of
        S.Nil => S.Cons (f,zero)
      | S.Cons (g,gt) =>
          if N.equal (L.force g,N.zero)
          then S.Cons (f,multiply gt (compose ft gs))
          else L.force (add (S.cons (f,zero)) (multiply gs (compose ft gs))))
  fun revert fs = L.delay (fn () => case L.force fs of
      S.Cons (f,ft) =>
        if N.equal (L.force f,N.zero) then
          L.force (S.fix (fn rs => S.Cons (coefficient N.zero,divide one (compose ft rs))))
        else (case L.force ft of
            S.Cons (g,gt) => (case L.force gt of S.Nil =>
              L.force (cons (N.divide (N.negate N.one,L.force g),
                cons (N.divide (N.one,L.force g),zero)))
              | _ => raise Fail "unsupported power series reversion")
          | _ => raise Fail "unsupported power series reversion")
    | _ => raise Fail "unsupported power series reversion")
  fun derivative fs = L.delay (fn () => case L.force fs of
      S.Nil => S.Nil
    | S.Cons (_,ft) => L.force (derivativeFrom ft 1))
  and derivativeFrom fs n = L.delay (fn () => case L.force fs of
      S.Nil => S.Nil
    | S.Cons (f,ft) => S.Cons (L.delay (fn () =>
        N.multiply (N.fromInt n,L.force f)),derivativeFrom ft (n+1)))
  (* The leading zero is emitted before even inspecting the operand. *)
  fun integral fs = cons (N.zero,integralFrom fs 1)
  and integralFrom fs n = L.delay (fn () => case L.force fs of
      S.Nil => S.Nil
    | S.Cons (f,ft) => S.Cons (L.delay (fn () =>
        N.divide (L.force f,N.fromInt n)),integralFrom ft (n+1)))
  fun squareRoot fs = L.delay (fn () => case L.force fs of
      S.Nil => S.Nil
    | S.Cons (f,ft) =>
        if N.equal (L.force f,N.one) then
          L.force (S.fix (fn qs => L.force (add one
            (integral (divide (derivative fs) (scale (coefficient (N.fromInt 2)) qs))))))
        else if N.equal (L.force f,N.zero) then
          (case L.force ft of S.Cons (g,gt) =>
            if N.equal (L.force g,N.zero) then S.Cons (f,squareRoot gt)
            else raise Fail "unsupported power series square root"
          | _ => raise Fail "unsupported power series square root")
        else raise Fail "unsupported power series square root")
  fun render n fs =
    let fun extract (0,_) = []
          | extract (left,series) = case L.force series of S.Nil => []
            | S.Cons (f,ft) => N.show (L.force f)::extract (left-1,ft)
    in "[" ^ String.concatWith "," (extract (n,fs)) ^ "]" end
end

structure BenchPowerInteger =
struct
  type t = IntInf.int
  val zero : t = 0
  val one : t = 1
  val fromInt = IntInf.fromInt
  fun equal (a:t,b) = a=b
  val add = IntInf.+
  val negate = IntInf.~
  val multiply = IntInf.*
  fun divide (_:t,_:t) : t = raise Fail "integer series is not fractional"
  fun show n = String.translate (fn #"~" => "-" | c => String.str c) (IntInf.toString n)
end

structure BenchPowerRational =
struct
  type t = BenchRational.rational
  val zero : t = (0,1)
  val one : t = (1,1)
  fun fromInt n : t = (IntInf.fromInt n,1)
  fun equal (a:t,b) = a=b
  val add = BenchRational.add
  fun negate (n,d) = (IntInf.~ n,d)
  fun multiply ((a,b):t,(c,d):t) = BenchRational.ratio (IntInf.*(a,c),IntInf.*(b,d))
  fun divide ((a,b):t,(c,d):t) = BenchRational.ratio (IntInf.*(a,d),IntInf.*(b,c))
  val show = BenchRational.show
end
