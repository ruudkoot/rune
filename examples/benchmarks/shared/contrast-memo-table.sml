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
