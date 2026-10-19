structure BenchMiniDelay=
struct
 datatype 'a state=Pending of unit->'a|Ready of 'a|Failed of exn|Forcing
 type 'a t='a state ref
 fun delay f=ref(Pending f)
 fun force value=case !value of Ready answer=>answer|Failed ex=>raise ex
   |Forcing=>raise Fail"recursive MiniLight delay"
   |Pending f=>(value:=Forcing;
      (let val answer=f()val _=value:=Ready answer in answer end)
       handle ex=>(value:=Failed ex;raise ex))
end
