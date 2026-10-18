 fun tfo_align arg0 arg1 arg2=D.delay(fn()=>
   let val Pt(x1,y1,z1)=D.force arg0
       val Pt(x2,y2,z2)=D.force arg1
       val Pt(x3,y3,z3)=D.force arg2
       val x31=D.delay(fn()=>R.sub(real x3,real x1))
       val y31=D.delay(fn()=>R.sub(real y3,real y1))
       val z31=D.delay(fn()=>R.sub(real z3,real z1))
       val rotpy=pt_sub(D.delay(fn()=>Pt(x2,y2,z2)))(D.delay(fn()=>Pt(x1,y1,z1)))
       val phi=pt_phi rotpy
       val theta=pt_theta rotpy
       val sinp=D.delay(fn()=>R.sin(real phi))
       val sint=D.delay(fn()=>R.sin(real theta))
       val cosp=D.delay(fn()=>R.cos(real phi))
       val cost=D.delay(fn()=>R.cos(real theta))
       val sinpsint=D.delay(fn()=>R.mul(real sinp,real sint))
       val sinpcost=D.delay(fn()=>R.mul(real sinp,real cost))
       val cospsint=D.delay(fn()=>R.mul(real cosp,real sint))
       val cospcost=D.delay(fn()=>R.mul(real cosp,real cost))
       val rotpz=D.delay(fn()=>Pt(D.delay(fn()=>R.sub(R.mul(real cost,real x31),R.mul(real sint,real z31))),D.delay(fn()=>R.add(R.add(R.mul(real sinpsint,real x31),R.mul(real cosp,real y31)),R.mul(real sinpcost,real z31))),D.delay(fn()=>R.add(R.add(R.mul(real cospsint,real x31),R.negative(R.mul(real sinp,real y31))),R.mul(real cospcost,real z31)))))
       val rho=pt_theta rotpz
       val cosr=D.delay(fn()=>R.cos(real rho))
       val sinr=D.delay(fn()=>R.sin(real rho))
       val x=D.delay(fn()=>R.add(R.negative(R.mul(real x1,real cost)),R.mul(real z1,real sint)))
       val y=D.delay(fn()=>R.sub(R.sub(R.negative(R.mul(real x1,real sinpsint)),R.mul(real y1,real cosp)),R.mul(real z1,real sinpcost)))
       val z=D.delay(fn()=>R.sub(R.add(R.negative(R.mul(real x1,real cospsint)),R.mul(real y1,real sinp)),R.mul(real z1,real cospcost)))
   in Tfo(D.delay(fn()=>R.sub(R.mul(real cost,real cosr),R.mul(real cospsint,real sinr))),D.delay(fn()=>real sinpsint),D.delay(fn()=>R.add(R.mul(real cost,real sinr),R.mul(real cospsint,real cosr))),D.delay(fn()=>R.mul(real sinp,real sinr)),D.delay(fn()=>real cosp),D.delay(fn()=>R.negative(R.mul(real sinp,real cosr))),D.delay(fn()=>R.sub(R.negative(R.mul(real sint,real cosr)),R.mul(real cospcost,real sinr))),D.delay(fn()=>real sinpcost),D.delay(fn()=>R.add(R.negative(R.mul(real sint,real sinr)),R.mul(real cospcost,real cosr))),D.delay(fn()=>R.sub(R.mul(real x,real cosr),R.mul(real z,real sinr))),D.delay(fn()=>real y),D.delay(fn()=>R.add(R.mul(real x,real sinr),R.mul(real z,real cosr))))end)
