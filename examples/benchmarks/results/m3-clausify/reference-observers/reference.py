from pathlib import Path
import hashlib,itertools,json,subprocess,time,resource
ref=Path(__file__).resolve().parent
# Rebuild the unmodified original and export-only observer in private paths.
source=(ref/'Main.hs').read_text()
assert source.count('module Main(main) where')==1
(ref/'Kernel.hs').write_text(source.replace('module Main(main) where','module Kernel where'))
for kind,file in [('original','Main.hs'),('observer','Observer.hs')]:
    with (ref/(kind+'-build.log')).open('w') as log:
        subprocess.run(['/usr/bin/ghc','-O2','-i'+str(ref),'-outputdir',str(ref/('ghc-'+kind)),'-o',str(ref/kind),str(ref/file)],check=True,stdout=log,stderr=subprocess.STDOUT)
def bounded():
    resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
    resource.setrlimit(resource.RLIMIT_CPU,(120,120))
metadata=[]
for n,fixture in [(1,'clausify.faststdout'),(7,'clausify.stdout'),(35,'clausify.slowstdout')]:
    start=time.monotonic()
    result=subprocess.run([str(ref/'original'),str(n)],capture_output=True,timeout=120,preexec_fn=bounded)
    assert result.returncode==0,result.stderr
    assert result.stdout==(ref/fixture).read_bytes(),fixture
    (ref/f'original-{n}.output').write_bytes(result.stdout)
    metadata.append({'n':n,'repetitions':67,'bytes':len(result.stdout),'seconds':time.monotonic()-start})
(ref/'metadata.json').write_text(json.dumps(metadata,indent=2)+'\n')
precedence={'=':1,'>':2,'|':3,'&':4}
def parse(text):
    tokens=list(text.replace(' ',''));index=0
    def expr(minimum=0):
        nonlocal index
        token=tokens[index];index+=1
        if token=='~': left=('~',expr(5))
        elif token=='(':
            left=expr();assert tokens[index]==')';index+=1
        else: assert token.islower();left=token
        while index<len(tokens) and tokens[index] in precedence and precedence[tokens[index]]>=minimum:
            op=tokens[index];index+=1
            left=(op,left,expr(precedence[op])) # equal precedence associates right
        return left
    tree=expr();assert index==len(tokens);return tree
def cnf(tree,negative=False):
    if isinstance(tree,str):return [(frozenset() if negative else frozenset(tree),frozenset(tree) if negative else frozenset())]
    op,*args=tree
    if op=='~':return cnf(args[0],not negative)
    a,b=args
    if op=='>':return cnf(('|',('~',a),b),negative)
    if op=='=':return cnf(('&',('>',a,b),('>',b,a)),negative)
    left,right=cnf(a,negative),cnf(b,negative)
    if (op=='&')!=negative:return left+right
    return [(p|q,n|m) for p,n in left for q,m in right]
def clauses(tree):return sorted(set((tuple(sorted(p)),tuple(sorted(n))) for p,n in cnf(tree) if not p&n))
def display(cs):return ''.join(''.join(c+' ' for c in p)+'<= '+''.join(c+' ' for c in n)+'\n' for p,n in cs)
def truth(tree,env):
    if isinstance(tree,str):return env[tree]
    op,*args=tree
    if op=='~':return not truth(args[0],env)
    a,b=(truth(x,env) for x in args)
    return {'&':a and b,'|':a or b,'>':not a or b,'=':a==b}[op]
base=['a','~a','a|~a','a&a','a|b','a&b','a>b','a=b','a=b=c','a>b>c','~(a|b)','~(a&b)','~~a','(a&b)|(c&d)','(a=b)=(b=c)','(a = a = a) = (a = a = a) = (a = a = a)']
# Also check all operators, both association choices, negation and mixed symbols.
formulas=base+[f'({a}{op}{b}){outer}{c}' for a,b,c in [('a','b','c'),('a','a','b')] for op in precedence for outer in precedence]
records=[];chunks=[]
for i,text in enumerate(formulas):
    ast=parse(text);cs=clauses(ast);expected=display(cs).encode()
    actual=subprocess.check_output([str(ref/'observer'),text],timeout=60)
    assert actual==expected,(text,actual,expected)
    symbols=sorted(set(c for c in text if c.islower()))
    for bits in itertools.product([False,True],repeat=len(symbols)):
        env=dict(zip(symbols,bits))
        value=all(any(env[c] for c in p) or any(not env[c] for c in n) for p,n in cs)
        assert value==truth(ast,env),(text,env)
    (ref/f'case-{i:03}.expected').write_bytes(actual)
    records.append({'formula':text,'output':actual.decode(),'sha256':hashlib.sha256(actual).hexdigest()})
    chunks.append(str(i)+'\n'+actual.decode()+'END\n')
(ref/'cases.json').write_text(json.dumps(records,indent=2)+'\n')
(ref/'corpus.expected').write_text(''.join(chunks))
sample=base[-1];assert display(clauses(parse(sample)))=='a <= \n'
for n in [1,7,35]:
    actual=(ref/f'original-{n}.output').read_bytes()
    assert actual==display(clauses(parse(sample))).encode()*(67*n)
print(f'{len(records)} original/independent clause outputs and complete truth tables agree; all three original profiles agree')
