from pathlib import Path
p=Path(__file__).resolve().parent
body=r'''
structure GraphsPOLICY=BenchGGGraphsFn(BenchPOLICY)
structure RenderPOLICY=struct
 structure K=GraphsPOLICY
 structure S=BenchStream
 val base="BASE/"
 fun read file=let val f=TextIO.openIn file val text=TextIO.inputAll f val _=TextIO.closeIn f in text end
 fun run(profile,file,modeName)=
   let val input=String.explode(read(base^"source/"^file))
       val mode=case modeName of "spark"=>K.Sparks[K.RESUMED,K.USED,K.CREATED,K.LOST]
         |"pool"=>K.Pool|_=>K.Activity[K.GC,K.REDN,K.IDLE,K.FLUSH]
       val format=case modeName of "eps"=>K.Encapsulated(15,10)|"portrait"=>K.Portrait|_=>K.Landscape
       val output=K.run mode format[]input
       val text=String.implode(List.rev(S.foldl(fn(c,cs)=>c::cs)[]output))
       val file=TextIO.openOut(base^"actual-POLICY-"^modeName^"-"^profile^".ps")
       val _=TextIO.output(file,text)val _=TextIO.closeOut file
   in print("POLICY "^modeName^" "^profile^" "^Int.toString(String.size text)^"\n")end
 val _=List.app(fn(profile,file)=>List.app(fn mode=>run(profile,file,mode))
   ["activity","spark","pool","eps","portrait"])[("smoke","gg.faststdin"),("normal","gg.stdin"),("large","gg.slowstdin")]
end
'''
(p/'render-pilot.sml').write_text(''.join(body.replace('POLICY',policy).replace('BASE',str(p))for policy in ['Need','Strict']))
