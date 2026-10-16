from pathlib import Path
import struct,math,json
p=Path(__file__).resolve().parent
f32=lambda x:struct.unpack('!f',struct.pack('!f',x))[0]
bits=lambda x:struct.unpack('!I',struct.pack('!f',x))[0]
position=f32(1.0);velocity=f32(0.0);dt=f32(.02);states=[];minimum=math.inf;maximum=0;max_gap=0

def domain(x):
 global minimum,maximum
 assert math.isfinite(x)
 if x:
  e=math.frexp(abs(x))[1];minimum=min(minimum,e);maximum=max(maximum,e);assert e>=-125 and e<=128
 return x

def mul(a,b):domain(a);domain(b);return domain(f32(a*b))
def add(a,b):
 global max_gap
 if a and b:max_gap=max(max_gap,abs(math.frexp(abs(a))[1]-math.frexp(abs(b))[1]))
 domain(a);domain(b);return domain(f32(a+b))
for i in range(4000):
 states.append((bits(position),bits(velocity)))
 force=mul(mul(f32(-1.0),f32(1.0)),position)
 position,velocity=add(position,mul(dt,velocity)),add(velocity,mul(dt,force))
for profile,n in [('smoke',1000),('normal',2500),('large',4000)]:
 actual=[tuple(int(x,16)for x in line.replace('|',' ').split())for line in(p/(profile+'.bits')).read_text().splitlines()];assert actual==states[:n]
 shown=[line.split()[0]for line in(p/(profile+'.stdout')).read_text().splitlines()];assert len(shown)==n and [bits(f32(float(x)))for x in shown]==[s[0]for s in states[:n]]
 (p/(profile+'.positions')).write_text(''.join(format(state[0],'08x')+'\n'for state in states[:n]))
(p/'suite-smoke.positions').write_text(''.join(format(state[0],'08x')+'\n'for state in states[:100]))
(p/'independent-metadata.json').write_text(json.dumps(dict(cells=4000,position_and_velocity_bit_mismatches=0,minimum_nonzero_frexp_exponent=minimum,maximum_frexp_exponent=maximum,maximum_addend_exponent_gap=max_gap,domain='all selected operations are finite binary32 normal or zero; binary64 products exact and sums have at most 24+gap significand bits',dt_bits=format(bits(dt),'08x')),indent=2)+'\n')
print('PASS independent linear binary32 Euler oracle: all 4000 position/velocity bits and original rendered positions agree; finite-normal helper domain confirmed')
