(* Written by Stephen Weeks (sweeks@sweeks.com). *)
structure Array = Array2

fun 'a fold (n : int, b : 'a, f : int * 'a -> 'a) =
   let
      fun loop (i : int, b : 'a) : 'a =
         if i = n
            then b
         else loop (i + 1, f (i, b))
   in loop (0, b)
   end

fun foreach (n : int, f : int -> unit) : unit =
   fold (n, (), f o #1)

fun mult (a1 : real Array.array, a2 : real Array.array) : real Array.array =
   let
      val r1 = Array.nRows a1
      val c1 = Array.nCols a1
      val r2 = Array.nRows a2
      val c2 = Array.nCols a2
   in if c1 <> r2
         then raise Fail "mult"
      else
         let val a = Array2.array (r1, c2, 0.0)
            fun dot (r, c) =
               fold (c1, 0.0, fn (i, sum) =>
                    sum + Array.sub (a1, r, i) * Array.sub (a2, i, c))
         in foreach (r1, fn r =>
                    foreach (c2, fn c =>
                            Array.update (a, r, c, dot (r,c))));
            a
         end
   end


structure Benchmark =
struct
  val name = "matrix-multiply"
  fun run [size] =
        let val n = BenchInput.between (1, 500) (BenchInput.integer size)
            val input = Array2.tabulate Array2.RowMajor (n,n,fn (r,c) => Real.fromInt (r+c))
            val result = mult (input,input)
            val ni = IntInf.fromInt n
            val s1 = IntInf.div (IntInf.* (ni,IntInf.- (ni,1)),2)
            val s2 = IntInf.div (IntInf.* (IntInf.* (ni,IntInf.- (ni,1)),IntInf.- (IntInf.* (2,ni),1)),6)
            fun expected (i,j) = IntInf.+ (IntInf.+ (IntInf.* (ni,IntInf.* (IntInf.fromInt i,IntInf.fromInt j)),
              IntInf.* (IntInf.fromInt (i+j),s1)),s2)
            fun check (i,j,sum) = if i=n then sum else if j=n then check(i+1,0,sum) else
              let val want = expected(i,j)
                  val observed = Array2.sub(result,i,j)
              in if BenchInput.closeReal(observed,Real.fromLargeInt want,0.000001,0.0) then check(i,j+1,IntInf.+(sum,want))
                 else raise Fail "matrix result" end
        in IntInf.toString(check(0,0,0)) end
    | run _ = raise Fail "matrix-multiply expects dimension"
end
