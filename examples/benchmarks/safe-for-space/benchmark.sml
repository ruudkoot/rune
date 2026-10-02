(* main.sml
 *
 * COPYRIGHT (c) 2020 John Reppy (http://cs.uchicago.edu/~jhr)
 * All rights reserved.
 *
 * This is an example from the "Efficient and Safe-for-Space Closure
 * Conversion" paper by Zhong Shao and Andrew Appel (TOPLAS 2000).
 *)

structure Kernel =
  struct

    val name = "safe-for-space"

    val results : string list = []

    exception Empty

    fun hd l = (case l of [] => raise Empty | x::_ => x)

    val N = 10000

    fun f (v, w, x, y, z) = let
          fun g () = let
                val u = hd v
                fun h () = let
                      fun i () = w+x+y+z+3
                      in
                        (i, u)
                      end
                in
                  h
                end
          in
            g
          end;

    fun big n = if n < 1 then nil else n :: big(n-1);

    fun loop (bigSize, n, res) =
          if (n < 1)
            then res
            else let
              val s = f (big bigSize, 0, 0, 0, 0) ()
              in
                loop (bigSize, n-1, s::res)
              end

    (*
    val result = loop (N, [])
    *)

end
structure Benchmark=struct val name="safe-for-space"
fun run [size,closures]=let val n=BenchInput.between(1,100000)(BenchInput.integer size) val r=BenchInput.between(1,100000)(BenchInput.integer closures)
val retained=Kernel.loop(n,r,[])
fun use(h,(count,sum))=let val(i,u)=h() val v=i() in if v=3 andalso u=n then(count+1,IntInf.+(sum,IntInf.fromInt(v+u)))else raise Fail "closure result"end
val(count,sum)=List.foldl use (0,0)retained val _=if count=r then () else raise Fail "closure count"
in IntInf.toString sum end |run _=raise Fail "safe-for-space expects list size retained closures"end
