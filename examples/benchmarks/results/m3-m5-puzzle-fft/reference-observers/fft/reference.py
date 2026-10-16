from pathlib import Path
import cmath,hashlib,json,math,resource,struct,subprocess,time
ref=Path(__file__).resolve().parent
source=(ref/'fft.ml').read_text();marker='let () = main () |> ignore'
assert source.count(marker)==1
observer='''let emit channel array = Array.iter(fun z ->
  List.iter(fun f -> let bits=Int64.bits_of_float f in
    for i=0 to 7 do output_byte channel (Int64.to_int(Int64.logand 255L (Int64.shift_right_logical bits (8*i)))) done)
    [z.re;z.im])array
let () =
  let x=if Array.length Sys.argv>2 then [|{re=1.;im=2.};{re=3.;im=(-4.)};{re=(-2.);im=1.};{re=0.5;im=3.}|] else arr in
  let forward=fft x in
  emit stdout forward; emit stdout (ifft forward)
'''
(ref/'fft_observer.ml').write_text(source.replace(marker,observer))
metadata={'compiler':subprocess.check_output(['ocamlopt','-version'],text=True).strip(),'options':['-O2'],'profiles':[],'sha256':{}}
for stem in ['fft','fft_observer']:
    with(ref/(stem+'-build.log')).open('w')as log:
        subprocess.run(['ocamlopt','-O2','-o',stem,'unix.cmxa',stem+'.ml'],cwd=ref,check=True,stdout=log,stderr=subprocess.STDOUT)
    metadata['sha256'][stem+'.ml']=hashlib.sha256((ref/(stem+'.ml')).read_bytes()).hexdigest()
def bounded():
    resource.setrlimit(resource.RLIMIT_AS,(2*1024**3,2*1024**3))
    resource.setrlimit(resource.RLIMIT_CPU,(120,120))
def dft(xs):return [sum(x*cmath.exp(-2j*math.pi*k*i/len(xs)) for i,x in enumerate(xs)) for k in range(len(xs))]
for size in [1,2,8,16,1024,16384,1048576]:
    begin=time.monotonic()
    original=subprocess.run([str(ref/'fft'),str(size)],capture_output=True,timeout=120,preexec_fn=bounded)
    assert original.returncode==0 and not original.stdout,(size,original.stderr)
    output=ref/f'ramp-{size}.bin'
    with output.open('wb')as stream:
        subprocess.run([str(ref/'fft_observer'),str(size)],check=True,stdout=stream,timeout=120,preexec_fn=bounded)
    raw=output.read_bytes();assert len(raw)==32*size
    forward=list(struct.iter_unpack('<dd',raw[:16*size]));back=list(struct.iter_unpack('<dd',raw[16*size:]))
    digits=size.bit_length()-1;fb=2e-14*(digits+1)*size*size;rb=4e-14*(digits+1)*size
    fe=be=0.0
    small=dft([complex(i) for i in range(size)])if size<=16 else None
    for k,((real,imag),(br,bi))in enumerate(zip(forward,back)):
        if k==0:er,ei=size*(size-1)/2,0.0
        else:
            theta=math.pi*min(k,size-k)/size
            er=-size/2;ei=(1 if k<=size//2 else -1)*size/2*math.cos(theta)/math.sin(theta)
        error=max(abs(real-er),abs(imag-ei));berror=max(abs(br-k),abs(bi))
        assert all(math.isfinite(x)for x in [real,imag,br,bi])and error<=fb and berror<=rb,(size,k,error,fb,berror,rb)
        if small is not None:assert abs(complex(real,imag)-small[k])<=2*fb
        fe=max(fe,error);be=max(be,berror)
    metadata['profiles'].append({'size':size,'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest(),'frequency_max_error':fe,'frequency_bound':fb,'roundtrip_max_error':be,'roundtrip_bound':rb,'seconds':time.monotonic()-begin,'raw_retained':size<1048576})
    if size==1048576:output.unlink()
    print('PASS complete ramp',size,'forward error',fe,'roundtrip error',be,flush=True)
raw=subprocess.check_output([str(ref/'fft_observer'),'4','complex'],timeout=120,preexec_fn=bounded)
(ref/'complex-4.bin').write_bytes(raw)
xs=[1+2j,3-4j,-2+1j,.5+3j];actual=[complex(a,b)for a,b in struct.iter_unpack('<dd',raw)]
assert all(abs(a-b)<1e-12 for a,b in zip(actual[:4],dft(xs)))
assert all(abs(a-b.conjugate())<1e-12 for a,b in zip(actual[4:],xs))
metadata['complex_case']={'sha256':hashlib.sha256(raw).hexdigest(),'ifft_convention':'conjugate of general inverse'}
(ref/'metadata.json').write_text(json.dumps(metadata,indent=2)+'\n')
print('PASS independent complex DFT and source inverse convention')
