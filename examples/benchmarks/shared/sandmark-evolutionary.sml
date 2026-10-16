structure BenchEvolutionary =
struct
  type bitstring=bool array
  type individual={chromosome:bitstring,fitness:real}
  fun for first last f=if first>last then()else(f first;for(first+1)last f)
  fun chromosome({chromosome,...}:individual)=chromosome
  fun evaluate fitness x:individual={chromosome=x,fitness=fitness x}
  fun fittest(x:individual)(y:individual)=if #fitness x> #fitness y then x else y
  fun popFittest pop=Array.foldl(fn(x,acc)=>fittest acc x)(Array.sub(pop,0))pop
  fun onemax x=Array.foldl(fn(bit,total)=>if bit then total+1.0 else total)0.0 x
  fun randomBits state n=Array.tabulate(n,fn _=>BenchOCamlRandom.bits state mod 2=0)
  fun tournament state k pop=
    let val x=Array.sub(pop,BenchOCamlRandom.integer state(Array.length pop))
    in if k<=1 then x else let val y=tournament state(k-1)pop in fittest x y end end
  fun mutate state chi x=
    let val p=chi/Real.fromInt(Array.length x)
    in Array.tabulate(Array.length x,fn i=>
      let val bit=Array.sub(x,i)val flip=BenchOCamlRandom.real state 1.0<p
      in if bit then not flip else flip end)end
  fun run state budget lambda k chi fitness n=
    let val pop0=Array.tabulate(lambda,fn _=>evaluate fitness(randomBits state n))
        fun generation time pop=
          let val next=Array.tabulate(lambda,fn _=>
                evaluate fitness(mutate state chi(chromosome(tournament state k pop))))
          in if time*lambda>budget then next else generation(time+1)next end
    in generation 0 pop0 end
end
