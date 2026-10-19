
 val c4=number 4.0
 val c9=number(~9.0)
 val c11=number 11.0
 val c12=number 12.0
 val c16=number(~16.0)
 val c18=number(~18.0)
 val c20=number(~20.0)
 val c24=number 24.0
 val c32=number(~32.0)
 val c48=number(~48.0)
 val c78=number 78.0
 val c80=number 80.0
 val c96=number(~96.0)
 val c120=number 120.0
 val c128=number 128.0
 val c160=number 160.0
 val c192=number 192.0
 val c384=number 384.0
 val a11=(c78,c18,c18,(c24,c24),(c24,c120),(c24,c120))
 val a12=(c9,c9,c11,(c4,c16),(c4,c16),(c16,c16))
 val a13=(c9,c11,c9,(c16,c4),(c16,c16),(c4,c16))
 val a14=(c12,c20,c20,(c48,c48),(c48,c16),(c48,c16))
 val a15=((negative c48),c16,c32,(c32,c16),(c32,(negative c48)),(c16,(negative c48)))
 val a16=((negative c48),c32,c16,(c16,c32),(c16,(negative c48)),(c32,(negative c48)))
 val a22=(c18,c78,c18,(c24,c120),(c24,c24),(c120,c24))
 val a23=(c11,c9,c9,(c16,c16),(c16,c4),(c16,c4))
 val a24=(c16,(negative c48),c32,(c32,(negative c48)),(c32,c16),((negative c48),c16))
 val a25=(c20,c12,c20,(c48,c16),(c48,c48),(c16,c48))
 val a26=(c32,(negative c48),c16,(c16,(negative c48)),(c16,c32),((negative c48),c32))
 val a33=(c18,c18,c78,(c120,c24),(c120,c24),(c24,c24))
 val a34=(c16,c32,(negative c48),((negative c48),c32),((negative c48),c16),(c32,c16))
 val a35=(c32,c16,(negative c48),((negative c48),c16),((negative c48),c32),(c16,c32))
 val a36=(c20,c20,c12,(c16,c48),(c16,c48),(c48,c48))
 val a44=(c96,c160,c160,(c384,c384),(c384,c128),(c384,c128))
 val a45=((negative c16),(negative c16),c80,(c192,c128),(c192,c128),(c128,c128))
 val a46=((negative c16),c80,(negative c16),(c128,c192),(c128,c128),(c192,c128))
 val a55=(c160,c96,c160,(c384,c128),(c384,c384),(c128,c384))
 val a56=(c80,(negative c16),(negative c16),(c128,c128),(c128,c192),(c128,c192))
 val a66=(c160,c160,c96,(c128,c384),(c128,c384),(c384,c384))
 type convectionEntry=realv*realv*realv*(realv*realv)*(realv*realv)*(realv*realv)
 fun selectCoefficients(row:convectionEntry list)=
   let val values=F.fromList row
   in(map(fn v=> #1(force v))values,map(fn v=> #2(force v))values,
      map(fn v=> #3(force v))values,map(fn v=>cell(#4(force v)))values,
      map(fn v=>cell(#5(force v)))values,map(fn v=>cell(#6(force v)))values)end
 val convectionCoefficients=F.fromList[
   selectCoefficients[a11,a12,a13,a14,a15,a16],selectCoefficients[a12,a22,a23,a24,a25,a26],
   selectCoefficients[a13,a23,a33,a34,a35,a36],selectCoefficients[a14,a24,a34,a44,a45,a46],
   selectCoefficients[a15,a25,a35,a45,a55,a56],selectCoefficients[a16,a26,a36,a46,a56,a66]]
 val convectionMatrix=
   A.listArray(1,6)(map(fn cols=>let val(c1,c2,c3,c4,c5,c6)=force cols
       fun pairTerm g h x=let val(a,b)=force x in add(mul a g)(mul b h)end
       fun part(g1,g2,g3)velocity=
          map(fn col=>listMatchProd(force col)velocity)
            (F.fromList[map(mul g1)c1,map(mul g2)c2,map(mul g3)c3,
               map(pairTerm g2 g3)c4,map(pairTerm g1 g3)c5,map(pairTerm g1 g2)c6])
     in cell(fn(y1,y2)=>fn(u1,u2)=>zipWith add(part y1 u1)(part y2 u2))end)convectionCoefficients)
