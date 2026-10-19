structure BenchState =
struct
  type ('s,'a) state = 's -> 's * 'a
  fun return value state=(state,value)
  fun bind computation next state=let val(newState,value)=computation state in next value newState end
  fun mapList _ []=return[]
    |mapList f(x::xs)=bind(f x)(fn y=>bind(mapList f xs)(fn ys=>return(y::ys)))
  fun update f state=(f state,state)
  fun starting computation state = let val(_,answer)=computation state in answer end
end
