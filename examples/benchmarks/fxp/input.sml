structure XMLInput =
struct
  val words=Vector.fromList ["alpha","beta","gamma","delta","epsilon","zeta","eta","theta","iota","kappa","lambda","mu","nu","xi","omicron","pi","rho","sigma","tau","upsilon","phi","chi","psi","omega"]
  val tags=Vector.fromList ["section","para","list","item","note","em","code","ref"]
  val attributes=Vector.fromList ["href","id","class","rel","n"]
  fun generate (target,path)=
    let val seed=ref(0w12345:Word32.word)
        val elements=ref 1 val countAttrs=ref 0
        fun rnd n=(seed:=Word32.andb(Word32.+(Word32.*(!seed,0w1103515245),0w12345),0wx7fffffff);
          Word32.toInt(Word32.>>(!seed,0w16)) mod n)
        fun word()=Vector.sub(words,rnd 24)
        fun attrs()=let val count=rnd 4 val offset=rnd 5
          fun loop(0,_,acc)=String.concat(List.rev acc)
            | loop(k,i,acc)=let val text=" "^Vector.sub(attributes,(offset+i)mod 5)^"=\""^word()^Int.toString(rnd 1000)^"\""
              in countAttrs:= !countAttrs+1;loop(k-1,i+1,text::acc) end
          in loop(count,0,[]) end
        fun text count =
          let val base=String.concatWith " "(List.tabulate(count,fn _=>word()))
          in if rnd 4=0 then base^" &amp; "^word()^" &lt;x&gt; (c)" else base end
        fun element depth =
          let val tag=Vector.sub(tags,rnd 8)
              val tag=if depth=1 andalso rnd 3=0 then "section" else tag
              val at=attrs()
              val _=elements:= !elements+1
              val count=rnd 3+1
              fun content(0,acc)=String.concat(List.rev acc)
                | content(k,acc)=let val part=text(rnd 12+1)^"\n"
                    val child=if depth<3 andalso rnd 3=0 then element(depth+1) else ""
                  in content(k-1,child::part::acc) end
              val body=content(count,[])
              val title=if tag="section" then
                let val at=attrs() val body=text 4 val _=elements:= !elements+1
                in "<title"^at^">\n"^body^"\n</title>\n" end else ""
          in title^"<"^tag^at^">\n"^body^"</"^tag^">\n" end
        val output=TextIO.openOut path
        val _=TextIO.output(output,"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<doc>\n")
        fun loop bytes=if bytes>=target then bytes else
          let val item=element 1 in TextIO.output(output,item);loop(bytes+String.size item) end
        val bytes=loop 0
        val _=TextIO.output(output,"</doc>\n")
        val _=TextIO.closeOut output
    in (!elements,!countAttrs,bytes) end
end
