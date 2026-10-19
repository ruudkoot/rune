structure BenchGrepTests =
struct
 structure N=BenchGrepFn(BenchNeed)
 structure S=BenchGrepFn(BenchStrict)
 fun cases label check inputs =
   let fun loop [] _=()
         | loop(input::rest)i=(T.check(label^"-"^Int.toString i,fn()=>check input);loop rest(i+1))
   in loop inputs 0 end
 val _=List.app(fn(label,pattern,yes,no)=>
  let val p=BenchUTF8.decode pattern
      val n=N.compile p
      val s=S.compile p
      fun accept input=N.accept n(BenchUTF8.decode input)andalso S.accept s(BenchUTF8.decode input)
      fun reject input=not(N.accept n(BenchUTF8.decode input))andalso not(S.accept s(BenchUTF8.decode input))
  in cases("grep/"^label^"/accept")accept yes;
     cases("grep/"^label^"/reject")reject no end)
 [("literal","a",["a"],["","ab"]),("star","a*",["","a","aaa"],["b","ab"]),
  ("plus","a+",["a","aaa"],["","b"]),("optional","a?",["","a"],["aa"]),
  ("literal-caret","^a",["^a"],["a"]),("ignored-suffix","a\\",["a"],["b"]),
  ("literal-dollar","a$$",["a$"],["a"]),
  ("group-and-anchor","\\(a\\|b\\)*c$",["c","abc","bbac"],["","ab","acc"]),
  ("selected-pattern",".*:..*",["x:y",": ","abc:de"],["",":","abc:"])]
 val _=T.check("utf8/non-ascii",fn()=>BenchUTF8.decode "\195\169\237\149\156"=[233,54620])
 val _=T.check("utf8/overlong-rejected",fn()=>((BenchUTF8.decode "\192\128";false)handle Fail _=>true))

 val _=T.check("utf8/scalar-boundaries",fn()=>BenchUTF8.decode
   "\000\127\194\128\223\191\224\160\128\239\191\191\240\144\128\128\244\143\191\191"
   =[0,127,128,2047,2048,65535,65536,1114111])
 val _=List.app(fn(label,bytes)=>T.check("utf8/"^label,fn()=>
   ((BenchUTF8.decode bytes;false)handle Fail _=>true)))
   [("bad-continuation","\226(\161"),("truncated","\226\130"),
    ("surrogate","\237\160\128"),("overlong-three","\224\128\128"),
    ("overlong-four","\240\128\128\128"),("out-of-range","\244\144\128\128")]
 val _=T.check("utf8/line-boundaries",fn()=>BenchUTF8.lines[10,97,10,10,98]=[[],[97],[],[98]])
 val _=T.check("grep/literal-label-defers-successor",fn()=>
   let val bad=N.L.delay(fn()=>raise Fail "unneeded successor")
   in case BenchNeed.force(N.step(N.nfaChar 97 bad)98)of N.Q.Nil=>true | _=>false end)
 val _=T.check("grep/node-memoization",fn()=>
   let val calls=ref 0
       val node=N.L.delay(fn()=>(calls:= !calls+1;N.NFAFinal))
       val _=N.L.force node
       val _=N.L.force node
   in !calls=1 end)
end
