
 val dryRunSettings:flags=F.fromList[NoBaraki,LowerLim(int 0),UpperLim(int 0),PolyLim(int 1),MonoLim(int 1),ScaleUp(int 20)]
 fun augmentFlags flags=if member equalFlag(cell DryRun)flags then
      F.append dryRunSettings(F.append flags defaultSettings)else F.append flags defaultSettings
 fun strictAnalyze table initialFlags contents=
   let val flags=augmentFlags initialFlags
       val prepared=L.delay(fn()=>prepareAnalysisDetailed contents table flags)
       fun statics()=let val(s,_,_,_)=L.force prepared in s end
       val pretty=F.defer(fn()=>let val(_,_,p,_)=L.force prepared in p end)
       val words=F.defer(fn()=>let val(_,_,_,w)=L.force prepared in w end)
       val analyzed=F.defer(fn()=>if member equalFlag(cell Typecheck)flags then F.empty()
          else let val(s,records,_,_)=L.force prepared
                   val(poly,mono,low,high,scale)=staticLimits s
                   val mindless=hasFlag s SimpleInv
                   val baraki=not(hasFlag s NoBaraki)
               in F.append(settingInformation poly mono low high scale mindless baraki)
                     (flatMap(printAnalysisInformation s mindless)records)end)
   in textConcat[text"\nJules's Strictness Analyser, version 0.400",
      text"\nCopyright (c) Julian Seward 1992\nRead ",renderInteger(length table),text" lattice sizes.\n",
      text"\n\n=============\n=== Input ===\n=============\n",pretty,
      text"\n\n\n=============\n=== Types ===\n=============\n",words,text"\n\n",analyzed,text"\n"]end
