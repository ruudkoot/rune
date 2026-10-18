from pathlib import Path
import subprocess,json,datetime,math
p=Path(__file__).resolve().parent;d=p/'source'
dates=['1980-01-01','1980-02-29','2000-02-29','2012-01-01','2012-01-31','2100-02-28','2299-12-31']
source='''let dates=['''+';'.join(json.dumps(x)for x in dates)+''']
let ()=List.iter(fun text->
 let date=Date.of_string text in
 Printf.printf "date %s %d\\n"text date;
 List.iter(fun months->let changed=Date.add_months date months in let g=Date.gregorian_of_date changed in
 Printf.printf "month %s %d %d %d %d %d\\n"text months changed g.Date.year g.Date.month g.Date.day)[-13;-1;0;1;13])dates
let ()=List.iter(fun x->Printf.printf "cdf %.17g %.17g\\n"x(Math.ugaussian_P x))[-8.;-3.;-1.;0.;1.;3.;8.]
let ()=let calls=ref[]in let root=Math.Rootfinder.brent 0. 2.(fun x->calls:=x:: !calls;x*.x-.2.)1e-10 in
 Printf.printf "root %.17g\\n"root;
 print_endline("order "^String.concat ","(List.map(Printf.sprintf "%.17g")(List.rev !calls)))
let ()=let calls=ref[]in let left()=calls:="left":: !calls;1. in let right()=calls:="right":: !calls;2. in
 ignore(left(),right()); print_endline("tuple "^String.concat ","(List.rev !calls));
 calls:=[];ignore(left()-.right());print_endline("subtract "^String.concat ","(List.rev !calls))
'''
(d/'Date_source.ml').write_bytes((d/'date.ml').read_bytes())
source=source.replace('Date.', 'Date_source.')
(d/'Support.ml').write_text(source)
with(d/'support-build.log').open('w')as f:subprocess.run(['ocamlopt','-o','support-observer','Date_source.ml','math.cmx','Support.ml'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
out=subprocess.check_output([str(d/'support-observer')],cwd=d,timeout=60);(p/'support.reference').write_bytes(out)
rows=out.decode().splitlines()
datesRecorded={}
for line in rows:
 fields=line.split()
 if fields[0]=='date':
  datesRecorded[fields[1]]=int(fields[2])
 if fields[0]=='cdf':
  x,y=map(float,fields[1:]);assert abs(y-(1+math.erf(x/math.sqrt(2)))/2)<1e-7
 if fields[0]=='root':assert abs(float(fields[1])-math.sqrt(2))<1e-10
for a in dates:
 for b in dates:
  assert (datesRecorded[a]-datesRecorded[b])/1440==(datetime.date.fromisoformat(a)-datetime.date.fromisoformat(b)).days
assert 'tuple right,left'in rows and 'subtract right,left'in rows
print('PASS source date/month/root/CDF observations; independent date differences, erf and square-root models; observed tuple/subtraction order')
