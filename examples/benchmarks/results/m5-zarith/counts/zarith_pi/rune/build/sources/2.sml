(* SML97 translations of the Sandmark/Zarith tests and the used Num integer
   operations. Original sources, authorship, GNU Library GPL v2 (Zarith) and
   LGPL v2.1 (Num), with their linking exceptions, are retained in
   shared/zarith-upstream. See each benchmark's PROVENANCE.md. *)
(* Sandmark/Zarith streaming pi: retain all four LFT coefficients. *)
structure BenchZarithPi =
struct
  type lft = IntInf.int * IntInf.int * IntInf.int * IntInf.int
  val zero = IntInf.fromInt 0
  val one = IntInf.fromInt 1
  val ten = IntInf.fromInt 10
  val negativeTen = IntInf.fromInt ~10
  val unit = (one, zero, zero, one)

  fun floorEv ((q,r,s,t) : lft) x =
    IntInf.quot (IntInf.+ (IntInf.* (q,x),r),
                 IntInf.+ (IntInf.* (s,x),t))

  fun comp ((q,r,s,t) : lft) ((a,b,c,d) : lft) =
    let
      val td = IntInf.+ (IntInf.* (s,b),IntInf.* (t,d))
      val sc = IntInf.+ (IntInf.* (s,a),IntInf.* (t,c))
      val rb = IntInf.+ (IntInf.* (q,b),IntInf.* (r,d))
      val qa = IntInf.+ (IntInf.* (q,a),IntInf.* (r,c))
    in (qa,rb,sc,td) end

  fun prod z n = comp (ten,IntInf.* (negativeTen,n),zero,one) z
  fun cons z k =
    let val den = 2*k+1
    in comp z (IntInf.fromInt k,IntInf.fromInt (2*den),zero,IntInf.fromInt den) end

  fun run count emit =
    let
      fun spaces n = String.implode (List.tabulate (n,fn _ => #" "))
      fun digit k z n row col =
        if n>0 then
          let val y = floorEv z (IntInf.fromInt 3)
          in
            if y = floorEv z (IntInf.fromInt 4) then
              if col=10 then
                let val nextRow = row+10
                in emit ("\t:"^Int.toString nextRow^"\n");
                   emit (IntInf.toString y);
                   digit k (prod z y) (n-1) nextRow 1
                end
              else (emit (IntInf.toString y); digit k (prod z y) (n-1) row (col+1))
            else digit (k+1) (cons z k) n row col
          end
        else emit (spaces (10-col)^"\t:"^Int.toString (row+col)^"\n")
    in digit 1 unit count 0 0 end

  fun check count expected =
    let
      val position = ref 0
      fun emit text =
        let val n = String.size text
        in
          if !position+n <= String.size expected andalso
             String.substring (expected,!position,n) = text
          then position := !position+n
          else raise Fail "pi output differs from reviewed digits and layout"
        end
      val _ = run count emit
    in if !position = String.size expected then () else raise Fail "pi output is incomplete" end
end
