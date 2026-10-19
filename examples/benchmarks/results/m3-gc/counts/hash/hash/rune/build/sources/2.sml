structure Benchmark =
struct
  val name="hash"
  type table={count:int,mask:int,buckets:(int*int)list array}
  fun hash key=key+Word64.toInt(Word64.>>(Word64.*(Word64.fromInt key,0w1013904242),0w32))
  fun index mask key=Word.toInt(Word.andb(Word.fromInt(hash key),Word.fromInt mask))
  fun new() : table ref=ref{count=0,mask=7,buckets=Array.array(8,[])}
  fun resize({count,mask,buckets}:table)=
    let val next=2*mask+1
    in if next>33554431 then{count=count,mask=mask,buckets=buckets}else
      let val target=Array.array(next+1,[])
          fun split i=if i>mask then()else
            let val(low,high)=List.partition(fn(k,_)=>index next k=i)(Array.sub(buckets,i))
                val _=Array.update(target,i,low)val _=Array.update(target,i+mask+1,high)
            in split(i+1)end
          val _=split 0
      in{count=count,mask=next,buckets=target}end end
  fun insert cell key=
    let val{count,mask,buckets}= !cell val i=index mask key
        val _=Array.update(buckets,i,(key,key)::Array.sub(buckets,i))
        val updated={count=count+1,mask=mask,buckets=buckets}
    in cell:=(if count+1-64>7*mask then resize updated else updated)end
  fun lookup({mask,buckets,...}:table)key=
    let fun seek []=NONE|seek((k,v)::rest)=if k=key then SOME v else seek rest
    in seek(Array.sub(buckets,index mask key))end
  fun validate size({count,mask,buckets}:table)=
    let val seen=Array.array(size+1,false)
        fun one((key,value),(total,sum))=
          if key<1 orelse key>size orelse key<>value orelse Array.sub(seen,key)then raise Fail "hash table entries differ"
          else(Array.update(seen,key,true);(total+1,IntInf.+(sum,IntInf.fromInt value)))
        fun bucket(i,(total,sum))=
          let val entries=Array.sub(buckets,i)
              fun placed(k,_)=let val big=IntInf.fromInt k
                val h=IntInf.+(big,IntInf.div(IntInf.*(big,1013904242),4294967296))
              in IntInf.toInt(IntInf.mod(h,IntInf.fromInt(mask+1)))=i end
              val _=if List.all placed entries then()else raise Fail "hash function or bucket placement differs"
          in List.foldl one(total,sum)entries end
        fun scan(i,acc)=if i=Array.length buckets then acc else scan(i+1,bucket(i,acc))
        val(total,sum)=scan(0,(0,0))
        val n=IntInf.fromInt size val expected=IntInf.div(IntInf.*(n,IntInf.+(n,1)),2)
        val _=if count=size andalso total=size andalso sum=expected then()else raise Fail "hash table totals differ"
    in sum end
  fun run[size]=
    let val n=BenchInput.between(100,100000000)(BenchInput.integer size)val cell=new()
        fun fill k=if k>n then()else(insert cell k;fill(k+1))
        val _=fill 1 val current= !cell val result=lookup current 100
        val sum=validate n current
    in case result of SOME 100=>Int.toString(#count current)^" "^Int.toString(#mask current)^" "^IntInf.toString sum
      | _=>raise Fail "hash lookup differs"end
    |run _=raise Fail "hash expects key-count"
end
