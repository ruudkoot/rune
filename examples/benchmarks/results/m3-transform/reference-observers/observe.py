from pathlib import Path
import shutil,re,subprocess,json,resource
p=Path(__file__).resolve().parent;o=p/'observer-source';shutil.copytree(p/'source',o,dirs_exist_ok=True)
t=(o/'Main.hs').read_text().replace('module Main (main)','module Kernel')
t='{-# LANGUAGE DeriveDataTypeable #-}\n'+t.replace('    import System.Environment','    import Data.Data (Data, Typeable);\n    import System.Environment')
t=re.sub(r'(data\n\s+[^;]+)(;)',lambda m:m[1]+' deriving (Data,Typeable)'+m[2],t)
(o/'Kernel.hs').write_text(t)
names=re.findall(r'^\s+(c_\w+text)=',(p/'source/Main.hs').read_text(),re.M)
observer=r'''{-# LANGUAGE ScopedTypeVariables #-}
module Main where
import Kernel
import Data.Data
import Data.Char(ord)
quote s="\""++concatMap esc s++"\"" where
 esc '"'="\\\""
 esc '\\'="\\\\"
 esc '\n'="\\n"
 esc '\r'="\\r"
 esc '\t'="\\t"
 esc c=[c]
dump :: Data a=>a->String
dump x=case cast x of
 Just(n::Int)->show n
 Nothing->case cast x of
  Just(c::Char)->show(ord c)
  Nothing->case cast x of
   Just(s::String)->quote s
   Nothing->"["++quote(showConstr(toConstr x))++concatMap(","++)(gmapQ dump x)++"]"
stages text=
 let prepared=f_prepare text
     v=f_one_test "v" "v" f_id prepared
     v0=f_one_test "v0" "inl v" (f_lab . f_use . f_srt . f_inl . f_inl . f_use . f_srt) v
     v1=f_one_test "v1" "t1 v0" (f_lab . f_use . f_srt . f_t1) v0
     v3=f_one_test "v3" "t3 v1" (f_lab . f_use . f_srt . f_t3) v1
     v5=f_one_test "v5" "t5 v3" (f_srt . f_t5) v3
     v6=f_one_test "v6" "t6 v5" (f_inl . f_t6) v5
 in [("prepared",prepared),("v",v),("v0",v0),("v1",v1),("v3",v3),("v5",v5),("v6",v6)]
main=mapM_ observe INPUTS
 where
 observe(name,text)=do
  writeFile(name++".input")text
  writeFile(name++"-tokens.reference")(dump(f_lex text)++"\n")
  writeFile(name++"-parse.reference")(dump(f_parse(f_drop_pragma(f_lex text)))++"\n")
  writeFile(name++"-parse.pretty")(f_prm(f_parse(f_drop_pragma(f_lex text))))
  mapM_(\(stage,quad)->writeFile(name++"-"++stage++".reference")(dump quad++"\n"))(stages text)
  writeFile(name++"-report.reference")(f_test(f_prepare text))
  putStrLn(name++"\t"++show(length(f_test(f_prepare text))))
'''
values='['+','.join('('+json.dumps(n.removeprefix('c_').removesuffix('text'))+','+n+')'for n in names)+']'
(o/'Observe.hs').write_text(observer.replace('INPUTS',values))
with(p/'observer-build.log').open('w')as log:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','Observe.hs','-o','observe'],cwd=o,stdout=log,stderr=subprocess.STDOUT,check=True)
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
r=subprocess.run([str(o/'observe'),'+RTS','-M512m','-RTS'],cwd=p,capture_output=True,timeout=600,preexec_fn=cap)
(p/'observe.stdout').write_bytes(r.stdout);(p/'observe.stderr').write_bytes(r.stderr)
r.check_returncode()
print(r.stdout.decode())
