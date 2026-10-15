from pathlib import Path
import subprocess,calendar,resource
p=Path(__file__).parent;source=Path('/home/ruud/reference/ghc/nofib/spectral/calendar/Main.hs')
subprocess.run(['ghc','-O2','-outputdir',str(p/'build'),'-o',str(p/'original'),str(source)],check=True,stdout=(p/'build.log').open('w'),stderr=subprocess.STDOUT)
(p/'Kernel.hs').write_text(source.read_text().replace('#define fail ioError','#define fail ioError').replace('{-# LANGUAGE CPP #-}','{-# LANGUAGE CPP #-}\nmodule Kernel where',1))
(p/'Observer.hs').write_text('module Main where\nimport qualified Kernel as K\nimport System.Environment\nmain=getArgs >>= \\[year] -> putStr(K.cal(read year::Int))\n')
subprocess.run(['ghc','-O2','-i'+str(p),'-outputdir',str(p/'observer-build'),'-o',str(p/'observer'),str(p/'Observer.hs')],check=True,stdout=(p/'observer-build.log').open('w'),stderr=subprocess.STDOUT)
def center(text,width):
 gap=width-len(text);left=gap//2
 return ' '*left+text+' '*(gap-left)
def picture(year):
 result=[center(str(year),75),' '*75]
 months=[]
 for month in range(1,13):
  monday,days=calendar.monthrange(year,month);first=(monday+1)%7
  cells=[f'{d:3d}'if 1<=d<=days else'   'for d in range(1-first,43-first)]
  rows=[center(calendar.month_name[month],21),' Su Mo Tu We Th Fr Sa']+[''.join(cells[i:i+7])for i in range(0,42,7)]
  months.append(['  '+row+'  'for row in rows]+[' '*25])
 for start in range(0,12,3):result+=[''.join(row)for row in zip(*months[start:start+3])]
 return '\n'.join(result)+'\n'
def limits():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
with(p/'reference.log').open('w')as log:
 for year in [1,4,100,400,1900,1994,2000,2024,9999,11993,51993]:
  result=subprocess.run([str(p/'observer'),str(year)],capture_output=True,check=True,timeout=30,preexec_fn=limits)
  assert result.stdout==picture(year).encode(),year
  (p/(str(year)+'.txt')).write_bytes(result.stdout)
  print('PASS full independent Gregorian layout',year,len(result.stdout),file=log,flush=True)
 for profile,n in [('smoke',2),('normal',10000),('large',50000)]:
  result=subprocess.run([str(p/'original'),'1993',str(n)],capture_output=True,check=True,timeout=120,preexec_fn=limits)
  assert result.stdout==b'2888\n'*n
  (p/(profile+'.stdout')).write_bytes(result.stdout)
  print('PASS original length-observed workload',profile,n,file=log,flush=True)
