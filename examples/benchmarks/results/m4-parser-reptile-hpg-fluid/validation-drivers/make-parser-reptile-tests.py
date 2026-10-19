from pathlib import Path
import shutil
root=Path.cwd();private=root/'tests/out/benchmarks';tests=root/'tests/benchmarks'
readline='fun read file=let val f=TextIO.openIn file in TextIO.inputAll f before TextIO.closeIn f end\n'
def readsource(f):return f.read_text().replace(readline,'')
def rewrite(source,family):
 return source.replace('read(', 'BenchApplicationTestIO.read(').replace('read file','BenchApplicationTestIO.read file')
def copy(src,dest):dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dest)
# Parser whole reports and hashes.
p=private/'nofib-parser-originals';d=tests/'data/nofib-parser';d.mkdir(exist_ok=True)
for profile,suffix in [('smoke','faststdin'),('normal','stdin'),('large','slowstdin')]:
 copy(private/('pinned/nofib/real/parser/parser.'+suffix),d/('inputs/parser.'+suffix))
 for suffix in ['raw','layout','result','hash']:copy(p/('stage-data/'+profile+'.'+suffix),d/('profiles/'+profile+'.'+suffix))
for sub,extensions in [('lexer-cases',['input','raw','layout']),('parse-cases',['input','reference'])]:
 for f in(p/sub).iterdir():
  if any(f.name.endswith('.'+ext)for ext in extensions):copy(f,d/sub/f.name)
parts=[]
for filename,kind in [('parser-probe.sml','report'),('hash-probe.sml','hash')]:
 s=readsource(p/filename)
 s=s.replace('val root="tests/out/benchmarks/"','val root="tests/benchmarks/data/nofib-parser/"')
 s=s.replace('pinned/nofib/real/parser/','inputs/').replace('nofib-parser-originals/stage-data/','profiles/')
 a=s.index('  in if actual=expected');b=s.index('\n val _=List.app one',a)
 s=s[:a]+'  in BenchApplicationTestIO.compare("nofib-parser/"+label+"/"+profile+"/'+kind+'",expected,actual)end\n'+s[b:]
 s=s.replace('ParserProbeFn','NofibParser'+kind.title()+'TestsFn').replace('NeedParser=','NeedParser'+kind.title()+'=').replace('StrictParser=','StrictParser'+kind.title()+'=')
 parts.append(rewrite(s,'parser'))
s=readsource(p/'lexer-probe.sml').replace('val root="tests/out/benchmarks/"','val root="tests/benchmarks/data/nofib-parser/"')
s=s.replace('pinned/nofib/real/parser/','inputs/').replace('nofib-parser-originals/stage-data/','profiles/')
a=s.index('        in if actual=expected');b=s.index('\n      val _=check"raw"',a)
s=s[:a]+'        in BenchApplicationTestIO.compare("nofib-parser/"+label+"/"+profile+"/"+phase,expected,actual)end\n'+s[b:]
s=s.replace('LexerProbeFn','NofibParserLexerTestsFn')
parts.append(rewrite(s,'parser'))
s=readsource(p/'lexer-cases-probe.sml').replace('tests/out/benchmarks/nofib-parser-originals/lexer-cases/','tests/benchmarks/data/nofib-parser/lexer-cases/')
a=s.index('           val same=');b=s.index('\n      val _=check"raw"',a)
s=s[:a]+'''           val same=if String.isPrefix"exception\\n"expected then trim output=trim expected else output=expected
       in T.check("nofib-parser/"^label^"/lexer/"^name^"/"^mode,fn()=>same)end
'''+s[b:]
s=s.replace('LexerProbeFn','NofibParserLexerCaseTestsFn')
parts.append(rewrite(s,'parser'))
s=readsource(p/'parse-cases-probe.sml').replace('tests/out/benchmarks/nofib-parser-originals/parse-cases/','tests/benchmarks/data/nofib-parser/parse-cases/')
a=s.index('   in if same then print');b=s.index('\n val _=List.app one',a)
s=s[:a]+'   in T.check("nofib-parser/"+label+"/typed/"+name+"/"+mode,fn()=>same)end\n'+s[b:]
s=s.replace('CasesProbeFn','NofibParserTypedCaseTestsFn')
parts.append(rewrite(s,'parser'))
s=readsource(p/'demand-probe.sml')
s=s.replace('fun check name valid=if valid then print("PASS "^label^" "^name^"\\n")else raise Fail name',
            'fun check name valid=T.check("nofib-parser/"+label+"/demand/"+name,fn()=>valid)')
parts.append(s)
(tests/'nofib-parser-tests.sml').write_text('\n'.join(parts))
# Reptile complete protocol, full transition traces and component bytes.
p=private/'nofib-reptile-originals';d=tests/'data/nofib-reptile';d.mkdir(exist_ok=True)
for profile,suffix in [('smoke','faststdin'),('normal','stdin'),('large','slowstdin')]:
 copy(private/('pinned/nofib/real/reptile/reptile.'+suffix),d/('inputs/reptile.'+suffix))
 copy(p/('stage-data/'+profile+'.protocol'),d/('profiles/'+profile+'.protocol'))
 copy(p/('state-data/'+profile+'.reference'),d/('states/'+profile+'.reference'))
for f in(p/'component-data').glob('*.reference'):copy(f,d/'components'/f.name)
parts=[]
for filename,kind in [('probe.sml','protocol'),('state-probe.sml','state')]:
 s=readsource(p/filename).replace('val root="tests/out/benchmarks/"','val root="tests/benchmarks/data/nofib-reptile/"')
 s=s.replace('pinned/nofib/real/reptile/','inputs/').replace('nofib-reptile-originals/stage-data/','profiles/').replace('nofib-reptile-originals/state-data/','states/')
 a=s.index('   in if actual=expected');b=s.index('\n val _=List.app one',a)
 s=s[:a]+'   in BenchApplicationTestIO.compare("nofib-reptile/"+label+"/"+profile+"/'+kind+'",expected,actual)end\n'+s[b:]
 s=s.replace('ReptileProbeFn','NofibReptileProtocolTestsFn').replace('StatesFn','NofibReptileStateTestsFn')
 parts.append(rewrite(s,'reptile'))
s=readsource(p/'components-probe.sml').replace('tests/out/benchmarks/nofib-reptile-originals/component-data/','tests/benchmarks/data/nofib-reptile/components/')
a=s.index('   in if actual=expected');b=s.index('\n val _=List.app check',a)
s=s[:a]+'   in BenchApplicationTestIO.compare("nofib-reptile/"+label+"/component/"+name,expected,actual)end\n'+s[b:]
s=s.replace('if K.number a=x andalso K.number b=y then print("PASS "^label^" rational\\n")else raise Fail"rational"',
            'T.check("nofib-reptile/"+label+"/rational/"+x+"/"+y,fn()=>K.number a=x andalso K.number b=y)')
parts.append(rewrite(s,'reptile'))
(tests/'nofib-reptile-tests.sml').write_text('\n'.join(parts))
for family in ['parser','reptile']:
 d=tests/('data/nofib-'+family)
 (d/'.gitattributes').write_text('# Exact independent original-language observations.\\n** -whitespace\\n'.replace('\\n','\n'))
 files=sorted(str(f.relative_to(root))for f in d.rglob('*')if f.is_file()and f.name!='FILES')
 (d/'FILES').write_text('\n'.join(files)+'\n')
print('Prepared parser and Reptile fixtures and portable assertions.')
