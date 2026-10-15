(* Decimal chunk boundaries, signs and immutable magnitudes. *)
structure I = IntInf
val one = I.fromInt 1
fun check n =
  let val p = I.pow(I.fromInt 10,n)
      val original = p
      val zeros = String.implode(List.tabulate(n,fn _ => #"0"))
      val nines = String.implode(List.tabulate(n,fn _ => #"9"))
      val text = "1" ^ zeros
  in I.toString p = text andalso I.toString (I.~ p) = "~" ^ text andalso
     I.toString (I.-(p,one)) = nines andalso
     I.toString (I.+(p,one)) = "1" ^ String.substring(zeros,1,n-1) ^ "1" andalso
     I.fmt StringCvt.DEC p = text andalso I.toString p = text andalso p = original
  end
val () = print(Bool.toString(List.all check [1,4,9,15,18,19,20,27,31,36,64,128,257,1024]) ^ "\n")
val () = print(Bool.toString(I.toString(I.fromInt 0)="0" andalso I.toString(I.fromInt (~1))="~1") ^ "\n")
val x = I.+(I.pow(I.fromInt 10,90),I.pow(I.fromInt 10,36))
val expected = "1" ^ String.implode(List.tabulate(53,fn _ => #"0")) ^
               "1" ^ String.implode(List.tabulate(36,fn _ => #"0"))
val () = print(Bool.toString(I.toString x=expected andalso I.toString(I.~ x)="~" ^ expected) ^ "\n")
