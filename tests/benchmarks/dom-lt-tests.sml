structure DomTests=struct
 structure D=BenchDomFn(struct val checkInitialized=true end)
 structure Driver=BenchDomDriverFn(D)
 structure G=BenchDomGraph
 structure M=BenchDomIntMap
 structure S=BenchDomIntSet
 structure R=BenchDomReader
 val base=""
 fun read name=R.read(base^name)
 val graphs=R.graphs(read"cases/graphs.in")
 val parents=R.results(read"repair-threshold.parents")
 val _=List.app(fn(index,(graph,expected))=>T.check("dom-lt/original-repaired-model/"^Int.toString index,
   fn()=>D.idom graph=expected))
   (ListPair.zip(List.tabulate(length graphs,fn i=>i),ListPair.zip(graphs,parents)))
 val keys=[~130,~65,~64,~63,~1,0,1,2,63,64,65,127,128,1024]
 val a=S.fromList keys
 val b=S.fromList[~65,0,2,128,2048]
 val maps=M.fromList(List.map(fn key=>(key,key+1))keys)
 val other=M.fromList[(~65,9),(0,8),(128,7),(2048,6)]
 val raw=read"containers.reference"
 fun between begin ending=
   let val lines=String.fields(fn c=>c= #"\n")raw
       fun after []=raise Fail "missing container section"|after(x::xs)=if x=begin then xs else after xs
       fun until []=[]|until(x::xs)=if x=ending then[]else x::until xs
   in String.concat(List.map(fn line=>line^"\n")(until(after lines)))end
 val setExpected=List.map(fn R.List xs=>List.map R.integer xs|_=>raise Match)(R.parse(between"SETS""MAPS"))
 val setResults=List.map S.toList[a,b,S.union a b,S.difference a b,S.difference b a,S.filter(fn x=>x mod 2=0)a,
   S.fromList[65,64,63,0,64],S.insert(~66)a]
 val _=List.app(fn(i,(actual,expected))=>T.check("dom-lt/original-IntSet/"^Int.toString i,fn()=>actual=expected))
   (ListPair.zip(List.tabulate(length setResults,fn i=>i),ListPair.zip(setResults,setExpected)))
 val mapExpected=R.results(between"MAPS""FOLDS")
 val mapResults=List.map M.toList[maps,other,M.unionWith(fn x=>fn y=>x-y)maps other,
   M.unionWith(fn x=>fn y=>x-y)other maps,M.insertWith(fn x=>fn y=>x-y)64 100 maps,
   M.adjust(fn x=>x+5)(~1)maps,M.adjust(fn x=>x+5)999 maps,M.fromList[(2,5),(2,9),(1,4)],M.map(fn x=>x*2)other]
 val _=List.app(fn(i,(actual,expected))=>T.check("dom-lt/original-IntMap/"^Int.toString i,fn()=>actual=expected))
   (ListPair.zip(List.tabulate(length mapResults,fn i=>i),ListPair.zip(mapResults,mapExpected)))
 val _=T.check("dom-lt/original-set-fold-direction",fn()=>S.foldr(fn key=>fn acc=>key-acc)0 a= ~1027)
 val _=T.check("dom-lt/original-map-left-fold",fn()=>M.foldl(fn acc=>fn key=>fn value=>acc+key-value)0 maps= ~14)
 val _=T.check("dom-lt/original-map-right-fold",fn()=>M.foldr(fn key=>fn value=>fn acc=>key-value-acc)0 maps=0)
 val _=T.check("dom-lt/bitmap-leaf-64-bits",fn()=>case S.fromList[0,1,63]of
   S.Tip(prefix,bits)=>prefix=0w0 andalso Word64.toString bits="8000000000000003"|_=>false)
 val _=T.check("dom-lt/strict-descending-set-fold-process-order",fn()=>
   S.foldr(fn node=>fn order=>order@[node])[] (S.fromList[0,1,63,64])=[64,63,1,0])
 val triangle=(0,G.fromAdj[(0,[1,2]),(1,[]),(2,[1])])
 val _=T.check("dom-lt/minimum-threshold-counterexample",fn()=>D.idom triangle=[(0,0),(2,0),(1,0)])
 val _=T.check("dom-lt/wrong-original-pairs-have-same-length",fn()=>
   length[(0,0),(2,0),(1,2)]=length(D.idom triangle))
 val _=T.check("dom-lt/wrong-original-pairs-rejected",fn()=>
   ((Driver.calculate[triangle]0[[(0,0),(2,0),(1,2)]];false)
     handle Fail why=>String.isPrefix "incorrect result:"why))
 val _=T.check("dom-lt/inclusive-source-repetition-range",fn()=>
   Driver.calculate[triangle]0[[(0,0),(2,0),(1,0)]]=3 andalso
   Driver.calculate[triangle]1[[(0,0),(2,0),(1,0)]]=7)
 val _=T.check("dom-lt/initialization-checker-negative-control",fn()=>
   ((D.read(D.newI 1)0;false)handle Fail why=>String.isPrefix "uninitialized dominator array read"why))
 val _=T.check("dom-lt/source-store-initializes-slot",fn()=>
   let val arr=D.newI 1 val _=D.write arr 0 7 in D.read arr 0=7 end)
 val _=T.check("dom-lt/semantic-target-enables-initialization-checks",fn()=>
   let val D.A(_,flags)=D.newI 1 in Option.isSome flags end)
 val _=T.check("dom-lt/missing-root-rejected",fn()=>((D.idom(0,G.fromAdj[(1,[])]);false)handle Fail _=>true))
 val _=T.check("dom-lt/unclosed-graph-rejected",fn()=>((D.idom(0,G.fromAdj[(0,[1])]);false)handle Fail _=>true))
 val _=T.check("dom-lt/duplicate-vertices-last-wins",fn()=>
   G.toAdj(G.fromAdj[(0,[1]),(0,[2,2]),(1,[]),(2,[])])=[(0,[2]),(1,[]),(2,[])])
 val _=T.check("dom-lt/original-corpus-checksum-one-pass",fn()=>
   Driver.run[base^"ghc-examples.in","0",base^"corpus.parents"]="2183")
end
