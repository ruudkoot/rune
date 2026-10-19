(* Active integer-key OCaml 4.14.1 Hashtbl algorithms.
 * Xavier Leroy / INRIA 1996, LGPL 2.1 with linking exception.
 * SML refs replace inline mutable bucket fields; equal integer keys are
 * immutable. Hashing is deterministic seed zero; random tables are out of scope. *)
structure BenchStdlibHashtbl=
struct
 datatype 'a bucket=Empty|Cons of int*'a ref*'a bucket ref
 datatype mode=Generic|Integer
 datatype 'a table=Table of{size:int ref,data:'a bucket Array.array ref,
   initial:int ref,mode:mode}
 fun power size requested=if size>=requested then size else power(size*2)requested
 fun create mode requested=
   let val size=power 16 requested
   in Table{size=ref 0,data=ref(Array.array(size,Empty)),initial=ref size,mode=mode}end
 fun length(Table{size,...})= !size
 fun bucketCount(Table{data,...})=Array.length(!data)
 fun index(Table{data,mode,...}) key=
   let val hash=case mode of Generic=>BenchStdlibHash.integer key|Integer=>key
       val mask=Word.fromInt(Array.length(!data)-1)
   in Word.toInt(Word.andb(Word.fromInt hash,mask))end
 fun resize(table as Table{data,initial,...})=
   let val old= !data val count=Array.length old*2
       val next=Array.array(count,Empty)
       val tails=Array.array(count,Empty)
       val inplace= !initial>=0
       val _=data:=next
       fun insert Empty=()
         |insert(cell as Cons(key,value,link))=
           let val rest= !link
               val cell=if inplace then cell else Cons(key,ref(!value),ref Empty)
               val slot=index table key
               val _=case Array.sub(tails,slot)of Empty=>Array.update(next,slot,cell)
                    |Cons(_,_,previous)=>previous:=cell
               val _=Array.update(tails,slot,cell)
           in insert rest end
       fun each first last f=if first>=last then()else(f first;each(first+1)last f)
       val _=each 0(Array.length old)(fn i=>insert(Array.sub(old,i)))
       val _=if inplace then each 0 count(fn i=>case Array.sub(tails,i)of Empty=>()|Cons(_,_,link)=>link:=Empty)else()
   in()end
 fun add(table as Table{data,size,...}) key value=
   let val slot=index table key
       val _=Array.update(!data,slot,Cons(key,ref value,ref(Array.sub(!data,slot))))
       val _=size:= !size+1
   in if !size>Array.length(!data)*2 then resize table else()end
 fun replace(table as Table{data,size,...}) key value=
   let val slot=index table key val old=Array.sub(!data,slot)
       fun update Empty=true
         |update(Cons(k,item,link))=if k=key then(item:=value;false)else update(!link)
   in if update old then
       (Array.update(!data,slot,Cons(key,ref value,ref old));size:= !size+1;
        if !size>Array.length(!data)*2 then resize table else())
      else()end
 fun remove(table as Table{data,size,...}) key=
   let val slot=index table key
       fun scan Empty _=()
         |scan(cell as Cons(k,_,link))previous=
           if k=key then(size:= !size-1;
             case previous of Empty=>Array.update(!data,slot,!link)
               |Cons(_,_,previousLink)=>previousLink:= !link)
           else scan(!link)cell
   in scan(Array.sub(!data,slot))Empty end
 fun findOpt table key=
   let val Table{data,...}=table
       fun rest Empty=NONE
         |rest(Cons(k,value,link))=if key=k then SOME(!value)else rest(!link)
       (* Retain the source's three explicitly unrolled bucket comparisons. *)
   in case Array.sub(!data,index table key)of Empty=>NONE
    |Cons(k1,v1,n1)=>if key=k1 then SOME(!v1)else
      case !n1 of Empty=>NONE
      |Cons(k2,v2,n2)=>if key=k2 then SOME(!v2)else
        case !n2 of Empty=>NONE
        |Cons(k3,v3,n3)=>if key=k3 then SOME(!v3)else rest(!n3)
   end
 fun traversing(Table{initial,...}) body=
   let val old= !initial<0
       val _=if old then()else initial:= ~(!initial)
       fun restore()=if old then()else initial:= ~(!initial)
   in (let val result=body()val _=restore()in result end)
      handle ex=>(restore();raise ex)end
 fun iter f(table as Table{data,...})=traversing table(fn()=>
   let val array= !data
       fun bucket Empty=()
         |bucket(Cons(key,value,link))=let val next= !link in f key(!value);bucket next end
       fun loop i=if i=Array.length array then()else(bucket(Array.sub(array,i));loop(i+1))
   in loop 0 end)
 fun fold f(table as Table{data,...}) initial=traversing table(fn()=>
   let val array= !data
       fun bucket Empty result=result
         |bucket(Cons(key,value,link))result=bucket(!link)(f key(!value)result)
       fun loop i result=if i=Array.length array then result
         else loop(i+1)(bucket(Array.sub(array,i))result)
   in loop 0 initial end)
 fun filterMap f(table as Table{data,size,...})=traversing table(fn()=>
   let val array= !data
       fun attach slot Empty cell=Array.update(!data,slot,cell)
         |attach _ (Cons(_,_,link))cell=link:=cell
       fun bucket slot previous Empty=attach slot previous Empty
         |bucket slot previous(cell as Cons(key,value,link))=
           let val rest= !link
           in case f key(!value)of NONE=>(size:= !size-1;bucket slot previous rest)
             |SOME newValue=>(attach slot previous cell;value:=newValue;bucket slot cell rest)end
       fun loop i=if i=Array.length array then()else(bucket i Empty(Array.sub(!data,i));loop(i+1))
   in loop 0 end)
 fun contents table=rev(fold(fn k=>fn v=>fn xs=>(k,v)::xs)table[])
end
