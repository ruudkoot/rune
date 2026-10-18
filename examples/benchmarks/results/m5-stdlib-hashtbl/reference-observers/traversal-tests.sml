structure StdlibHashtblTraversalTests=struct
 structure H=BenchStdlibHashtbl
 val _=T.check("stdlib-hashtbl/source-resize-during-iter",fn()=>
 let val table=H.create H.Generic 1
     fun loop i last f=if i>last then()else(f i;loop(i+1)last f)
     val _=loop 0 31(fn i=>H.add table i i)
     val first=ref true val visits=ref[]
     fun callback key value=(visits:=(key,value):: !visits;
       if !first then(first:=false;loop 32 95(fn i=>H.add table i i))else())
     val _=H.iter callback table
 in H.length table=96 andalso H.bucketCount table=64 andalso rev(!visits)=[(20,20),(6,6),(2,2),(29,29),(21,21),(14,14),(24,24),(16,16),(8,8),(30,30),(7,7),(3,3),(13,13),(12,12),(5,5),(4,4),(31,31),(9,9),(25,25),(23,23),(11,11),(0,0),(28,28),(26,26),(10,10),(1,1),(17,17),(32,32),(27,27),(19,19),(18,18),(22,22),(15,15)]end)
 val _=T.check("stdlib-hashtbl/source-resize-during-fold",fn()=>
 let val table=H.create H.Generic 1
     fun loop i last f=if i>last then()else(f i;loop(i+1)last f)
     val _=loop 0 31(fn i=>H.add table i i)
     val first=ref true val visits=ref[]
     fun callback key value=(visits:=(key,value):: !visits;
       if !first then(first:=false;loop 32 95(fn i=>H.add table i i))else())
     val _=(H.fold(fn k=>fn v=>fn n=>(callback k v;n+1))table 0;())
 in H.length table=96 andalso H.bucketCount table=64 andalso rev(!visits)=[(20,20),(6,6),(2,2),(29,29),(21,21),(14,14),(24,24),(16,16),(8,8),(30,30),(7,7),(3,3),(13,13),(12,12),(5,5),(4,4),(31,31),(9,9),(25,25),(23,23),(11,11),(0,0),(28,28),(26,26),(10,10),(1,1),(17,17),(32,32),(27,27),(19,19),(18,18),(22,22),(15,15)]end)
end
