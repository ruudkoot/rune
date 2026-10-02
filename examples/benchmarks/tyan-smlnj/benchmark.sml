structure Log=struct fun print (_:string)=() fun say (_:string list)=()fun flush()=()end
(* util.sml
 *
 * COPYRIGHT (c) 2026 The Fellowship of SML/NJ (https://smlnj.org)
 * All rights reserved.
 *)

structure Util = struct
    exception NotImplemented of string
    exception Impossible of string (* flag "impossible" condition  *)
    exception Illegal of string (* flag function use violating precondition *)

    fun error exn msg = raise (exn msg)
    fun notImplemented msg = error NotImplemented msg
    fun impossible msg = error Impossible msg
    fun illegal msg = error Illegal msg

    (* arr[i] := obj :: arr[i]; extend non-empty arr if necessary *)
    fun insert (obj,i,arr) = let
          val len = Array.length arr
          val res =  if i<len then (Array.update(arr,i,obj::Array.sub(arr,i)); arr)
             else let val arr' = Array.array(Int.max(i+1,len+len),[])
                      fun copy ~1 = (Array.update(arr',i,[obj]); arr')
                        | copy j = (Array.update(arr',j,Array.sub(arr,j));
                                    copy(j-1))
                      in copy(len-1) end
          in res
          end

    (* given compare and array a, return list of contents of a sorted in
     * ascending order, with duplicates stripped out; which copy of a duplicate
     * remains is random.  NOTE that a is modified.
     *)
    fun stripSort compare = fn a => let
          infix sub


          val op sub = Array.sub and update = Array.update
          fun swap (i,j) = let val ai = a sub i
                           in update(a,i,a sub j); update(a,j,ai) end
          (* sort all a[k], 0<=i<=k<j<=length a *)
          fun s (i,j,acc) = if i=j then acc else let
                val pivot = a sub ((i+j) div 2)
                fun partition (lo,k,hi) = if k=hi then (lo,hi) else
                      case compare (pivot,a sub k) of
                          LESS => (swap (lo,k); partition (lo+1,k+1,hi))
                        | EQUAL => partition (lo,k+1,hi)
                        | GREATER => (swap (k,hi-1); partition (lo,k,hi-1))
                val (lo,hi) = partition (i,i,j)
                in s(i,lo,pivot::s(hi,j,acc)) end
           val res = s(0,Array.length a,[])

          in
           res
          end
end

(* f.sml
 *
 * COPYRIGHT (c) 2026 The Fellowship of SML/NJ (https://smlnj.org)
 * All rights reserved.
 *)

structure F = struct

    val p = 17

    datatype field = F of int (* for (F n), always 0<=n<p *)

    (* exception Div = Integer.Div *)
(* unused code unless P.show, commented out in earlier version, is used
    fun show (F x) = Log.print (Int.toString x)
*)
(* unused code
    val char = p
*)

(* unused code unless P.display is used
    val zero = F 0
*)
    val one = F 1
    fun coerceInt n = F (n mod p)

    fun add (F n,F m) = let val k = n+m in if k>=p then F(k-p) else F k end
    fun subtract (F n,F m) = if n>=m then F(n-m) else F(n-m+p)
    fun negate (F 0) = F 0 | negate (F n) = F(p-n)
    fun multiply (F n,F m) = F ((n*m) mod p)
    fun reciprocal (F 0) = raise Div
      | reciprocal (F n) = let
          (* consider euclid gcd alg on (a,b) starting with a=p, b=n.
           * if maintain a = a1 n + a2 p, b = b1 n + b2 p, a>b,
           * then when 1 = a = a1 n + a2 p, have a1 = inverse of n mod p
           * note that it is not necessary to keep a2, b2 around.
           *)
          fun gcd ((a,a1),(b,b1)) =
              if b=1 then (* by continued fraction expansion, 0<|b1|<p *)
                 if b1<0 then F(p+b1) else F b1
              else let val q = a div b
                   in gcd((b,b1),(a-q*b,a1-q*b1)) end
          in gcd ((p,0),(n,1)) end
(* unused code
    fun divide (n,m) = multiply (n, reciprocal m)
*)

(* unused code unless power is used
    val andb = op &&
    val rshift = op >>
*)

(* unused code
    fun power(n,k) =
          if k<=3 then case k of
              0 => one
            | 1 => n
            | 2 => multiply(n,n)
            | 3 => multiply(n,multiply(n,n))
            | _ => reciprocal (power (n,~k)) (* know k<0 *)
          else if andb(k,1)=0 then power(multiply(n,n),rshift(k,1))
               else multiply(n,power(multiply(n,n),rshift(k,1)))
*)

    fun isZero (F n) = n=0
(* unused codeunless P.display is used
    fun equal (F n,F m) = n=m

    fun display (F n) = if n<=p div 2 then Int.toString n
                        else "-" ^ Int.toString (p-n)
*)
end

(* m.sml
 *
 * COPYRIGHT (c) 2026 The Fellowship of SML/NJ (https://smlnj.org)
 * All rights reserved.
 *)

structure M = struct (* MONO *)
    local
        val andb = fn (i1, i2) => (Word.toInt (Word.andb (Word.fromInt (i1), Word.fromInt (i2))))
        val op << = fn (i1, i2) => (Word.toInt (Word.<< (Word.fromInt (i1), Word.fromInt (i2))))
        val op >> = fn (i1, i2) => (Word.toInt (Word.>> (Word.fromInt (i1), Word.fromInt (i2))))
        infix << >> andb
    in

(* encode (var,pwr) as a long word: hi word is var, lo word is pwr
   masks 0xffff for pwr, mask ~0x10000 for var, rshift 16 for var
   note that encoded pairs u, v have same var if u>=v, u andb ~0x10000<v
*)

    datatype mono = M of int list
    exception DoesntDivide

    val one = M []
    fun x_i v = M [(v<<16)+1]
    fun explode (M l) = List.map (fn v => (v>>16,v andb 65535)) l
    fun implode l = M (List.map (fn (v,p) => (v<<16)+p) l)

    val deg = let fun d([],n) = n | d(u::ul,n) = d(ul,(u andb 65535) + n)
              in fn (M l) => d(l,0) end

    (* x^k > y^l if x>k or x=y and k>l *)
    val compare = let
          fun cmp ([],[]) = EQUAL
            | cmp (_::_,[]) = GREATER
            | cmp ([],_::_) = LESS
            | cmp ((u::us), (v::vs)) = if u=v then cmp (us,vs)
                                  else if u<v then LESS
                                  else (* u>v *)   GREATER
          in fn (M m,M m') => cmp(m,m') end

    fun display (M (l : int list)) : string =
      let
        fun dv v = if v<26 then chr (v+ord #"a") else chr (v-26+ord #"A")
        fun d (vv,acc) = let val v = vv>>16 and p = vv andb 65535
                         in if p=1 then dv v::acc
                            else
                              (dv v)::(String.explode (Int.toString p)) @ acc
                         end
      in String.implode(List.foldl d [] l) end

    val multiply = let
          fun mul ([],m) = m
            | mul (m,[]) = m
            | mul (u::us, v::vs) = let
                val uu = u andb ~65536
                in if uu = (v andb ~65536) then let
                      val w = u + (v andb 65535)
                      in if uu = (w andb ~65536) then w::mul(us,vs)
                         else
                           (Util.illegal
                            (String.concat ["Mono.multiply overflow: ",
                                            display (M(u::us)),", ",
                                            display (M(v::vs))]))
                      end
                   else if u>v then u :: mul(us,v::vs)
                   else (* u<v *) v :: mul(u::us,vs)
                end
          in fn (M m,M m') => M (mul (m,m')) end

    val lcm = let
          fun lcm ([],m) = m
            | lcm (m,[]) = m
            | lcm (u::us, v::vs) =
                if u>=v then if (u andb ~65536)<v then u::lcm(us,vs)
                                                    else u::lcm(us,v::vs)
                        else if (v andb ~65536)<u then v::lcm(us,vs)
                                                    else v::lcm(u::us,vs)
          in fn (M m,M m') => M (lcm (m,m')) end
    val tryDivide = let
          fun rev([],l) = l | rev(x::xs,l)=rev(xs,x::l)
          fun d (m,[],q) = SOME(M(rev(q,m)))
            | d ([],_::_,_) = NONE
            | d (u::us,v::vs,q) =
                if u<v then NONE
                else if (u andb ~65536) = (v andb ~65536) then
                    if u=v then d(us,vs,q) else d(us,vs,u-(v andb 65535)::q)
                else d(us,v::vs,u::q)
          in fn (M m,M m') => d (m,m',[]) end
    fun divide (m,m') =
          case tryDivide(m,m') of SOME q => q | NONE => raise DoesntDivide

end end (* local, structure M *)

(* p.sml
 *
 * COPYRIGHT (c) 2026 The Fellowship of SML/NJ (https://smlnj.org)
 * All rights reserved.
 *)

structure P = struct

    datatype poly = P of (F.field*M.mono) list (* descending mono order *)
    val zero = P []
    fun coerce (a,m) = P [(a,m)]
    fun implode p = P p
    fun cons (am,P p) = P (am::p)

    val op >> = fn (i1, i2) => (Word.toInt (Word.>> (Word.fromInt (i1), Word.fromInt (i2))))
    infix >>

    val log = let fun log(n,l) = if n<=1 then l else log((n >> 1),1+l)
              in fn n => log(n,0) end
    val maxLeft = ref 0
    val maxRight = ref 0
    val counts = Array.tabulate(20,fn _ => Array.array(20,0))
    val indices = [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19]

    fun pair(l,r) = let
          val l = log l and r = log r
          val _ = maxLeft := Int.max(!maxLeft,l) and _ = maxRight := Int.max(!maxRight,r)
          val a = Array.sub(counts,l)
          in Array.update(a,r,Array.sub(a,r)+1) end

local
    fun neg p = (List.map (fn (a,m) => (F.negate a,m)) p)
    fun plus ([],p2) = p2
      | plus (p1,[]) = p1
      | plus ((a,m)::ms,(b,n)::ns) = case M.compare(m,n) of
            LESS => (b,n) :: plus ((a,m)::ms,ns)
          | GREATER => (a,m) :: plus (ms,(b,n)::ns)
          | EQUAL => let val c = F.add(a,b)
                             in if F.isZero c then plus(ms,ns)
                                else (c,m)::plus(ms,ns)
                             end
    fun minus ([],p2) = neg p2
      | minus (p1,[]) = p1
      | minus ((a,m)::ms,(b,n)::ns) = case M.compare(m,n) of
            LESS => (F.negate b,n) :: minus ((a,m)::ms,ns)
          | GREATER => (a,m) :: minus (ms,(b,n)::ns)
          | EQUAL => let val c = F.subtract(a,b)
                             in if F.isZero c then minus(ms,ns)
                                else (c,m)::minus(ms,ns)
                             end
    fun termMult (a,m,p) =
          (List.map (fn (a',m') => (F.multiply(a,a'),M.multiply(m,m'))) p)
in
    fun add (P p1,P p2) = (pair(length p1,length p2); P (plus(p1,p2)))
    fun subtract (P p1,P p2) = (pair(length p1,length p2); P (minus(p1,p2)))

    fun spair (a,m,P f,b,n,P g) =
      (pair(length f,length g); P(minus(termMult(a,m,f),termMult(b,n,g))))
    val termMult = fn (a,m,P f) => P(termMult(a,m,f))
end

    fun scalarMult (a,P p) = P (List.map (fn (b,m) => (F.multiply(a,b),m)) p)

    fun isZero (P []) = true | isZero (P (_::_)) = false

    (* these should only be called if there is a leading term, i.e. poly<>0 *)
    fun leadMono (P((_,m)::_)) = m
      | leadMono (P []) = Util.illegal "POLY.leadMono"
    fun leadCoeff (P((a,_)::_)) = a
      | leadCoeff (P []) = Util.illegal "POLY.leadCoeff"
    fun rest (P (_::p)) = P p
      | rest (P []) = Util.illegal "POLY.rest"
    fun leadAndRest (P (lead::rest)) = (lead,P rest)
      | leadAndRest (P []) = Util.illegal "POLY.leadAndRest"

    fun deg (P []) = Util.illegal "POLY.deg on zero poly"
      | deg (P ((_,m)::_)) = M.deg m (* homogeneous poly *)
    fun numTerms (P p) = length p

end


(* hp.sml
 *
 * COPYRIGHT (c) 2026 The Fellowship of SML/NJ (https://smlnj.org)
 * All rights reserved.
 *)

structure HP = struct
    datatype hpoly = HP of P.poly array
    val op >> = fn (i1, i2) => (Word.toInt (Word.>> (Word.fromInt (i1), Word.fromInt (i2))))
    infix >>
    val log = let
          fun log(n,l) = if n<8 then l else log((n >> 2),1+l)
          in fn n => log(n,0) end
    fun mkHPoly p = let
          val l = log(P.numTerms p)
          in HP(Array.tabulate(l+1,fn i => if i=l then p else P.zero)) end
    fun add(p,HP ps) = let
          val l = log(P.numTerms p)
          in if l>=Array.length ps then let
               val n = Array.length ps
               in HP(Array.tabulate(n+n,
                     fn i => if i<n then Array.sub(ps,i)
                             else if i=l then p else P.zero))
               end
             else let
               val p = P.add(p,Array.sub(ps,l))
               in if l=log(P.numTerms p) then (Array.update(ps,l,p); HP ps)
                  else (Array.update(ps,l,P.zero); add (p,HP ps))
               end
          end
    fun leadAndRest (HP ps) = let
          val n = Array.length ps
          fun lar (m,indices,i) = if i>=n then lar'(m,indices) else let
                val p = Array.sub(ps,i)
                in if P.isZero p then lar(m,indices,i+1)
                   else if null indices then lar(P.leadMono p,[i],i+1)
                        else case M.compare(m,P.leadMono p) of
                            LESS => lar(P.leadMono p,[i],i+1)
                          | EQUAL => lar(m,i::indices,i+1)
                          | GREATER => lar(m,indices,i+1)
                end
          and lar' (_,[]) = NONE
            | lar' (m,i::is) = let
                fun extract i = case P.leadAndRest(Array.sub(ps,i)) of
                      ((a,_),rest) => (Array.update(ps,i,rest); a)
                val a = List.foldr (fn (j,b) => F.add(extract j,b)) (extract i) is
                in if F.isZero a then lar(M.one,[],0) else SOME(a,m,HP ps)
                end
          in lar(M.one,[],0) end
  end

(* mi.sml
 *
 * COPYRIGHT (c) 2026 The Fellowship of SML/NJ (https://smlnj.org)
 * All rights reserved.
 *)

structure MI = struct (* MONO_IDEAL *)

    (* trie:
     * index first by increasing order of vars
     * children listed in increasing degree order
     *)
    datatype 'a mono_trie = MT of 'a option * (int * 'a mono_trie) list
                            (* tag, encoded (var,pwr) and children *)
    datatype 'a mono_ideal = MI of (int * 'a mono_trie) ref
                            (* int maxDegree = least degree > all elements *)

    val op && = fn (i1, i2) => (Word.toInt (Word.andb (Word.fromInt (i1), Word.fromInt (i2))))
    val op << = fn (i1, i2) => (Word.toInt (Word.<< (Word.fromInt (i1), Word.fromInt (i2))))
    infix && <<

    fun rev ([],l) = l | rev (x::xs,l) = rev(xs,x::l)
    val emptyTrie = MT(NONE,[])
    fun mkEmpty () = MI(ref (0,emptyTrie))

    val lshift = op <<
    val andb = op &&

    fun encode (var,pwr) = lshift(var,16)+pwr
    fun grabVar vp = andb(vp,~65536)
    fun grabPwr vp = andb(vp,65535)
    fun smallerVar (vp,vp') = vp < andb(vp',~65536)

    exception Found
    fun search (MI(x),M.M m') = let
          val (d,mt) = !x
          val result = ref NONE
          (* exception Found of M.mono * '_a *)
          (* s works on remaining input mono, current output mono, tag, trie *)
          fun s (_,m,MT(SOME a,_)) =
                raise(result := SOME (M.M m,a); Found)
            | s (m',m,MT(NONE,trie)) = s'(m',m,trie)
          and s'([],_,_) = NONE
            | s'(_,_,[]) = NONE
            | s'(vp'::m',m,trie as (vp,child)::children) =
                if smallerVar(vp',vp) then s'(m',m,trie)
                else if grabPwr vp = 0 then (s(vp'::m',m,child);
                                             s'(vp'::m',m,children))
                else if smallerVar(vp,vp') then NONE
                else if vp<=vp' then (s(m',vp::m,child);
                                      s'(vp'::m',m,children))
                else NONE
          in s(rev(m',[]),[],mt)
             handle Found (* (m,a) => SOME(m,a) *) => !result
          end

   (* assume m is a new generator, i.e. not a multiple of an existing one *)
    fun insert (MI (mi),m,a) = let
          val (d,mt) = !mi
          fun i ([],MT (SOME _,_)) = Util.illegal "MONO_IDEAL.insert duplicate"
            | i ([],MT (NONE,children)) = MT(SOME a,children)
            | i (vp::m,MT(a',[])) = MT(a',[(vp,i(m,emptyTrie))])
            | i (vp::m,mt as MT(a',trie as (vp',_)::_)) = let
                fun j [] = [(vp,i(m,emptyTrie))]
                  | j ((vp',child)::children) =
                      if vp<vp' then (vp,i(m,emptyTrie))::(vp',child)::children
                      else if vp=vp' then (vp',i(m,child))::children
                      else (vp',child) :: j children
                in
                   if smallerVar(vp,vp') then
                       MT(a',[(grabVar vp,MT(NONE,trie)),(vp,i(m,emptyTrie))])
                   else if smallerVar(vp',vp) then i(grabVar vp'::vp::m,mt)
                   else MT(a',j trie)
                end
          in mi := (Int.max(d,M.deg m),i (rev(List.map encode(M.explode m),[]),mt)) end

    fun mkIdeal [] = mkEmpty()
      | mkIdeal (orig_ms : (M.mono * '_a) list)= let
          fun ins ((m,a),arr) = Util.insert((m,a),M.deg m,arr)
          val msa = Array.fromList orig_ms
          val ms : (M.mono * '_a) list =
              Util.stripSort (fn ((m,_),(m',_)) => M.compare (m,m')) msa
          val buckets = List.foldr ins (Array.array(0,[])) ms
          val n = Array.length buckets
          val mi = mkEmpty()
          fun sort i = if i>=n then mi else let
                fun redundant (m,_) = case search(mi,m) of NONE => false
                                                         | SOME _ => true
                fun filter ([],l) = List.app (fn (m,a) => insert(mi,m,a)) l
                  | filter (x::xx,l) = if redundant x then filter(xx,l)
                                       else filter(xx,x::l)
                in filter(Array.sub(buckets,i),[]);
                   Array.update(buckets,i,[]);
                   sort(i+1)
                end
          in sort 0 end

    fun fold g (MI(x)) init = let
          val (_,mt) = !x
          fun f(acc,m,MT(NONE,children)) = f'(acc,m,children)
            | f(acc,m,MT(SOME a,children)) =
                f'(g((M.M m,a),acc),m,children)
          and f'(acc,m,[]) = acc
            | f'(acc,m,(vp,child)::children) =
                if grabPwr vp=0 then f'(f(acc,m,child),m,children)
                else f'(f(acc,vp::m,child),m,children)
          in f(init,[],mt) end

end (* structure MI *)

(* g.sml
 *
 * COPYRIGHT (c) 2026 The Fellowship of SML/NJ (https://smlnj.org)
 * All rights reserved.
 *)

structure G = struct
    val autoReduce = ref true
    val maxDeg = ref 10000
    val maybePairs = ref 0
    val primePairs = ref 0
    val usedPairs = ref 0
    val newGens = ref 0

    val op && = fn (i1, i2) => (Word.toInt (Word.andb (Word.fromInt (i1), Word.fromInt (i2))))
    infix &&

    fun reset () = (maybePairs:=0; primePairs:=0; usedPairs:=0; newGens:=0)

    fun inc r = r := !r + 1

    fun reduce (f,mi) = if P.isZero f then f else let
          (* use accumulator and reverse at end? *)
          fun r hp = case HP.leadAndRest hp of
                NONE => []
              | (SOME(a,m,hp)) => case MI.search(mi,m) of
                    NONE => (a,m)::(r hp)
                  | SOME (m',p) => r (HP.add(P.termMult(F.negate a,M.divide(m,m'),!p),hp))
          in P.implode(r (HP.mkHPoly f)) end

    (* assume f<>0 *)
    fun mkMonic f = P.scalarMult(F.reciprocal(P.leadCoeff f),f)

    (* given monic h, a monomial ideal mi of m's tagged with g's representing
     * an ideal (g1,...,gn): a poly g is represented as (lead mono m,rest of g).
     * update pairs to include new s-pairs induced by h on g's:
     * 1) compute minimal gi1...gik so that <gij:h's> generate <gi:h's>, i.e.
     *    compute monomial ideal for gi:h's tagged with gi
     * 2) toss out gij's whose lead mono is rel. prime to h's lead mono (why?)
     * 3) put (h,gij) pairs into degree buckets: for h,gij with lead mono's m,m'
     *    deg(h,gij) = deg lcm(m,m') = deg (lcm/m) + deg m = deg (m':m) + deg m
     * 4) store list of pairs (h,g1),...,(h,gn) as vector (h,g1,...,gn)
     *)
    fun addPairs (h,mi,pairs) = let
          val m = P.leadMono h
          val d = M.deg m
          fun tag ((m' : M.mono,g' : P.poly ref),quots) = (inc maybePairs;
                                     (M.divide(M.lcm(m,m'),m),(m',!g'))::quots)
          fun insert ((mm,(m',g')),arr) = (* recall mm = m':m *)
                if M.compare(m',mm)=EQUAL then (* rel. prime *)
                    (inc primePairs; arr)
                else (inc usedPairs;
                      Util.insert(P.cons((F.one,m'),g'),M.deg mm+d,arr))
          val buckets = MI.fold insert (MI.mkIdeal (MI.fold tag mi []))
                                       (Array.array(0,[]))
          fun ins (~1,pairs) = pairs
            | ins (i,pairs) = case Array.sub(buckets,i) of
                    [] => ins(i-1,pairs)
                  | gs => ins(i-1,Util.insert(Array.fromList(h::gs),i,pairs))
          in ins(Array.length buckets - 1,pairs) end

    fun grobner fs = let
          fun pr l = Log.say (l@["\n"])
          val fs = List.foldr
                (fn (f,fs) => Util.insert(f,P.deg f,fs))
                (Array.array(0,[])) fs
          (* pairs at least as long as fs, so done when done w/ all pairs *)
          val pairs = ref(Array.array(Array.length fs,[]))
          val mi = MI.mkEmpty()
          val newDegGens = ref []
          val addGen = (* add and maybe auto-reduce new monic generator h *)
                if not(!autoReduce) then
                    fn h => MI.insert (mi,P.leadMono h,ref (P.rest h))
                else fn h => let
                    val ((_,m),rh) = P.leadAndRest h
                    fun autoReduce f =
                          if P.isZero f then f
                          else let val ((a,m'),rf) = P.leadAndRest f
                               in case M.compare(m,m') of
                                   LESS => P.cons((a,m'),autoReduce rf)
                                 | EQUAL => P.subtract(rf,P.scalarMult(a,rh))
                                 | GREATER => f
                               end
                    val rrh = ref rh
                    in
                        MI.insert (mi,P.leadMono h,rrh);
                        List.app (fn f => f:=autoReduce(!f)) (!newDegGens);
                        newDegGens := rrh :: !newDegGens
                    end
          val tasksleft = ref 0
          fun feedback () = let
                val n = !tasksleft
                in
                    if (n && 15)=0 then Log.print (Int.toString n) else ();
                        Log.print ".";
                        Log.flush();
                        tasksleft := n-1
                end

          fun try h =
              let
                  val _ = feedback ()
                  val h = reduce(h,mi)
              in if P.isZero h
                     then ()
                 else let val h = mkMonic h
                          val _ = (Log.print "#"; Log.flush())
                      in pairs := addPairs(h,mi,!pairs);
                          addGen h;
                          inc newGens
                      end
              end

          fun tryPairs fgs = let
                val ((a,m),f) = P.leadAndRest (Array.sub(fgs,0))
                fun tryPair i = if i=0 then () else let
                      val ((b,n),g) = P.leadAndRest (Array.sub(fgs,i))
                      val k = M.lcm(m,n)
                      in
                         try (P.spair(b,M.divide(k,m),f,a,M.divide(k,n),g));
                         tryPair (i-1)
                      end
                in tryPair (Array.length fgs -1) end

          fun numPairs ([],n) = n
            | numPairs (p::ps,n) = numPairs(ps,n-1+Array.length p)

          fun gb d = if d>=Array.length(!pairs) then mi else
                (* note: i nullify entries to reclaim space *)
                (
pr ["DEGREE ",Int.toString d," with ",
    Int.toString(numPairs(Array.sub(!pairs,d),0))," pairs ",
    if d>=Array.length fs then "0" else Int.toString(length(Array.sub(fs,d))),
      " generators to do"];
                 tasksleft := numPairs(Array.sub(!pairs,d),0);
                 if d>=Array.length fs then ()
                 else tasksleft := !tasksleft + length (Array.sub(fs,d));
                   if d>(!maxDeg) then ()
                   else (
                         reset();
                         newDegGens := [];
                         List.app tryPairs (Array.sub(!pairs,d));
                         Array.update(!pairs,d,[]);
                         if d>=Array.length fs then ()
                         else (List.app try (Array.sub(fs,d)); Array.update(fs,d,[]));
                           pr ["maybe ",Int.toString(!maybePairs)," prime ",
                               Int.toString (!primePairs),
                               " using ",Int.toString (!usedPairs),
                               "; found ",Int.toString (!newGens)]
                           );
                 gb(d+1)
                )
          in gb 0 end

local
    (* grammar:
     dig  ::= 0 | ... | 9
     var  ::= a | ... | z | A | ... | Z
     sign ::= + | -
     nat  ::= dig | nat dig
     mono ::=  | var mono | var num mono
     term ::= nat mono | mono
     poly ::= term | sign term | poly sign term
    *)
    datatype char = Dig of int | Var of int | Sign of int
    fun char ch =
        let val och = ord ch in
          if ord #"0"<=och andalso och<=ord #"9" then Dig (och - ord #"0")
          else if ord #"a"<=och andalso och<=ord #"z" then Var (och - ord #"a")
          else if ord #"A"<=och andalso och<=ord #"Z" then Var (och - ord #"A" + 26)
          else if och = ord #"+" then Sign 1
          else if och = ord #"-" then Sign ~1
               else Util.illegal ("bad ch in poly: " ^ (Char.toString(ch)))
        end

    fun nat (n,Dig d::l) = nat(n*10+d,l) | nat (n,l) = (n,l)
    fun mono (m,Var v::Dig d::l) =
          let val (n,l) = nat(d,l)
          in mono(M.multiply(M.implode[(v,n)],m),l) end
      | mono (m,Var v::l) = mono(M.multiply(M.x_i v,m),l)
      | mono (m,l) = (m,l)

    fun term l = let
          val (n,l) = case l of (Dig d::l) => nat(d,l) | _ => (1,l)
          val (m,l) = mono(M.one,l)
          in ((F.coerceInt n,m),l) end
    fun poly (p,[]) = p
      | poly (p,l) = let
          val (s,l) = case l of Sign s::l => (F.coerceInt s,l) | _ => (F.one,l)
          val ((a,m),l) = term l
          in poly(P.add(P.coerce(F.multiply(s,a),m),p),l) end

in
    fun parsePoly s = poly (P.zero,List.map char(String.explode s))

end (* local *)

end (* structure G *)

structure Benchmark=struct val name="tyan-smlnj"
fun run [reps]=let val r=BenchInput.between(1,192)(BenchInput.integer reps)
val _=G.maxDeg:=1000000 val _=BenchOutput.reset()
val u6=List.map G.parsePoly["abcdef-g6","a+b+c+d+e+f","ab+bc+cd+de+ef+fa","abc+bcd+cde+def+efa+fab","abcd+bcde+cdef+defa+efab+fabc","abcde+bcdef+cdefa+defab+efabc+fabcd"]
fun one()=let val ideal=G.grobner u6
val polynomials=MI.fold(fn((m,g),l)=>P.cons((F.one,m),!g)::l)ideal[]
fun info f=BenchOutput.put(M.display(P.leadMono f)^" + "^Int.toString(P.numTerms f-1)^" terms\n")
in List.app info polynomials end
fun loop 0=()|loop n=(one();loop(n-1))val _=loop r
in BenchOutput.summary()end |run _=raise Fail "Tyan expects u6 repetitions"end
