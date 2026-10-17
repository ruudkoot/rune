
structure DriverNeed=BenchGGDriverFn(BenchNeed)
structure TestsNeed=struct
 structure Driver=DriverNeed
 structure K=Driver.K
 structure C=K.C
 structure G=K.G
 structure D=BenchNeed
 structure L=BenchLazy
 structure S=BenchStream
 val base=""
 fun read path=Driver.read(base^path)
 fun label s="gg/Need/"^s
 val _=List.app(fn(profile,file)=>List.app(fn mode=>
   let val format=case mode of"eps"=>"eps"|"portrait"=>"portrait"|_=>"landscape"
       val kind=case mode of"spark"=>"spark"|"pool"=>"pool"|_=>"activity"
       val wanted=read(mode^"-"^profile^".ps")
       val expected=Int.toString(List.length(BenchGGCheck.rows wanted))
   in T.check(label(mode^"-"^profile),fn()=>
      Driver.run kind["1",base^file,base^mode^"-"^profile^".ps",format,"-"]="1:"^expected)end)
   ["activity","spark","pool","eps","portrait"])[("smoke","gg.faststdin"),("normal","gg.stdin"),("large","gg.slowstdin")]
 val _=List.app(fn mode=>T.check(label(mode^"-extra-compressed-trace"),fn()=>
   let val expected=List.length(BenchGGCheck.rows(read(mode^"-extra.ps")))
   in Driver.run mode["1",base^"extra.trace",base^mode^"-extra.ps","landscape","-"]="1:"^Int.toString expected end))
   ["activity","spark","pool"]
 fun show n=IntInf.toString(D.force n)
 fun row(C.Ln(pe,act,spark))=
       let val C.PE(name,no)=L.force pe
       in String.concatWith " "(String.implode name::show no::
         List.map show(C.actValues(L.force act)@C.sparkValues(L.force spark)))end
    |row _=raise Fail "unexpected ordered line"
 val _=List.app(fn(profile,file)=>T.check(label("ordered-records-"^profile),fn()=>
   let val(_,_,ordered)=L.force(C.parameters(C.parseFile(String.explode(read(file)))))
   in String.concat(List.rev(S.foldl(fn(line,rows)=>(row line^"\n")::rows)[]ordered))=read(profile^".rows")end))
   [("smoke","gg.faststdin"),("normal","gg.stdin"),("large","gg.slowstdin")]
 val _=T.check(label"source-integer-parser-preserves-positional-value",fn()=>
   let val(n,rest)=C.integer(String.explode" 12345:tail")in D.force n=12345 andalso String.implode rest=":tail"end)
 val _=T.check(label"source-integer-parser-empty-prefix-is-zero",fn()=>
   let val(n,rest)=C.integer(String.explode" -2")in D.force n=0 andalso String.implode rest="-2"end)
 val _=T.check(label"source-processor-splits-name-and-number",fn()=>
   let val(C.PE(name,n),rest)=C.processor(String.explode" 14.3:0")
   in String.implode name="14"andalso D.force n=3 andalso String.implode rest=":0"end)
 val _=T.check(label"source-null-lines-are-ignored",fn()=>case C.line(String.explode"not statistics")of C.Null=>true|_=>false)
 val _=T.check(label"source-partial-PE-header-yields-zero-active",fn()=>
   let val(pes,ticks,_)=L.force(C.parameters(C.parseFile(String.explode(read"gg.faststdin"))))
   in S.foldl(fn(_,n)=>n+1)0 pes=1 andalso D.force ticks=128 end)
 val _=T.check(label"source-infinite-scaling-is-preserved",fn()=>
   String.isSubstring"2.5 Infinity scale\n"(read"activity-smoke.ps"))
 val _=T.check(label"selected-inactive-processor-is-rejected",fn()=>
   ((Driver.run"activity"["1",base^"gg.stdin",base^"activity-normal.ps","landscape","14.1"];false)handle Fail _=>true))
 val _=T.check(label"postscript-integer-format-uses-minus",fn()=>G.integer(~12)="-12")
 val _=T.check(label"source-float-label-below-one",fn()=>G.printFloat(G.single 0.25)="0.2")
 val _=T.check(label"source-float-label-nearest-even",fn()=>G.printFloat(G.single 0.75)="0.8")
 val _=T.check(label"source-float-label-removes-zero-tenth",fn()=>G.printFloat(G.single 2.0)="2")
 val _=T.check(label"source-float-label-rounds-large-values",fn()=>G.printFloat(G.single 12.6)="13")
 val _=T.check(label"source-axis-scale-125-sequence",fn()=>
   List.map G.axisScale[0,1,2,3,6,11,26,51,101]=[1,1,2,5,10,20,50,100,200])
 val _=T.check(label"source-calibration-preserves-division",fn()=>List.map G.calibrate[0,1,2,100,101,12345]=[1,1,2,100,10,12])
 val _=T.check(label"zero-repetitions",fn()=>Driver.run"activity"["0",base^"gg.stdin",base^"activity-normal.ps","landscape","-"]="0:0")
 val _=T.check(label"repetitions-reset-source-state",fn()=>
   let val n=List.length(BenchGGCheck.rows(read"activity-smoke.ps"))
   in Driver.run"activity"["2",base^"gg.faststdin",base^"activity-smoke.ps","landscape","-"]="2:"^Int.toString(2*n)end)
 val _=T.check(label"paired-accumulation-shares-step-results",fn()=>
   let val calls=ref 0
       fun step state x=(calls:= !calls+1;(x,state+x))
       val result=C.accumulate step 0(S.fromList[1,2,3])
       val(traces,final)=L.force result
       val total=L.force final
       val completed= !calls
       val traced=S.foldl(fn(x,sum)=>sum+x)0 traces
   in total=6 andalso traced=6 andalso completed=3 andalso !calls=3 end)
 val _=T.check(label"unknown-mode-is-rejected",fn()=>((Driver.mode"bad";false)handle Fail _=>true))
 val _=T.check(label"unknown-format-is-rejected",fn()=>((Driver.format"bad";false)handle Fail _=>true))
end

structure DriverStrict=BenchGGDriverFn(BenchStrict)
structure TestsStrict=struct
 structure Driver=DriverStrict
 structure K=Driver.K
 structure C=K.C
 structure G=K.G
 structure D=BenchStrict
 structure L=BenchLazy
 structure S=BenchStream
 val base=""
 fun read path=Driver.read(base^path)
 fun label s="gg/Strict/"^s
 val _=List.app(fn(profile,file)=>List.app(fn mode=>
   let val format=case mode of"eps"=>"eps"|"portrait"=>"portrait"|_=>"landscape"
       val kind=case mode of"spark"=>"spark"|"pool"=>"pool"|_=>"activity"
       val wanted=read(mode^"-"^profile^".ps")
       val expected=Int.toString(List.length(BenchGGCheck.rows wanted))
   in T.check(label(mode^"-"^profile),fn()=>
      Driver.run kind["1",base^file,base^mode^"-"^profile^".ps",format,"-"]="1:"^expected)end)
   ["activity","spark","pool","eps","portrait"])[("smoke","gg.faststdin"),("normal","gg.stdin"),("large","gg.slowstdin")]
 val _=List.app(fn mode=>T.check(label(mode^"-extra-compressed-trace"),fn()=>
   let val expected=List.length(BenchGGCheck.rows(read(mode^"-extra.ps")))
   in Driver.run mode["1",base^"extra.trace",base^mode^"-extra.ps","landscape","-"]="1:"^Int.toString expected end))
   ["activity","spark","pool"]
 fun show n=IntInf.toString(D.force n)
 fun row(C.Ln(pe,act,spark))=
       let val C.PE(name,no)=L.force pe
       in String.concatWith " "(String.implode name::show no::
         List.map show(C.actValues(L.force act)@C.sparkValues(L.force spark)))end
    |row _=raise Fail "unexpected ordered line"
 val _=List.app(fn(profile,file)=>T.check(label("ordered-records-"^profile),fn()=>
   let val(_,_,ordered)=L.force(C.parameters(C.parseFile(String.explode(read(file)))))
   in String.concat(List.rev(S.foldl(fn(line,rows)=>(row line^"\n")::rows)[]ordered))=read(profile^".rows")end))
   [("smoke","gg.faststdin"),("normal","gg.stdin"),("large","gg.slowstdin")]
 val _=T.check(label"source-integer-parser-preserves-positional-value",fn()=>
   let val(n,rest)=C.integer(String.explode" 12345:tail")in D.force n=12345 andalso String.implode rest=":tail"end)
 val _=T.check(label"source-integer-parser-empty-prefix-is-zero",fn()=>
   let val(n,rest)=C.integer(String.explode" -2")in D.force n=0 andalso String.implode rest="-2"end)
 val _=T.check(label"source-processor-splits-name-and-number",fn()=>
   let val(C.PE(name,n),rest)=C.processor(String.explode" 14.3:0")
   in String.implode name="14"andalso D.force n=3 andalso String.implode rest=":0"end)
 val _=T.check(label"source-null-lines-are-ignored",fn()=>case C.line(String.explode"not statistics")of C.Null=>true|_=>false)
 val _=T.check(label"source-partial-PE-header-yields-zero-active",fn()=>
   let val(pes,ticks,_)=L.force(C.parameters(C.parseFile(String.explode(read"gg.faststdin"))))
   in S.foldl(fn(_,n)=>n+1)0 pes=1 andalso D.force ticks=128 end)
 val _=T.check(label"source-infinite-scaling-is-preserved",fn()=>
   String.isSubstring"2.5 Infinity scale\n"(read"activity-smoke.ps"))
 val _=T.check(label"selected-inactive-processor-is-rejected",fn()=>
   ((Driver.run"activity"["1",base^"gg.stdin",base^"activity-normal.ps","landscape","14.1"];false)handle Fail _=>true))
 val _=T.check(label"postscript-integer-format-uses-minus",fn()=>G.integer(~12)="-12")
 val _=T.check(label"source-float-label-below-one",fn()=>G.printFloat(G.single 0.25)="0.2")
 val _=T.check(label"source-float-label-nearest-even",fn()=>G.printFloat(G.single 0.75)="0.8")
 val _=T.check(label"source-float-label-removes-zero-tenth",fn()=>G.printFloat(G.single 2.0)="2")
 val _=T.check(label"source-float-label-rounds-large-values",fn()=>G.printFloat(G.single 12.6)="13")
 val _=T.check(label"source-axis-scale-125-sequence",fn()=>
   List.map G.axisScale[0,1,2,3,6,11,26,51,101]=[1,1,2,5,10,20,50,100,200])
 val _=T.check(label"source-calibration-preserves-division",fn()=>List.map G.calibrate[0,1,2,100,101,12345]=[1,1,2,100,10,12])
 val _=T.check(label"zero-repetitions",fn()=>Driver.run"activity"["0",base^"gg.stdin",base^"activity-normal.ps","landscape","-"]="0:0")
 val _=T.check(label"repetitions-reset-source-state",fn()=>
   let val n=List.length(BenchGGCheck.rows(read"activity-smoke.ps"))
   in Driver.run"activity"["2",base^"gg.faststdin",base^"activity-smoke.ps","landscape","-"]="2:"^Int.toString(2*n)end)
 val _=T.check(label"paired-accumulation-shares-step-results",fn()=>
   let val calls=ref 0
       fun step state x=(calls:= !calls+1;(x,state+x))
       val result=C.accumulate step 0(S.fromList[1,2,3])
       val(traces,final)=L.force result
       val total=L.force final
       val completed= !calls
       val traced=S.foldl(fn(x,sum)=>sum+x)0 traces
   in total=6 andalso traced=6 andalso completed=3 andalso !calls=3 end)
 val _=T.check(label"unknown-mode-is-rejected",fn()=>((Driver.mode"bad";false)handle Fail _=>true))
 val _=T.check(label"unknown-format-is-rejected",fn()=>((Driver.format"bad";false)handle Fail _=>true))
end

structure CheckerTests=struct
 structure C=BenchGGCheck
 structure S=BenchStream
 fun label s="gg/checker/"^s
 fun chars text=S.fromList(String.explode text)
 fun reject name expected observed=T.check(label name,fn()=>((C.consume(chars observed)(C.rows expected);false)handle Fail _=>true))
 val _=T.check(label"equivalent-double-spelling",fn()=>C.consume(chars"1.5000000000000000 2.0000000 scale\n")(C.rows"1.5 2.0 scale\n")=1)
 val _=T.check(label"nearby-double-inside-bound",fn()=>C.equivalent"1.5000000000001 2.0 scale\n""1.5 2.0 scale\n")
 val _=reject"perturbed-double""1.5 2.0 scale\n""1.500001 2.0 scale\n"
 val _=reject"changed-integer-point""1 2 moveto\n""2 2 moveto\n"
 val _=reject"integer-point-cannot-be-rounded""1 2 moveto\n""1.0000000000001 2 moveto\n"
 val _=reject"changed-command""1 2 moveto\n""1 2 lineto\n"
 val _=reject"changed-title""(Activity) show\n""(Activities) show\n"
 val _=reject"changed-color""0 setgray\n""1 setgray\n"
 val _=reject"extra-line""stroke\n""stroke\nfill\n"
 val _=reject"missing-line""stroke\nfill\n""stroke\n"
 val _=reject"missing-numeric-newline""1.5 2.0 scale\n""1.5 2.0 scale"
 val _=reject"numeric-whitespace-is-not-an-output-change""1.5 2.0 scale\n""1.5  2.0 scale\n"
 val _=reject"infinity-cannot-replace-finite""1.5 2.0 scale\n""Infinity 2.0 scale\n"
 val _=reject"finite-cannot-replace-infinity""2.5 Infinity scale\n""2.5 0.0 scale\n"
 val _=reject"infinity-sign-is-preserved""2.5 Infinity scale\n""2.5 -Infinity scale\n"
 val _=reject"NaN-does-not-match-infinity""2.5 Infinity scale\n""2.5 NaN scale\n"
 val _=T.check(label"matching-NaN-category",fn()=>C.numeric("NaN","NaN"))
 val _=T.check(label"zero-lines-are-consumed",fn()=>C.consume(chars"")[]=0)
 val _=List.app(fn(text,wanted)=>T.check(label("hash-"^text),fn()=>C.reverseHash text=Word64.fromInt wanted))
   [("",0),("a",97),("abc",96354)]
 val _=T.check(label"multi-line-polynomial-composition",fn()=>C.consume(chars"newpath\n1 2 moveto\nstroke\n")
   (C.rows"newpath\n1 2 moveto\nstroke\n")=3)
end
structure DemandTests=struct
 structure K=DriverNeed.K
 structure Q=DriverStrict.K
 structure S=BenchStream
 structure L=BenchLazy
 val _=T.check("gg/demand/global-postscript-prefix-before-input",fn()=>
   let val output=K.run(K.Activity[K.GC,K.REDN,K.IDLE,K.FLUSH])K.Landscape[](String.explode"Bbroken")
   in String.implode(S.take 17 output)="%!PS-Adobe-2.0\n%%"end)
 val _=T.check("gg/demand/body-boxes-before-processor-data",fn()=>
   let val body=K.graph[](K.Activity[K.GC,K.REDN,K.IDLE,K.FLUSH])(String.explode"Bbroken")
   in String.implode(S.take 9 body)="0.2 setli"end)
 val _=T.check("gg/demand/default-activity-filter-ignores-processor-value",fn()=>
   let val entry=K.C.Ln(L.delay(fn()=>raise Fail "unused processor"),
         L.delay(fn()=>K.C.Act(K.C.zero,K.C.zero,K.C.zero,K.C.zero,K.C.zero,K.C.number 1)),
         L.delay(fn()=>raise Fail "unused sparks"))
   in case S.head(K.C.getActs[](S.singleton entry))of K.C.Act _=>true end)
 val _=T.check("gg/demand/default-spark-filter-ignores-processor-value",fn()=>
   let val entry=K.C.Ln(L.delay(fn()=>raise Fail "unused processor"),
         L.delay(fn()=>raise Fail "unused activities"),
         L.delay(fn()=>K.C.Sp(K.C.zero,K.C.zero,K.C.zero,K.C.zero,K.C.zero)))
   in case S.head(K.C.getSparks[](S.singleton entry))of K.C.Sp _=>true end)
 val _=T.check("gg/demand/unused-spark-integers-stay-lazy",fn()=>
   let val calls=ref 0
       val unused=BenchNeed.delay(fn()=>(calls:= !calls+1;IntInf.fromInt 7))
       val line=K.C.Ln(L.delay(fn()=>K.C.PE(String.explode"14",K.C.zero)),
         L.delay(fn()=>K.C.Act(K.C.zero,K.C.zero,K.C.zero,K.C.zero,K.C.zero,K.C.number 1)),
         L.delay(fn()=>K.C.Sp(K.C.zero,unused,unused,unused,unused)))
       val values=K.C.getActs[](S.singleton line)
       val _=S.foldl(fn(_,n)=>n+1)0 values
   in !calls=0 end)
end
