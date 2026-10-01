(* Written by Stephen Weeks (sweeks@sweeks.com). *)
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


structure PeekKernel =
   struct
      fun inner count =
         let
            val l1 = Plist.new ()
            val l2 = Plist.new ()
            val {add = addA, peek = peekA} = Plist.addPeek ()
            val {add = addB, peek = peekB} = Plist.addPeek ()
            val {add = addC, peek = peekC} = Plist.addPeek ()
            val {add = addD, peek = peekD} = Plist.addPeek ()
            val _ = addA (l1, 13: Int32.int)
            val _ = addB (l1, 15: Int64.int)
            val _ = addC (l1, 17: Int32.int)
            val _ = addD (l1, 19: Int64.int)
            val _ = addA (l2, 19: Int32.int)
            val _ = addB (l2, 17: Int64.int)
            val _ = addC (l2, 15: Int32.int)
            val _ = addD (l2, 13: Int64.int)
            fun peek l =
               Int32.toInt (valOf (peekA l1)) + Int64.toInt (valOf (peekB l))
               + Int32.toInt (valOf (peekC l)) + Int64.toInt (valOf (peekD l))
            fun loop (i, ac1, ac2) =
               if i = 0
                  then (ac1, ac2)
               else loop (i - 1, ac1 + peek l1, ac2 + peek l2)
            val (n1, n2) = loop (count, 0, 0)
            val _ =
               if n1 <> 64 * count orelse n2 <> 58 * count
                  then raise Fail "bug"
                  else ()
         in (n1,n2)
         end


end
structure Benchmark =
struct
  val name="peek"
  fun run [size,reps]=
    let val n=BenchInput.between(1,10000000)(BenchInput.integer size)
        val count=BenchInput.between(1,1000)(BenchInput.integer reps)
        fun loop(0,a,b)=(a,b) | loop(k,a,b)=let val(x,y)=PeekKernel.inner n
          in loop(k-1,IntInf.+(a,IntInf.fromInt x),IntInf.+(b,IntInf.fromInt y)) end
        val(a,b)=loop(count,0,0)
    in IntInf.toString a^" "^IntInf.toString b end
  | run _=raise Fail "peek expects iterations repetitions"
end
