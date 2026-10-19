module FullObserve where
import qualified Main as M
import Input_proc
main=do
 header<-readFile "../source/fluid.stdin"
 let(file,cfg@(mon,mi,mt,mj,jt,r,dt))=read_fs_cs header
 contents<-readFile("../source/"++file)
 let source=read_data contents
 mapM_(\(name,config)->do
   let value=M.run config source
   writeFile("../"++name++".reference")value
   print(name,length value))
  [("fluid-output",cfg),("fluid-monitor",(True,mi,mt,mj,jt,r,dt)),
   ("fluid-two-steps",(False,2,mt,mj,jt,r,dt)),("fluid-two-steps-monitor",(True,2,mt,mj,jt,r,dt)),
   ("fluid-tolerance-stop",(False,10,1.0e6,mj,jt,r,dt))]
