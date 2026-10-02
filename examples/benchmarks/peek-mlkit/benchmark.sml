(* Written by Stephen Weeks (sweeks@acm.org). *)
structure Plist:
   sig
      type t

      val new: unit -> t
      val addPeek: unit -> {add: t * 'a -> unit,
                            peek: t -> 'a option}
   end =
   struct
      datatype t = T of exn list ref

      fun new () = T (ref [])

      fun addPeek () =
         let
            exception E of 'a
            fun add (T r, x) = r := E x :: !r
            fun peek (T r) =
               let
                  val rec loop =
                     fn [] => NONE
                      | E x :: _ => SOME x
                      | _ :: l => loop l
               in loop (!r)
               end
         in {add = add, peek = peek}
         end
   end

structure Benchmark=struct val name="peek-mlkit"
fun run [lookups,reps]=let val n=BenchInput.between(1,10000000)(BenchInput.integer lookups) val r=BenchInput.between(1,1000)(BenchInput.integer reps)
fun one()=let val list=Plist.new() val {add,peek}=Plist.addPeek() val _=add(list,13)
fun loop(0,sum)=sum |loop(k,sum)=loop(k-1,sum+valOf(peek list))
in loop(n,0)end
in IntInf.toString(BenchInput.repeat r one)end |run _=raise Fail "peek expects lookups repetitions"end
