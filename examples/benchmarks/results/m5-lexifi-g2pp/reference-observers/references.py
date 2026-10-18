from pathlib import Path
import subprocess,json,hashlib
p=Path(__file__).resolve().parent;d=p/'source'
s=(d/'main.ml').read_text().split('let () =')[0]
(d/'Data.ml').write_text(s)
source='''module D=Data
open G2pp_calibration
let run limit=
 let result=calibrate ~max_global:limit ~today:D.today ~swaption_quotes:D.swaption_quotes ~variables:D.variables ~zc:D.zc()in
 let {Optimization.cr_parameters=p;cr_root_mean_squared_error=rms;cr_quoted_prices=quotes;cr_calibrated_prices=prices}=result in
 Printf.printf "limit %d\\nparameters %.17g %.17g %.17g %.17g %.17g\\nrms %.17g\\n"limit p.g_a p.g_b p.g_sigma p.g_nu p.g_rho rms;
 Array.iteri(fun i value->Printf.printf "price %d %.17g %.17g\\n"i value quotes.(i))prices
let ()=List.iter run[40;2000;20000]
'''
(d/'Observer.ml').write_text(source)
with(d/'observer-build.log').open('w')as f:subprocess.run(['ocamlopt','-o','observer','date.cmx','math.cmx','optimization.cmx','g2pp_calibration.cmx','Data.ml','Observer.ml'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
out=subprocess.check_output([str(d/'observer')],cwd=d,timeout=600);(p/'profiles.reference').write_bytes(out)
blocks=out.decode().split('limit ')[1:];assert len(blocks)==3
records=[]
for block in blocks:
 lines=block.splitlines();limit=int(lines[0]);params=list(map(float,lines[1].split()[1:]));rms=float(lines[2].split()[1])
 prices=[list(map(float,line.split()[2:]))for line in lines[3:]];assert len(prices)==196
 records.append(dict(limit=limit,parameters=params,rms=rms,prices=prices))
(p/'profiles.json').write_text(json.dumps(records,indent=2)+'\n')
print('PASS original calibration profiles with all 196 calibrated/market prices and full parameter precision')
