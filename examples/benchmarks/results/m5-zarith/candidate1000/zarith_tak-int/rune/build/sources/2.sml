(* SML97 translations of the Sandmark/Zarith tests and the used Num integer
   operations. Original sources, authorship, GNU Library GPL v2 (Zarith) and
   LGPL v2.1 (Num), with their linking exceptions, are retained in
   shared/zarith-upstream. See each benchmark's PROVENANCE.md. *)
(* Ground numeric interfaces for the integer-only Zarith/Num benchmark modes. *)
signature BENCH_ZARITH_NUMBER =
sig
 type t
 val one : t
 val fromInt : int -> t
 val add : t * t -> t
 val pred : t -> t
 val greater : t * t -> bool
 val toString : t -> string
end
structure BenchZarithInt : BENCH_ZARITH_NUMBER =
struct
 type t=int
 val one=1
 fun fromInt n=n
 val add=op +
 fun pred n=n-1
 val greater=op >
 val toString=Int.toString
end
structure BenchZarithBig : BENCH_ZARITH_NUMBER =
struct
 type t=IntInf.int
 val one=IntInf.fromInt 1
 val fromInt=IntInf.fromInt
 val add=IntInf.+
 fun pred n=IntInf.-(n,one)
 val greater=IntInf.>
 val toString=IntInf.toString
end
structure BenchZarithNative : BENCH_ZARITH_NUMBER =
struct
 type t=Word64.word
 val one=0w1:Word64.word
 val sign=0wx8000000000000000:Word64.word
 val fromInt=Word64.fromInt
 val add=Word64.+
 fun pred n=Word64.-(n,one)
 fun greater(x,y)=Word64.>(Word64.xorb(x,sign),Word64.xorb(y,sign))
 fun toString n=IntInf.toString(Word64.toLargeIntX n)
end
structure BenchZarithNum : BENCH_ZARITH_NUMBER =
struct
 datatype t=Small of int | Big of IntInf.int
 val one=Small 1
 val fromInt=Small
 fun big(Small n)=IntInf.fromInt n | big(Big n)=n
 fun normalize n=(Small(IntInf.toInt n)handle Overflow=>Big n)
 fun add(Small x,Small y)=(Small(x+y)handle Overflow=>Big(IntInf.+(IntInf.fromInt x,IntInf.fromInt y)))
   | add(x,y)=normalize(IntInf.+(big x,big y))
 fun pred(Small n)=(Small(n-1)handle Overflow=>Big(IntInf.-(IntInf.fromInt n,IntInf.fromInt 1)))
   | pred(Big n)=normalize(IntInf.-(n,IntInf.fromInt 1))
 fun greater(Small x,Small y)=x>y | greater(x,y)=IntInf.>(big x,big y)
 fun toString(Small n)=Int.toString n | toString(Big n)=IntInf.toString n
end
functor BenchZarithFibFn(N : BENCH_ZARITH_NUMBER) =
struct
 fun fib n=if n<2 then N.one else
   let val right=fib(n-2)
       val left=fib(n-1)
   in N.add(left,right)end
end
functor BenchZarithTakFn(N : BENCH_ZARITH_NUMBER) =
struct
 fun tak(x,y,z)=if N.greater(x,y)then
   let val right=tak(N.pred z,x,y)
       val middle=tak(N.pred y,z,x)
       val left=tak(N.pred x,y,z)
   in tak(left,middle,right)end else z
end
structure BenchZarithFact =
struct
 fun fact n=if n<=0 then IntInf.fromInt 1 else
   let val previous=fact(n-1)
       val factor=IntInf.fromInt n
   in IntInf.*(factor,previous)end
end

structure BenchZarithRepeat =
struct
 (* The source executes once even for count <= 0.  Check every discarded result. *)
 fun run count kernel arg check =
   let fun loop n =
     if n<=0 then let val value=kernel arg in check value; value end
     else (check(kernel arg);loop(n-1))
   in loop count end
end
