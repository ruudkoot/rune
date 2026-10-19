functor BenchFemReportFn(K:sig
 structure A:sig type 'a vec val vecsub:'a vec->int->'a end
 type database
 val nnode:database->int val nelem:database->int val nmats:database->int val nplds:database->int
 val nodeXY:database->int->real*real
 val nodeBC:database->int->int
 val material:database->int->real*real
 val elementNodes:database->int->int*int
 val elementMaterial:database->int->int
 val pointLoad:database->int->int*real*real*real
 val nodeDisplacement:real A.vec->int->real*real*real
end)=
struct
 fun range a b=if a>b then[]else a::range(a+1)b
 fun spaces n=String.implode(List.tabulate(n,fn _=> #" "))
 fun left width text=text^spaces(if width<=String.size text then 1 else width-String.size text)
 fun right width text=spaces(if width<=String.size text then 1 else width-String.size text)^text
 fun integer n=String.map(fn #"~"=> #"-"|c=>c)(Int.toString n)
 fun real value=String.map(fn #"~"=> #"-"|c=>c)(Real.fmt(StringCvt.FIX(SOME 9))value)
 fun il width n=left width(integer n)
 fun ir width n=right width(integer n)
 fun rl width n=left width(real n)
 fun rr width n=right width(real n)
 fun source db=
   let val controls="\n\n\nCONTROL DATA :\n\n"^
          "   Total number of nodes = "^il 3(K.nnode db)^"\n"^
          "   Number of elements    = "^il 3(K.nelem db)^"\n"^
          "   Number of point loads = "^il 3(K.nplds db)^"\n"^
          "   Total number of materials = "^il 3(K.nmats db)^"\n\n\n"
       fun node n=let val(x,y)=K.nodeXY db n
         in"  Node.no = "^il 3 n^"   x = "^rl 8 x^"   y = "^rl 8 y^"   bc = "^il 3(K.nodeBC db n)^"\n"end
       fun material n=let val(ea,ei)=K.material db n
         in"  Material No.="^il 3 n^"   EA = "^rl 8 ea^"   EI = "^rl 8 ei^"\n"end
       fun element n=let val(nl,nr)=K.elementNodes db n
         in"  Element No.="^il 3 n^"   Node.L ="^il 3 nl^"   Node.R ="^il 3 nr^"   Material No. ="^il 3(K.elementMaterial db n)^"\n"end
       fun load n=let val(node,px,py,m)=K.pointLoad db n
         in"  To_point No."^il 3 node^"  Px = "^rl 9 px^"  Py = "^rl 9 py^"  M = "^rl 9 m^"\n"end
   in controls^"NODE INFORMATION  :\n\n"^String.concat(List.map node(range 1(K.nnode db)))^"\n\n"^
      "MATERIAL INFORMATION :\n\n"^String.concat(List.map material(range 1(K.nmats db)))^
      "\nELEMENT DATA:\n\n"^String.concat(List.map element(range 1(K.nelem db)))^"\n\n"^
      "\nPOINT LOADS DATA:\n\n"^String.concat(List.map load(range 1(K.nplds db)))^"\n\n"end
 fun displacements db uvw=
   let fun node n=let val(x,y)=K.nodeXY db n val(u,v,theta)=K.nodeDisplacement uvw n
         in ir 8 n^rr 7 x^rr 6 y^ir 7(K.nodeBC db n)^rr 15 u^rr 15 v^rr 15 theta^"\n"end
   in"\n\nDISPLACEMENT OF THE STRUCTURE \n\n"^
     "     Node     X     Y     BC         U             V"^"                  Theta\n"^
     String.concat(List.map node(range 1(K.nnode db)))end
 fun forces db values=
   let fun element n=let val(nl,nr)=K.elementNodes db n
         in ir 8 n^ir 10 nl^ir 8 nr^rr 15(K.A.vecsub values n)^"\n"end
   in"\n\n\nINTERNAL FORCES OF ELEMENT \n\n"^"    Element    NodeL   NodeR     TENSION\n"^
     String.concat(List.map element(range 1(K.nelem db)))end
 fun render db uvw frc=source db^displacements db uvw^forces db frc
end
