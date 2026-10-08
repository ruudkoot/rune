(* Canonical values across the machine-int boundary, independent of width. *)
structure PackedIntInf =
struct
  structure I = IntInf
  fun check (name, yes) = print (name ^ ": " ^ Bool.toString yes ^ "\n")
  val top = I.fromInt (valOf Int.maxInt)
  val above = I.+ (top,I.fromInt 1)
  val () = check ("small and large", I.- (above,I.fromInt 1) = top)
  val () = check ("negative boundary", I.toInt (I.~ above) = valOf Int.minInt)
  val () = check ("bounded conversion", (I.toInt above; false) handle Overflow => true)
  val () = check ("canonical sign", I.~ (I.~ above) = above)
  val below = I.- (I.~ above,I.fromInt 1)
  val () = check ("mixed comparisons", I.compare(top,above) = LESS andalso
    I.compare(above,top) = GREATER andalso I.compare(below,I.~ above) = LESS andalso
    I.compare(I.~ above,below) = GREATER andalso I.compare(above,below) = GREATER)
  val () = check ("minimum quotient", I.quot (I.fromInt (valOf Int.minInt),I.fromInt (~1)) = above)
  val b = I.pow (I.fromInt 2,60)
  val square = I.* (b,b)
  val () = check ("carry product", I.* (I.- (b,I.fromInt 1),I.+ (b,I.fromInt 1)) = I.- (square,I.fromInt 1))
  val () = check ("division correction", I.divMod (I.+ (square,I.fromInt 1),I.+ (b,I.fromInt 1)) = (I.- (b,I.fromInt 1),I.fromInt 2))
  val () = check ("zero normalization", I.* (square,I.fromInt 0) = I.fromInt 0)
  val () = check ("arithmetic shift", I.~>> (I.~ (I.+ (b,I.fromInt 1)),0w60) = I.fromInt (~2))
  val () = check ("packed round trip", valOf (I.fromString (I.toString square)) = square)
  (* For B = 2^15 and 2^30: ((B/2-1)*B^2) divided by (B^2/2+B-1)
     has quotient B-4 and remainder 5B-4. (B^3+1) divided by (B^3/2+1)
     has quotient 1 and remainder B^3/2. These exercise difficult leading
     quotient estimates; each expected pair satisfies q*v+r=u and 0<=r<v. *)
  val corrections =
    [("17591112302592","536903679","32764","163836"),
     ("35184372088833","17592186044417","1","17592186044416"),
     ("618970018489768632842715136","576460753377165311","1073741820","5368709116"),
     ("1237940039285380274899124225","618970019642690137449562113","1","618970019642690137449562112")]
  fun number s = valOf (I.fromString s)
  val () = check ("quotient estimates", List.all
    (fn (u,v,q,r) => I.divMod(number u,number v) = (number q,number r)) corrections)
end
