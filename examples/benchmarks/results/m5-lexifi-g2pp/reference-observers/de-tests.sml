structure G2OptimizerTests=struct
 structure O=BenchG2Optimization
 fun close(a,b)=BenchG2Check.close(a,b,1.0E~12,1.0E~12)
 val _=T.check("G2/source-DE-sphere/0",fn()=>
 let val trace=ref[]
     val result=O.optimize(O.parameters 2)
       (fn x=>Array.foldl(fn(v,h)=>h+v*v)0.0 x)
       (Array.fromList[~2.0,~2.0])(Array.fromList[2.0,2.0])
       (fn n=>fn value=>trace:=(n,value):: !trace)
       {maxit=10000,maxf=0,target=0.0}
 in #evaluations result=40 andalso #status result=O.MaxEvaluations
    andalso close(#f result,0.039335378187796088)
    andalso close(Array.sub(#x0 result,0),0.020352068508639132)
    andalso close(Array.sub(#x0 result,1),0.19728449380327828)
    andalso ListPair.allEq(fn((n,a),(m,b))=>n=m andalso close(a,b))(rev(!trace),[(1,5.2944564798739364),(2,2.8038646539434375),(3,2.6375124397213803),(4,1.036747639267523),(7,0.92754581640959244),(9,0.65372128765511428),(18,0.49195254159800422),(24,0.21049203104421424),(29,0.039335378187796088)])end)
 val _=T.check("G2/source-DE-sphere/20",fn()=>
 let val trace=ref[]
     val result=O.optimize(O.parameters 2)
       (fn x=>Array.foldl(fn(v,h)=>h+v*v)0.0 x)
       (Array.fromList[~2.0,~2.0])(Array.fromList[2.0,2.0])
       (fn n=>fn value=>trace:=(n,value):: !trace)
       {maxit=10000,maxf=20,target=0.0}
 in #evaluations result=40 andalso #status result=O.MaxEvaluations
    andalso close(#f result,0.039335378187796088)
    andalso close(Array.sub(#x0 result,0),0.020352068508639132)
    andalso close(Array.sub(#x0 result,1),0.19728449380327828)
    andalso ListPair.allEq(fn((n,a),(m,b))=>n=m andalso close(a,b))(rev(!trace),[(1,5.2944564798739364),(2,2.8038646539434375),(3,2.6375124397213803),(4,1.036747639267523),(7,0.92754581640959244),(9,0.65372128765511428),(18,0.49195254159800422),(24,0.21049203104421424),(29,0.039335378187796088)])end)
 val _=T.check("G2/source-DE-sphere/40",fn()=>
 let val trace=ref[]
     val result=O.optimize(O.parameters 2)
       (fn x=>Array.foldl(fn(v,h)=>h+v*v)0.0 x)
       (Array.fromList[~2.0,~2.0])(Array.fromList[2.0,2.0])
       (fn n=>fn value=>trace:=(n,value):: !trace)
       {maxit=10000,maxf=40,target=0.0}
 in #evaluations result=60 andalso #status result=O.MaxEvaluations
    andalso close(#f result,0.013836468707351687)
    andalso close(Array.sub(#x0 result,0),0.099565228485722079)
    andalso close(Array.sub(#x0 result,1),~0.062635724502376783)
    andalso ListPair.allEq(fn((n,a),(m,b))=>n=m andalso close(a,b))(rev(!trace),[(1,5.2944564798739364),(2,2.8038646539434375),(3,2.6375124397213803),(4,1.036747639267523),(7,0.92754581640959244),(9,0.65372128765511428),(18,0.49195254159800422),(24,0.21049203104421424),(29,0.039335378187796088),(42,0.013836468707351687)])end)
 val _=T.check("G2/source-DE-sphere/200",fn()=>
 let val trace=ref[]
     val result=O.optimize(O.parameters 2)
       (fn x=>Array.foldl(fn(v,h)=>h+v*v)0.0 x)
       (Array.fromList[~2.0,~2.0])(Array.fromList[2.0,2.0])
       (fn n=>fn value=>trace:=(n,value):: !trace)
       {maxit=10000,maxf=200,target=0.0}
 in #evaluations result=220 andalso #status result=O.MaxEvaluations
    andalso close(#f result,0.00020950007825557522)
    andalso close(Array.sub(#x0 result,0),~0.0086204328746659238)
    andalso close(Array.sub(#x0 result,1),0.01162704671483495)
    andalso ListPair.allEq(fn((n,a),(m,b))=>n=m andalso close(a,b))(rev(!trace),[(1,5.2944564798739364),(2,2.8038646539434375),(3,2.6375124397213803),(4,1.036747639267523),(7,0.92754581640959244),(9,0.65372128765511428),(18,0.49195254159800422),(24,0.21049203104421424),(29,0.039335378187796088),(42,0.013836468707351687),(142,0.0048185812677001769),(156,0.0026326211591338857),(169,0.0024335478835963609),(190,0.0019162366665728926),(197,0.00020950007825557522)])end)
end
