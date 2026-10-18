(* Selected OCaml 4.14.1 Hashtbl/hash operations, Xavier Leroy / INRIA,
 * LGPL 2.1 with linking exception. Exact notices accompany the source.
 * The source memo bound permits at most 1001 bindings in 1024 buckets;
 * no resizing/traversal operation is reachable in this fragment. *)
structure BenchSauvolaHash=
struct
 structure H=BenchStdlibHash
 val fractionUnit=valOf(IntInf.fromString"4503599627370496")
 val wordUnit=valOf(IntInf.fromString"4294967296")
 (* PACK_REAL optional structure names differ between supported hosts.
  * Reconstruct the binary64 words with one common SML97 arithmetic algorithm.
  * Conversion truncates an exactly integral scaled significand. *)
 fun words value=
   if Real.isNan value then(0wx7FF00000,0w1)
   else if Real.==(value,0.0)then(0w0,0w0)
   else
     let val sign:Word32.word=if Real.signBit value then 0wx80000000 else 0w0
     in if not(Real.isFinite value)then(Word32.orb(sign,0wx7FF00000),0w0)
        else
          let val magnitude=Real.abs value
              val{man,exp}=Real.toManExp magnitude
              val biased=exp+1022
              val fraction=if biased<=0 then
                    Real.toLargeInt IEEEReal.TO_ZERO(magnitude*4.4942328371557898E307*4503599627370496.0)
                  else IntInf.-(Real.toLargeInt IEEEReal.TO_ZERO(man*9007199254740992.0),fractionUnit)
              val highFraction=Word32.fromInt(IntInf.toInt(IntInf.quot(fraction,wordUnit)))
              val low=Word32.fromLargeInt(IntInf.mod(fraction,wordUnit))
              val high=Word32.orb(sign,Word32.orb(highFraction,
                    Word32.<<(Word32.fromInt(Int.max(0,biased)),0w20)))
          in(high,low)end
     end
 fun real state value=
   let val(high,low)=words value
   in H.mix(H.mix state low)high end
 fun pairReal(a,b)=H.finish(real(real(H.mix 0w0 0w2048)a)b)
 fun pairInt pair=H.pair pair
 fun equalReal(a,b)=Real.==(a,b)orelse(Real.isNan a andalso Real.isNan b)
end
functor BenchSauvolaMemoFn(Key:sig
 type key
 val hash:key->int
 val equal:key*key->bool
end)=
struct
 datatype 'a bucket=Empty|Cons of Key.key*'a*'a bucket
 type 'a table={buckets:'a bucket Array.array,size:int ref}
 exception NotFound
 fun create(): 'a table={buckets=Array.array(1024,Empty),size=ref 0}
 fun index key=Key.hash key mod 1024
 fun find({buckets,...}:'a table)key=
   let fun rest Empty=raise NotFound
         |rest(Cons(k,value,next))=if Key.equal(key,k)then value else rest next
   in case Array.sub(buckets,index key)of Empty=>raise NotFound
    |Cons(k1,v1,n1)=>if Key.equal(key,k1)then v1 else
      case n1 of Empty=>raise NotFound
      |Cons(k2,v2,n2)=>if Key.equal(key,k2)then v2 else
        case n2 of Empty=>raise NotFound
        |Cons(k3,v3,n3)=>if Key.equal(key,k3)then v3 else rest n3
   end
 fun clear({buckets,size}:'a table)=
   let fun loop i=if i=1024 then()else(Array.update(buckets,i,Empty);loop(i+1))
   in if !size>0 then(size:=0;loop 0)else()end
 fun add({buckets,size}:'a table)key value=
   let val slot=index key
   in Array.update(buckets,slot,Cons(key,value,Array.sub(buckets,slot)));size:= !size+1 end
 fun memo f=
   let val table=create()
   in fn key=>find table key handle NotFound=>
      (if !(#size table)>1000 then clear table else();
       let val value=f key val _=add table key value in value end)end
end
structure BenchSauvolaRealMemo=BenchSauvolaMemoFn(struct
 type key=real*real
 val hash=BenchSauvolaHash.pairReal
 fun equal((a,b),(c,d))=BenchSauvolaHash.equalReal(a,c)andalso BenchSauvolaHash.equalReal(b,d)
end)
structure BenchSauvolaIntMemo=BenchSauvolaMemoFn(struct
 type key=int*int
 val hash=BenchSauvolaHash.pairInt
 fun equal((a,b),(c,d))=a=c andalso b=d
end)
