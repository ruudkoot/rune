from pathlib import Path
import shutil
p=Path(__file__).resolve().parent;dev=p/'table-only-development';dev.mkdir(exist_ok=True)
for name in ['arrays.sml','kernel.sml','check.sml','tests.sml','semantics-final.log','semantic-exits.json']:
 shutil.copy(p/name,dev/name)
for level in ['O0','O2']:
 (p/('host-tests-'+level)).rename(dev/('host-tests-'+level))
 (p/('host-tests-'+level+'.log')).rename(dev/('host-tests-'+level+'.log'))
f=p/'arrays.sml';t=f.read_text();a=t.index(' fun total a=')
t=t[:a]+''' datatype 'a seqNode=Nil|Cons of 'a L.delay*'a seqNode L.delay
 type 'a seq='a seqNode L.delay
 fun mapList f values=L.delay(fn()=>case values of []=>Nil
      |x::xs=>Cons(L.delay(fn()=>f x),mapList f xs))
 fun elements array=L.delay(fn()=>
   let val Store(_,values)=L.force array
       fun loop i=L.delay(fn()=>if i=Vector.length values then Nil
          else Cons(Vector.sub(values,i),loop(i+1)))
   in L.force(loop 0)end)
 fun head values=case L.force values of Nil=>raise Empty|Cons(value,_)=>L.force value
 fun foldl f initial values=
   let fun loop acc values=case L.force values of Nil=>L.force acc
         |Cons(value,rest)=>
           let val next=L.delay(fn()=>f(L.force acc,L.force value))
               val _=if strict then ignore(L.force next)else()
           in loop next rest end
   in loop initial values end
 fun total array=foldl(fn(a:real,b)=>a+b)(L.delay(fn()=>0.0))(elements array)
end
'''
f.write_text(t)
f=p/'kernel.sml';t=f.read_text()
point=' fun polynomial g degree';i=t.index(point)
t=t[:i]+''' fun sum values=A.foldl(fn(a:real,b)=>a+b)(L.delay(fn()=>0.0))values
 fun sumMap f positions=sum(A.mapList f positions)
 fun minimum(a:real,b)=if a<=b then a else b
 fun maximum(a:real,b)=if a<=b then b else a
 fun minList values=A.foldl minimum(L.delay(fn()=>A.head values))values
 fun maxList values=A.foldl maximum(L.delay(fn()=>A.head values))values
'''+t[i:]
old='''       val a=A.sub g(search rhoTable rhoValue,search thetaTable thetaValue)
   in List.foldl(fn((i,j),acc)=>acc+(A.sub a(i,j)*pow(rhoValue,i))*pow(thetaValue,j))
        0.0(coords(range 0 degree)(range 0 degree))end'''
new='''       val a=L.delay(fn()=>A.sub g(search rhoTable rhoValue,search thetaTable thetaValue))
   in sumMap(fn(i,j)=>(A.sub(force a)(i,j)*pow(rhoValue,i))*pow(thetaValue,j))
        (coords(range 0 degree)(range 0 degree))end'''
assert old in t;t=t.replace(old,new)
old='''         fun energy t=e0-(p0+qkl)*tau-zonalEnergy rhokl t
         val t1=newton energy t0'''
new='''         val e1=e0-(p0+qkl)*tau
         val t1=newton(fn t=>e1-zonalEnergy rhokl t)t0'''
assert old in t;t=t.replace(old,new)
old=' fun sum xs=List.foldl(fn(x,a)=>a+x)0.0 xs\n';assert old in t;t=t.replace(old,'')
t=t.replace('sum(List.map','sum(A.mapList')
a=t.index(' fun timestep d thetaHat theta=');b=t.index(' fun suspend f=',a)
t=t[:a]+''' fun timestep d thetaHat theta=
   let val courant=minList(A.mapList(fn zone=>A.sub d zone)zones)
       val conduction=maxList(A.mapList(fn zone=>
         Real.abs(A.sub thetaHat zone-A.sub theta zone)/A.sub thetaHat zone)zones)
   in minimum(dtMaximum,minimum(courant,conduction))end
'''+t[b:]
a=t.index(' fun totals(state as')
t=t[:a]+''' type totalValues=real L.delay*real L.delay*real L.delay*real L.delay*
   real L.delay*real L.delay*real L.delay*real L.delay*real L.delay*
   real L.delay*real L.delay*real L.delay*real L.delay
 type totals=totalValues L.delay
 fun totals(((u,v),(r,z),alpha,s,rho,p,q,epsilon,theta,dt,err):state):totals=
   L.delay(fn()=>(L.delay(fn()=>A.total u),L.delay(fn()=>A.total v),
     L.delay(fn()=>A.total r),L.delay(fn()=>A.total z),
     L.delay(fn()=>A.total alpha),L.delay(fn()=>A.total s),
     L.delay(fn()=>A.total rho),L.delay(fn()=>A.total p),L.delay(fn()=>A.total q),
     L.delay(fn()=>A.total epsilon),L.delay(fn()=>A.total theta),dt,err))
 fun totalTotal values=
   let val(a,b,c,d,e,f,g,h,i,j,k,l,m)=L.force values
   in (((((((((((force a+force b)+force c)+force d)+force e)+force f)+force g)+force h)
         +force i)+force j)+force k)+force l)+force m end
 fun totalsList values=
   let val(a,b,c,d,e,f,g,h,i,j,k,l,m)=L.force values
   in[a,b,c,d,e,f,g,h,i,j,k,l,m]end
 fun computeRaw count=
   let fun loop state totals n=if n<1 then(totals,state)
         else(ignore(totalTotal totals);
              let val state'=next state in loop state'(totalsOf state')(n-1)end)
       and totalsOf state=totals state
       val state=initial()
   in loop state(totals state)count end
 (* Observation adapter only: the report consumer uses computeRaw and leaves
  * the final thirteen-tuple root unused, as in the source. *)
 fun compute count=let val(values,state)=computeRaw count in(totalsList values,state)end
end
'''
f.write_text(t)
f=p/'check.sml';t=f.read_text()
assert 'val(totals,state)=K.compute steps'in t
t=t.replace('val(totals,state)=K.compute steps','val(totals,state)=K.computeRaw steps')
t=t.replace('val _=R.totals values totals','val _=R.totals values(K.totalsList totals)')
f.write_text(t)
