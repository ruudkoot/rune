(* IntInf: an immediate where the number fits the word, else a sign and an
   immutable packed magnitude (haskell98 M31, D20 D). The VM's primitives
   add, subtract, multiply, divide and compare, two immediates in line and
   the rest in the runtime (runtime/intinf.c); this structure does the
   rest over the parts of a number, its sign and its magnitude, whose bytes
   are little endian, independent of the workspace's limb width. Arrays
   below are private scratch and never escape in a value.

   Implements: INT_INF

   Implements: INTEGER

   Status: optional *)
structure IntInf =
struct
  type limb = int
  type int = _prim "intinf"

  val intQuot = _prim "int_quot" : limb * limb -> limb
  val intRem = _prim "int_rem" : limb * limb -> limb
  val intToString = _prim "int_to_string" : limb -> string
  val strSize = _prim "string_size" : string -> limb
  val strSub = _prim "string_sub" : string * limb -> char
  val anew = _prim "array_new" : limb * limb -> limb array
  val alen = _prim "array_length" : limb array -> limb
  val at = _prim "array_sub" : limb array * limb -> limb
  val put = _prim "array_update" : limb array * limb * limb -> unit
  val intAdd = _prim "int_add" : limb * limb -> limb
  fun width (n, k) = width (intAdd (intAdd (n,n),1), k+1)
                      handle Overflow => k+1
  val machineBits = width (0,0)
  val smallBytes = (machineBits + 7) div 8
  val limbBits = if machineBits >= 61 then 30 else 15
  val shiftWord = _prim "word_lsl" : word * word -> word
  val toWord = _prim "word_from_int" : limb -> word
  val fromWord = _prim "word_to_int" : word -> limb
  fun pow2 k = fromWord(shiftWord(0w1,toWord k))
  val base = pow2 limbBits
  val mask = base - 1
  val fromInt = _prim "intinf_from_int" : limb -> int
  val toInt = _prim "intinf_to_int" : int -> limb
  (* whether a number is an immediate, which toInt gives *)
  val isSmall = _prim "intinf_is_small" : int -> bool
  (* a number's sign and canonical magnitude, and the number of a pair *)
  val parts = _prim "intinf_parts" : int -> bool * string
  val make = _prim "intinf_make" : bool * string -> int
  val addI = _prim "intinf_add" : int * int -> int
  val subI = _prim "intinf_sub" : int * int -> int
  val mulI = _prim "intinf_mul" : int * int -> int
  val negI = _prim "intinf_neg" : int -> int
  val quotI = _prim "intinf_quot" : int * int -> int
  val remI = _prim "intinf_rem" : int * int -> int
  val divI = _prim "intinf_div" : int * int -> int
  val modI = _prim "intinf_mod" : int * int -> int
  val ltI = _prim "intinf_lt" : int * int -> bool
  val leI = _prim "intinf_le" : int * int -> bool
  val gtI = _prim "intinf_gt" : int * int -> bool
  val geI = _prim "intinf_ge" : int * int -> bool
  val compare = _prim "intinf_order" : int * int -> order
  val zero = fromInt 0
  val one = fromInt 1
  val minusOne = fromInt (~1)

  fun byte (s,i) = ord (strSub (s,i))
  fun bput (a,i,n) = RuneBytes.update (a,i,chr n)
  val gmpAvailable = _prim "intinf_gmp_available" : unit -> bool
  val maxBits = _prim "intinf_max_bits" : unit -> limb
  val checkBits = _prim "intinf_check_bits" : limb -> unit
  val gmpBinary = _prim "intinf_binary" : limb * bool * string * bool * string -> bool * string
  val gmpShift = _prim "intinf_shift" : bool * bool * string * word -> bool * string
  val gmpPower = _prim "intinf_power" : bool * string * limb -> bool * string
  val gmpDecimal = _prim "intinf_decimal" : string -> string
  fun digitBits 0 = 0 | digitBits n = 1 + digitBits(n div 2)
  fun magBits s =
    let val n = strSize s in if n = 0 then 0 else (n-1)*8+digitBits(byte(s,n-1)) end
  fun checkMag s =
    if strSize s <= 8 then ()
    else let val limit = maxBits()
         in if strSize s <= limit div 8 then ()
            else if strSize s > limit div 8 + 1 then checkBits(limit+1)
            else checkBits(magBits s) end
  fun smallMag n =
    let val out = RuneBytes.new (smallBytes,0)
        fun loop (x,i) = if x = 0 then RuneBytes.extract (out,0,i)
          else let val r = intRem (x,256)
               in bput (out,i,if r < 0 then ~r else r); loop (intQuot(x,256),i+1) end
    in loop (n,0) end
  fun magnitude x = #2 (parts x)
  fun negative x = ltI (x,zero)
  fun isZero x = x = zero

  (* The workspace is a little-endian array plus its significant length. *)
  fun trim (a,n) = if n > 0 andalso at(a,n-1) = 0 then trim(a,n-1) else (a,n)
  val unpackBytes = _prim "intinf_unpack" : string * limb -> limb array
  val packBytes = _prim "intinf_pack" : limb array * limb * limb -> string
  fun unpack s = let val a = unpackBytes(s,limbBits) in trim(a,alen a) end
  fun pack (a,n) =
    let val (a,n) = trim(a,n)
        val () = if n = 0 orelse n <= maxBits() div limbBits then ()
                 else checkBits((n-1)*limbBits+digitBits(at(a,n-1)))
    in packBytes(a,n,limbBits) end
  fun carryDigits (a,n,c) =
    if c = 0 then (a,n)
    else let val r = anew(n+1,0)
             fun copy i = if i = n then put(r,n,c)
                          else (put(r,i,at(a,i)); copy(i+1))
             val () = copy 0
         in (r,n+1) end
  val smallLimbs = (machineBits+limbBits-1) div limbBits
  val smallLimbTop = pow2 ((machineBits-1) mod limbBits)
  (* A small scratch result never needs an intermediate packed string.
     Runtime budgets are at least 64 bits and cover every supported small int. *)
  fun finish (neg,work) =
    let val (a,n) = trim work
        fun lowZero i = i < 0 orelse (at(a,i) = 0 andalso lowZero(i-1))
        fun fits () = n < smallLimbs orelse at(a,n-1) < smallLimbTop orelse
          (neg andalso at(a,n-1) = smallLimbTop andalso lowZero(n-2))
        fun small(i,v) = if i < 0 then fromInt v else
          small(i-1,if neg then v*base-at(a,i) else v*base+at(a,i))
    in if n = 0 then zero
       else if n <= smallLimbs andalso fits() then small(n-1,0)
       else make(neg,pack(a,n)) end
  fun scale ((a,n),d) =
    let val r = anew(n+1,0)
        fun loop(i,c) = if i = n then put(r,n,c)
          else let val v = at(a,i)*d+c
               in put(r,i,v mod base); loop(i+1,v div base) end
        val () = loop(0,0)
    in (r,n) end
  fun absI x = if negative x then negI x else x
  fun sign x = case compare (x,zero) of LESS => ~1 | EQUAL => 0 | GREATER => 1
  (* one division, and the remainder of it *)
  fun quotRemI (a,b) = let val q = quotI (a,b) in (q,subI (a,mulI (q,b))) end
  fun divModI (a,b) = let val q = divI (a,b) in (q,subI (a,mulI (q,b))) end
  fun pow (x,n) =
    if n < 0 then if isZero x then raise Div
      else if x = one then one
      else if x = minusOne then (if intRem(n,2) = 0 then one else x)
      else zero
    else if n = 0 then one
    else if isZero x orelse x = one then x
    else if x = minusOne then (if n mod 2 = 0 then one else x)
    else let val m = magnitude x
             val bits = magBits m
             val limit = maxBits()
             val () = if bits > 1 andalso n > (limit-1) div (bits-1)
                      then checkBits(limit+1) else ()
             fun loop(b,e,acc) =
               if e = 0 then acc
               else let val acc = if e mod 2 = 0 then acc else mulI(acc,b)
                    in if e = 1 then acc else loop(mulI(b,b),e div 2,acc) end
         in if gmpAvailable() then make(gmpPower(negative x,m,n)) else loop(x,n,one) end

  val decimalChunk = if limbBits = 30 then 1000000000 else 10000
  val decimalDigits = if limbBits = 30 then 9 else 4
  (* Only this private copy is overwritten. Keeping one quotient workspace
     avoids quadratic temporary allocation while extracting decimal chunks. *)
  fun decimalSml s =
      let
        val (a,n) = unpack s
        fun divide (i,r) = if i < 0 then r
          else let val v = r*base+at(a,i)
               in put(a,i,v div decimalChunk); divide(i-1,v mod decimalChunk) end
        fun chunks (0,acc) = acc
          | chunks (n,acc) =
              let val r = divide(n-1,0)
              in chunks(#2(trim(a,n)),r::acc) end
        fun zeros(n,ss) = if n <= 0 then ss else zeros(n-1,"0"::ss)
        fun render(_,[]) = []
          | render(first,c::cs) =
              let val t = intToString c
                  val t = if first then t else concat(zeros(decimalDigits-strSize t,[t]))
              in t::render(false,cs) end
      in concat(render(true,chunks(n,[]))) end
  fun toString x =
    if isSmall x then intToString (toInt x)
    else let val (neg,s) = parts x
             val () = checkBits(magBits s)
             val text = if gmpAvailable() then gmpDecimal s else decimalSml s
         in if neg then "~" ^ text else text end
  fun log2 x = if sign x <= 0 then raise Domain else magBits(magnitude x)-1
  fun radixBase StringCvt.BIN = 2 | radixBase StringCvt.OCT = 8
    | radixBase StringCvt.DEC = 10 | radixBase StringCvt.HEX = 16
  fun fmt StringCvt.DEC x = toString x
    | fmt radix x =
      if isZero x then "0"
      else let val s = magnitude x
               val r = radixBase radix
               val bits = if r = 2 then 1 else if r = 8 then 3 else 4
               val digits = (magBits s+bits-1) div bits
               val prefix = if negative x then 1 else 0
               val out = RuneBytes.new(digits+prefix,0)
               val () = if prefix = 1 then bput(out,0,126) else ()
               fun loop i = if i = digits then ()
                 else let val bit = (digits-i-1)*bits
                          val pos = bit div 8 and shift = bit mod 8
                          val v = byte(s,pos) + (if pos+1 < strSize s then byte(s,pos+1)*256 else 0)
                          val d = (v div pow2 shift) mod r
                      in bput(out,i+prefix,if d < 10 then 48+d else 55+d); loop(i+1) end
               val () = loop 0
           in RuneBytes.extract(out,0,digits+prefix) end

  fun scan radix (getc : (char,'a) StringCvt.reader) src =
    let
      val r = radixBase radix
      fun digitValue c =
        let val n = ord c
            val v = if 48 <= n andalso n <= 57 then n-48
              else if 97 <= n andalso n <= 102 then n-87
              else if 65 <= n andalso n <= 70 then n-55 else 99
        in if v < r then SOME v else NONE end
      fun digitNext src = case getc src of
        SOME(c,_) => (case digitValue c of SOME _ => true | NONE => false) | NONE => false
      val src = StringCvt.skipWS getc src
      val (neg,src) = case getc src of
        SOME(#"~",rest) => (true,rest) | SOME(#"-",rest) => (true,rest)
      | SOME(#"+",rest) => (false,rest) | _ => (false,src)
      val src = if r <> 16 then src else
        case getc src of SOME(#"0",rest) =>
          (case getc rest of SOME(c,rest') =>
             if (c = #"x" orelse c = #"X") andalso digitNext rest' then rest' else src
           | NONE => src) | _ => src
      fun big (src,a,n) =
        let
          fun grow () =
            let val b = anew(alen a*2+1,0)
                fun copy i = if i = n then () else (put(b,i,at(a,i)); copy(i+1))
                val () = copy 0
            in b end
          fun more(d,rest) =
            let val () = if n = 0 then () else checkBits((n-1)*limbBits+digitBits(at(a,n-1)))
                val a = if n = alen a then grow() else a
                fun mul(i,c) = if i = n then
                    if c = 0 then n else (put(a,n,c); n+1)
                  else let val v = at(a,i)*r+c
                       in put(a,i,v mod base); mul(i+1,v div base) end
            in big(rest,a,mul(0,d)) end
        in case getc src of
             SOME(c,rest) => (case digitValue c of SOME d => more(d,rest)
                              | NONE => (make(neg,pack(a,n)),src))
           | NONE => (make(neg,pack(a,n)),src)
        end
      fun small(src,v) =
        case getc src of
          SOME(c,rest) =>
            (case digitValue c of
               SOME d =>
                 let val next = SOME(v*r+d) handle Overflow => NONE
                 in case next of SOME w => small(rest,w)
                    | NONE =>
                        let val (a,n) = unpack(smallMag v)
                            val (a,_) = scale((a,n),r)
                            fun add(i,c) = if c = 0 then ()
                              else let val t = at(a,i)+c
                                   in put(a,i,t mod base); add(i+1,t div base) end
                            val () = add(0,d)
                            val (_,n) = trim(a,n+1)
                        in big(rest,a,n) end
                 end
             | NONE => (fromInt(if neg then ~v else v),src))
        | NONE => (fromInt(if neg then ~v else v),src)
    in if digitNext src then SOME(small(src,0)) else NONE end
  fun fromString s = StringCvt.scanString (scan StringCvt.DEC) s

  val wordAnd = _prim "word_andb" : word * word -> word
  val wordOr = _prim "word_orb" : word * word -> word
  val wordXor = _prim "word_xorb" : word * word -> word
  val wordFromInt = _prim "word_from_int" : limb -> word
  val wordToInt = _prim "word_to_int" : word -> limb
  val wordToIntX = _prim "word_to_int_x" : word -> limb
  fun twosMagnitude (x,neg) =
    let val (a,n) = unpack(magnitude x)
        fun borrow i = if at(a,i) = 0 then (put(a,i,mask); borrow(i+1))
                       else put(a,i,at(a,i)-1)
        val () = if neg then borrow 0 else ()
    in if neg then trim(a,n) else (a,n) end
  fun bitwiseBig (code,f,signOf,a,b) =
    if gmpAvailable() then make(gmpBinary(code,negative a,magnitude a,negative b,magnitude b))
    else let val na = negative a and nb = negative b
        val (ma,la) = twosMagnitude(a,na)
        val (mb,lb) = twosMagnitude(b,nb)
        val n = if la > lb then la else lb
        val neg = signOf(na,nb)
        val out = if la >= lb then ma else mb
        fun get(s,len,negative,i) =
          let val b = if i < len then at(s,i) else 0
          in if negative then mask-b else b end
        fun loop(i,c) = if i = n then c
          else let val v = wordToInt(f(wordFromInt(get(ma,la,na,i)),wordFromInt(get(mb,lb,nb,i))))
                   val v = (if neg then mask-v else v)+c
               in if v >= base then (put(out,i,0); loop(i+1,1))
                  else (put(out,i,v); loop(i+1,0)) end
        val carry = loop(0,if neg then 1 else 0)
    in finish(neg,carryDigits(out,n,carry)) end
  (* Positive OR/XOR with a small operand cannot change the large value's
     top bit. Copy the unchanged high bytes and visit only the low ones. *)
  fun bitPositive (f,s,x) =
    let val () = checkMag s
    in if x = 0 then make(false,s)
       else let val n = strSize s
                val out = RuneBytes.new(n,0)
                val () = RuneBytes.blitString(s,0,out,0,n)
                fun loop(i,v) = if v = 0 then ()
                  else (bput(out,i,wordToInt(f(wordFromInt(byte(s,i)),wordFromInt(v mod 256))));
                        loop(i+1,v div 256))
                val () = loop(0,x)
            in make(false,RuneBytes.extract(out,0,n)) end
    end
  fun bitPositiveLarge (code,f,sa,sb) =
    let val () = checkMag sa
        val () = checkMag sb
    in if gmpAvailable() then make(gmpBinary(code,false,sa,false,sb))
       else let val (a,na) = unpack sa and (b,nb) = unpack sb
                val common = if na < nb then na else nb
                val out = if na >= nb then a else b
                val n = if code = 3 then common else if na >= nb then na else nb
                fun loop i = if i = common then ()
                  else (put(out,i,wordToInt(f(wordFromInt(at(a,i)),wordFromInt(at(b,i)))));
                        loop(i+1))
                val () = loop 0
            in finish(false,(out,n)) end
    end
  (* the operations are symmetric: a small operand and a large one are
     taken in either order *)
  fun bitwise (code,f,signOf) (a,b) =
    let fun mixed (x,large) =
          let val (neg,s) = parts large
          in if code <> 3 andalso not neg andalso x >= 0
             then bitPositive(f,s,x) else bitwiseBig(code,f,signOf,a,b) end
    in case (isSmall a,isSmall b) of
         (true,true) => fromInt(wordToIntX(f(wordFromInt(toInt a),wordFromInt(toInt b))))
       | (true,false) => mixed(toInt a,b)
       | (false,true) => mixed(toInt b,a)
       | (false,false) =>
           let val (na,sa) = parts a and (nb,sb) = parts b
           in if not na andalso not nb then bitPositiveLarge(code,f,sa,sb)
              else bitwiseBig(code,f,signOf,a,b) end
    end
  val andb = bitwise(3,wordAnd,fn(a,b)=>a andalso b)
  val orb = bitwise(4,wordOr,fn(a,b)=>a orelse b)
  val xorb = bitwise(5,wordXor,fn(a,b)=>a <> b)
  fun notb x = subI(negI x,one)
  fun << (x,w) =
    if w = 0w0 then x
    else if isZero x then zero
    else let val s = magnitude x
             val available = maxBits()-magBits s
             val wordGreater = _prim "word_gt" : word * word -> bool
             val () = if wordGreater(w,wordFromInt available) then checkBits(maxBits()+1) else ()
             val k = wordToInt w
             val n = strSize s
             val whole = k div 8 and bits = k mod 8
             val factor = pow2 bits
             fun smlShift () =
             let val out = RuneBytes.new(n+whole+1,0)
             fun loop(i,c) = if i = n then
                 (bput(out,i+whole,c); if c = 0 then n+whole else n+whole+1)
               else let val v = byte(s,i)*factor+c
                    in bput(out,i+whole,v mod 256); loop(i+1,v div 256) end
             val used = if bits = 0 then
                 (RuneBytes.blitString(s,0,out,whole,n); n+whole)
               else loop(0,0)
             in make(negative x,RuneBytes.extract(out,0,used)) end
         in if gmpAvailable() then make(gmpShift(true,negative x,s,w)) else smlShift() end
  fun ~>> (x,w) =
    if w = 0w0 then x
    else if isZero x then zero
    else if gmpAvailable() then make(gmpShift(false,negative x,magnitude x,w))
    else let val k = wordToInt w handle Overflow => ~1
        val neg = negative x
        val m = magnitude x
        fun shifted () =
          if k < 0 orelse k >= magBits m then if neg then minusOne else zero
          else let val (digits,n) = unpack m
                   val whole = k div limbBits and bits = k mod limbBits
                   val factor = pow2 bits
                   val highFactor = base div factor
                   fun discarded i = if i = whole then at(digits,i) mod factor <> 0
                                     else at(digits,i) <> 0 orelse discarded(i+1)
                   val roundUp = neg andalso discarded 0
                   fun loop i = if i = n-whole then ()
                     else let val low = at(digits,i+whole) div factor
                              val high = if i+whole+1 < n then at(digits,i+whole+1) mod factor else 0
                          in put(digits,i,low+high*highFactor); loop(i+1) end
                   val () = loop 0
                   fun increment i = if i = n-whole then 1
                     else if at(digits,i) = mask then (put(digits,i,0); increment(i+1))
                     else (put(digits,i,at(digits,i)+1); 0)
                   val carry = if roundUp then increment 0 else 0
               in finish(neg,carryDigits(digits,n-whole,carry)) end
    in shifted() end

  val precision : limb option = NONE
  val minInt : int option = NONE
  val maxInt : int option = NONE
  val toLarge = fn (x : int) => x
  val fromLarge = fn (x : int) => x
  val op + = addI
  val op - = subI
  val op * = mulI
  val ~ = negI
  val abs = absI
  val quotRem = quotRemI
  val divMod = divModI
  val quot = quotI
  val rem = remI
  val op div = divI
  val op mod = modI
  val op < = ltI
  val op <= = leI
  val op > = gtI
  val op >= = geI
  fun min (a,b) = if gtI(a,b) then b else a
  fun max (a,b) = if ltI(a,b) then b else a
  fun sameSign (a,b) = sign a = sign b
end

(* The largest integers are the arbitrary precision ones.

   Implements: INTEGER where type int = IntInf.int *)
structure LargeInt = IntInf

(* Integer constants and overloaded operators at IntInf.int. *)
structure RuneIntInf =
struct
  fun fromLit (digits : string) : IntInf.int =
    case IntInf.fromString digits of
      SOME i => i
    | NONE => raise Fail "RuneIntInf.fromLit"
end

_overload int IntInf via RuneIntInf.fromLit
