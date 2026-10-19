structure BenchGraph500Driver =
struct
  fun parameters[scaleText,factorText]=
        (BenchInput.between(0,21)(BenchInput.integer scaleText),
         BenchInput.between(1,16)(BenchInput.integer factorText))
    |parameters _=raise Fail "graph generator expects scale and edge factor"
  fun generate args=
    let val(scale,factor)=parameters args
        val edges=BenchGraph500.generate(BenchOCamlRandom.default())scale factor
        val(size,hash)=BenchGraphMarshal.write"edges.data"edges
    in Int.toString(Array.length edges)^" "^Int.toString size^" "^Word64.toString hash end
  fun sparseSummary edges=
    let val graph=BenchGraph500.sparse edges
        val count=ref 0 val hash=ref(0w0:Word64.word)
        fun add n=hash:=Word64.+(Word64.*(!hash,0w31),Word64.fromInt n)
        val _=Array.appi(fn(vertex,row)=>
          (add vertex;add(List.length row);
           List.app(fn(target,weight)=>
             if Real.isFinite weight andalso weight>=0.0 andalso weight<1.0 then
               (add target;add(Real.trunc(weight*100000000.0));count:= !count+1)
             else raise Fail "incorrect result: graph edge weight")row))graph
    in Int.toString(Array.length edges)^" "^Int.toString(Array.length graph)^" "^
       Int.toString(!count)^" "^Word64.toString(!hash)end
  fun kernel[path]=sparseSummary(BenchGraphMarshal.read path)
    |kernel _=raise Fail "graph kernel1 expects an edge-array Marshal file"
  fun prototype args=
    let val(scale,factor)=parameters args
        val rows=BenchKroneckerPrototype.generate(BenchOCamlRandom.default())scale factor
        val(size,hash)=BenchKroneckerPrototype.write"kronecker.txt"rows
    in Int.toString(RealArray.length(Array.sub(rows,0)))^" "^Int.toString size^" "^Word64.toString hash end
end
