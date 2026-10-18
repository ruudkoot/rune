from pathlib import Path
import json,sys
sys.setrecursionlimit(100000)
p=Path(__file__).resolve().parent
def sequence(tree):
 values=[]
 while tree[0]=='(:)':values.append(tree[1]);tree=tree[2]
 assert tree==['[]'];return values
def literal(text):return 'text '+json.dumps(text)
def listExpr(tree,render):return'list ['+','.join(render(x)for x in sequence(tree))+']'
def expr(tree):
 name,*a=tree
 if name=='F_Tail':return'tailExpr (fromInt '+str(a[0])+') ('+expr(a[1])+')'
 if name=='F_Cons':return'consExpr (fromInt '+str(a[0])+') ('+expr(a[1])+') ('+expr(a[2])+')'
 if name=='F_Map':return'mapExpr (fromInt '+str(a[0])+') ('+literal(a[1])+') ('+listExpr(a[2],expr)+')'
 if name=='F_Maps':return'mapsExpr (fromInt '+str(a[0])+') ('+literal(a[1])+') ('+literal(a[2])+') ('+expr(a[3])+') ('+listExpr(a[4],expr)+')'
 if name=='F_Ap':return'ap ('+literal(a[0])+') ('+listExpr(a[1],expr)+')'
 if name=='F_Tuple':return'tuple ('+listExpr(a[0],expr)+')'
 if name=='F_Var':return'var ('+literal(a[0])+')'
 if name=='F_Lit':return'lit ('+literal(a[0])+')'
 raise ValueError(tree)
def where(tree):
 if tree[0]=='C_NoWhere':return'noWhere()'
 assert tree[0]=='F_Where';return'whereExpr ('+listExpr(tree[1],definition)+')'
def definition(tree):
 name,*a=tree
 if name=='F_Caf':return'caf ('+listExpr(a[0],literal)+') ('+expr(a[1])+')'
 assert name=='F_Def'
 return'def ('+literal(a[0])+') ('+listExpr(a[1],literal)+') ('+expr(a[2])+') ('+where(a[3])+')'
names=[line.split('\t')[0]for line in (p/'observe.stdout').read_text().splitlines()]
text='fun parsedCases()=list ['+','.join('('+literal(n)+','+listExpr(json.loads((p/(n+'-parse.reference')).read_text()),definition)+')'for n in names)+']\n'
(p/'parsed-cases.sml').write_text(text)
print('source-derived AST constructor data',len(names))
