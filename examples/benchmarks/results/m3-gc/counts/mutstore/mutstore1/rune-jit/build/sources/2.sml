structure BenchMutStore =
struct
  fun run makeStore add buckets [size] =
    let val n=BenchInput.between(1,1000000)(BenchInput.integer size)
        val stores=List.tabulate(n,fn _=>makeStore())
        fun sequence store=List.app(fn _=>add(store,3,17))[1,2,3,4,5]
        val _=List.app(fn _=>List.app sequence stores)[1,2,3,4,5]
        fun observe(store,(entries,total))=
          let val lists=buckets store
              val _=if List.length lists=10 then()else raise Fail "store bucket count"
              fun one([],_,a)=a
                |one(xs::rest,index,(count,sum))=
                  let val length=List.length xs
                      val _=if length=(if index=3 then 25 else 0)andalso List.all(fn x=>x=17)xs
                        then()else raise Fail "store bucket contents"
                  in one(rest,index+1,(count+length,List.foldl(fn(x,a)=>a+x)sum xs))end
          in one(lists,0,(entries,total))end
        val(entries,total)=List.foldl observe(0,0)stores
    in Int.toString(List.length stores)^" "^Int.toString entries^" "^Int.toString total end
    |run _ _ _ _=raise Fail "mutstore expects store-count"
end
