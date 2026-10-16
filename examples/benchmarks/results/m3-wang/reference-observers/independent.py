from pathlib import Path
import json,subprocess,math
p=Path(__file__).resolve().parent;d=p/'wang'
def el21(rows):
 result=[rows[0]]
 for e,f,g,s in rows[1:]:
  a,b,c,r=result[-1];factor=e/b;result.append((-factor*a,f-factor*c,g,s-factor*r))
 return result
# Reverse recurrences evaluated iteratively in an independent mutable list.
def el22(rows):
 result=rows[-2:]
 for a,b,c,r in reversed(rows[:-2]):
  e,f,g,s=result[0];factor=c/f;result.insert(0,(a-factor*e,b,-factor*g,r-factor*s))
 return result

def el23(rows):
 result=[rows[-1]]
 for a,b,c,r in reversed(rows[:-1]):
  e,f,g,s=result[0];factor=c/f;result.insert(0,(a,b,0.0,r-factor*s))
 return result

def el1(x,y):
 a,b,c,r=x;e,f,g,s=y;factor=g/b;return e,f-factor*a,-factor*c,s-factor*r

def el31(rows,anchor):
 a,b,c,r=anchor;return [f/(s-(g/b)*r) for e,f,g,s in rows]+[r/b]

def el3(left,rows,right):
 ax,bx,cx,rx=left;ay,by,cy,ry=right
 return [f/((s-(e/bx)*rx)-(g/by)*ry) for e,f,g,s in rows]+[ry/by]

def solve(blocks):
 matrix1=[el22(el21(rows))for rows in blocks]
 first=[rows[0]for rows in matrix1[1:]];last=[rows[-1]for rows in matrix1]
 anchors=el23(el21([el1(x,y)for x,y in zip(first,last[:-1])]+[last[-1]]))
 matrix2=[rows[:-1]for rows in matrix1]
 # Preserve f_dist: it pairs its first anchor with the FIRST matrix2 block.
 return [el31(matrix2[0],anchors[0])]+[el3(a,m,b)for a,m,b in zip(anchors,matrix2,anchors[1:])]

def nonuniform(n):
 count=n*(n+1);z=lambda i:1+(i%7)/4;rows=[]
 for i in range(count):
  a=0 if i==0 else -1-(i%3)/8;b=5+(i%5)/4;c=0 if i==count-1 else .5+(i%2)/8
  rows.append((a,b,c,a*z(i-1)+b*z(i)+c*z(i+1)))
 return [rows[i:i+n+1]for i in range(0,count,n+1)]

meta=[]
for n in [2,3,4,5,7]:
 raw=subprocess.check_output([str(d/'nonuniform'),str(n)],cwd=d,timeout=30);(p/('nonuniform-'+str(n)+'.values')).write_bytes(raw);actual=[float(x)for x in raw.split()];blocks=nonuniform(n)
 (p/('nonuniform-'+str(n)+'.input')).write_text(''.join(' '.join(map(repr,r))+'\n'for block in blocks for r in block))
 expected=[v for row in solve(blocks)for v in row];assert len(actual)==len(expected)==n*(n+1)
 assert all(math.isfinite(a)and a.hex()==b.hex()for a,b in zip(actual,expected))
 meta.append(dict(n=n,count=len(actual),original_blocked_model_bit_mismatches=0,maximum_difference_from_manufactured_flattened_solution=max(abs(v-(1+(i%7)/4))for i,v in enumerate(actual))))
for profile,n in [('smoke',25),('normal',80),('large',150)]:
 rows=[(0.0,3.0,2.0,5.0)]+[(2.0,3.0,2.0,7.0)]*(n*(n+1)-2)+[(2.0,3.0,0.0,5.0)]
 expected=[v for row in solve([rows[i:i+n+1]for i in range(0,len(rows),n+1)])for v in row];actual=[float(x)for x in(p/(profile+'.values')).read_text().split()]
 assert len(actual)==len(expected) and all(a.hex()==b.hex()for a,b in zip(actual,expected))
meta.append(dict(source_scope='Do not replace source f_dist indexing with a flattened scalar tridiagonal solver; their nonuniform results differ. The selected uniform fixed benchmark agrees with one within recorded bounds.'))
(p/'independent-metadata.json').write_text(json.dumps(meta,indent=2)+'\n')
print('PASS independent mutable blocked model: all original 29780 uniform values and 124 nonuniform values agree bit for bit; source f_dist indexing retained')
