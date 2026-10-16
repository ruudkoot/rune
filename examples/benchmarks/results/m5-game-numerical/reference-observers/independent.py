from pathlib import Path
from decimal import Decimal,localcontext
import hashlib,json
ref=Path(__file__).resolve().parent
records=[]
def bitmap(width):
    out=bytearray(f'P4\n{width} {width}\n'.encode())
    for y in range(width):
        row=bytearray((width+7)//8)
        for x in range(width):
            c=complex(x/(width/2)-1.5,y/(width/2)-1.)
            z=0j;inside=True
            for _ in range(50):
                z=z*z+c
                if z.real*z.real+z.imag*z.imag>4.:
                    inside=False;break
            if inside:row[x//8]|=1<<(7-x%8)
        out.extend(row)
    return bytes(out)
for width in [1,7,8,9,16,17,64,256]:
    expected=bitmap(width);actual=(ref/f'mandelbrot-{width}.pbm').read_bytes();assert actual==expected,width
    records.append({'program':'mandelbrot6','width':width,'bytes':len(actual),'sha256':hashlib.sha256(actual).hexdigest(),'reference':'independent direct complex iteration and per-row bit packing'})
    print('PASS every independent PBM byte',width,flush=True)
def original(steps):return list(map(float,(ref/f'nbody-{steps}.state').read_text().split()))
with localcontext()as context:
    context.prec=60
    seed=original(0);assert len(seed)==37
    bodies=[[Decimal.from_float(x)for x in seed[2+7*i:2+7*(i+1)]]for i in range(5)]
    dt=Decimal('.01');observed={}
    def energy():
        result=Decimal(0)
        for i,b in enumerate(bodies):
            result+=Decimal('.5')*b[6]*sum(x*x for x in b[3:6])
            for other in bodies[i+1:]:
                distance=sum((x-y)**2 for x,y in zip(b[:3],other[:3])).sqrt()
                result-=b[6]*other[6]/distance
        return result
    for step in range(10001):
        if step in [0,10,10000]:
            expected=original(step);state=[float(x)for b in bodies for x in b]
            state_error=max(abs(x-y)for x,y in zip(state,expected[2:]));energy_error=abs(float(energy())-expected[1])
            momentum=[sum(b[axis+3]*b[6]for b in bodies)for axis in range(3)]
            assert state_error<1e-9 and energy_error<1e-11,(step,state_error,energy_error)
            assert max(map(abs,momentum))<Decimal('1e-14')
            record={'program':'nbody','steps':step,'precision':60,'state_max_error':state_error,'energy_error':energy_error,'momentum_max_abs':str(max(map(abs,momentum))),'reference':'high-precision equations from original zero-step state'}
            records.append(record);print('PASS independent nbody',record,flush=True)
        if step==10000:break
        for i,b in enumerate(bodies):
            for other in bodies[i+1:]:
                difference=[x-y for x,y in zip(b[:3],other[:3])]
                square=sum(x*x for x in difference);factor=dt/(square*square.sqrt())
                for axis,value in enumerate(difference):
                    b[axis+3]-=value*other[6]*factor
                    other[axis+3]+=value*b[6]*factor
        for b in bodies:
            for axis in range(3):b[axis]+=dt*b[axis+3]
(ref/'independent.json').write_text(json.dumps(records,indent=2)+'\n')
