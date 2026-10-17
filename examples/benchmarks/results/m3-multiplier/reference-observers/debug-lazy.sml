structure BenchLazy=struct
 datatype 'a state=Pending of unit->'a|Evaluating|Value of 'a|Failed of exn
 type 'a delay=int*'a state ref
 val next=ref 0
 val stack=ref([]:int list)
 val tags=ref([]:(int*string)list)
 fun delay f=let val id= !next val _=next:=id+1 in(id,ref(Pending f))end
 fun at name f=let val cell as(id,_)=delay f val _=tags:=(id,name):: !tags in cell end
 fun tag id=case List.find(fn(i,_)=>i=id)(!tags)of NONE=>"stream"|SOME(_,s)=>s
 fun force(id,cell)=case !cell of Value x=>x|Failed e=>raise e
  |Evaluating=>(print("REENTRY "^Int.toString id^" "^tag id^"\n");
     List.app(fn i=>print(Int.toString i^" "^tag i^"\n"))(!stack);
     TextIO.flushOut TextIO.stdOut;raise Fail "recursive forcing of delay")
  |Pending f=>let val previous= !stack val _=stack:=id::previous val _=cell:=Evaluating
       val value=f()handle e=>(stack:=previous;cell:=Failed e;raise e)
       val _=stack:=previous val _=cell:=Value value
     in value end
end
