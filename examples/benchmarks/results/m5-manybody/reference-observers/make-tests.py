from pathlib import Path
import shutil
p=Path(__file__).resolve().parent;data=p/'data';data.mkdir(exist_ok=True)
names=['one','small-zero','small-one','small-two','smoke','normal','normal-zero','large-zero']
for name in names:shutil.copyfile(p/(name+'.state'),data/(name+'.state'))
(p/'tests.sml').write_text(r'''structure ManyBodyTests =
struct
  structure K=BenchManyBody
  structure C=BenchManyBodyCheck
  structure N=BenchRecordNBody
  fun check(name,steps,count)=T.check("manybody/source/"^name,fn()=>
    C.run[Int.toString steps,Int.toString count,name^".state"]=
      Int.toString steps^":"^Int.toString count^":"^Int.toString(2+7*count))
  val _=List.app check[("one",0,1),("small-zero",0,4),("small-one",1,4),
    ("small-two",2,4),("smoke",1,16),("normal",20,256),("normal-zero",0,256),("large-zero",0,1024)]
  val reference=C.read "small-one.state"
  fun changed values index f=List.mapi(fn(i,x)=>if i=index then f x else x)values
  val _=List.app(fn i=>T.check("manybody/perturbed-component-"^Int.toString i,fn()=>
    not(C.matches 4(changed reference i(fn x=>x+8.0*(1.0E~9+1.0E~11*Real.abs x)))reference)))
    (List.tabulate(30,fn i=>i))
  val _=T.check("manybody/inside-documented-bound",fn()=>
    C.matches 4(List.map(fn x=>x+0.25*(1.0E~9+1.0E~11*Real.abs x))reference)reference)
  val _=T.check("manybody/short-reference-rejected",fn()=>not(C.matches 4 reference(tl reference)))
  val _=T.check("manybody/extra-reference-rejected",fn()=>not(C.matches 4 reference(reference@[0.0])))
  val _=T.check("manybody/nan-rejected",fn()=>
    not(C.matches 4(changed reference 4(fn _=>0.0/0.0))reference))
  val _=T.check("manybody/infinite-rejected",fn()=>
    not(C.matches 4(changed reference 7(fn _=>1.0/0.0))reference))
  fun body(x,y,z,vx,vy,vz,mass):K.body=
    {x=ref x,y=ref y,z=ref z,vx=ref vx,vy=ref vy,vz=ref vz,mass=mass}
  fun close(a,b)=BenchInput.closeReal(a,b,1.0E~14,1.0E~14)
  val _=T.check("manybody/ordered-two-body-step",fn()=>
    let val a=body(~1.0,0.0,0.0,0.0,0.0,0.0,2.0)
        val b=body(1.0,0.0,0.0,0.0,0.0,0.0,3.0)
        val _=K.advance(Array.fromList[a,b])0.1
    in close(!(#vx a),0.075)andalso close(!(#vx b),~0.05)
       andalso close(!(#x a),~0.9925)andalso close(!(#x b),0.995)end)
  val _=T.check("manybody/source-solar-mass-offset-denominator",fn()=>
    let val a=body(0.0,0.0,0.0,1.0,2.0,3.0,2.0)
        val b=body(1.0,0.0,0.0,4.0,5.0,6.0,3.0)
        val _=K.offset(Array.fromList[a,b])
    in close(!(#vx a),~14.0/N.solarMass)andalso close(!(#vy a),~19.0/N.solarMass)
       andalso close(!(#vz a),~24.0/N.solarMass)andalso close(!(#vx b),4.0)end)
  val _=T.check("manybody/fresh-default-generator",fn()=>
    ListPair.allEq close(K.state(K.initial 4),K.state(K.initial 4)))
  val _=T.check("manybody/fresh-body-fields",fn()=>
    let val a=K.initial 4 val b=K.initial 4 val _= #x(Array.sub(a,0)):= ~999.0
    in close(!(#x(Array.sub(a,1))), !(#x(Array.sub(b,1))))andalso
       not(close(!(#x(Array.sub(a,0))), !(#x(Array.sub(b,0)))))end)
  val _=T.check("manybody/zero-bodies-rejected",fn()=>((C.run["1","0","one.state"];false)handle Fail _=>true))
  val _=T.check("manybody/negative-steps-rejected",fn()=>((C.run["~1","1","one.state"];false)handle Fail _=>true))
end
'''.replace('List.mapi(fn(i,x)=>if i=index then f x else x)values','List.tabulate(List.length values,fn i=>let val x=List.nth(values,i)in if i=index then f x else x end)'))
root=Path.cwd();files=['tests/basis/harness.sml','examples/benchmarks/shared/input.sml','examples/benchmarks/shared/ocaml-random.sml','examples/benchmarks/shared/sandmark-nbody.sml',str(p/'kernel.sml'),str(p/'check.sml'),str(p/'tests.sml'),'tests/basis/finish.sml']
(p/'test-sources.txt').write_text(''.join(str(root/f)+'\n'for f in files));(p/'test-data.txt').write_text(''.join(name+'.state\n'for name in names))
