from pathlib import Path
import heapq
root=Path(__file__).parent
mod=2**64;sign=2**63;digit=10**18
wrap=lambda n: ((n+sign)%mod)-sign

def mul(n,p):
    low,high=p
    product=wrap(n*low)
    quotient=abs(product)//digit * (-1 if product<0 else 1)
    return product-quotient*digit,wrap(wrap(n*high)+quotient)

def render(p):
    low,high=p
    return str(low) if high==0 else str(high)+format(low,'018d')

# A cursor array is independent of the port's mutually recursive lazy lists.
values=[(1,0)];indices=[0,0,0];factors=[2,3,5]
for i in range(1,98000):
    candidates=[mul(n,values[j]) for n,j in zip(factors,indices)]
    chosen=min(candidates,key=lambda p:(p[1],p[0]))
    values.append(chosen)
    for j,candidate in enumerate(candidates):
        if candidate==chosen:indices[j]+=1
for profile,start,count in [('smoke',100,10),('normal',88000,200),('large',88000,10000)]:
    actual=(root/(profile+'.txt')).read_text()
    expected=''.join(render(p)+'\n' for p in values[start:start+count])
    assert expected==actual,(profile,'fixed-width reference mismatch')
    print(profile,'all values agree with independent signed-64-bit cursor oracle')

# The default normal window still agrees with mathematical Hamming numbers;
# the bytecode configuration's 10,000 outputs cross the source's overflow.
heap=[1];seen={1};exact=[]
for i in range(98200):
    value=heapq.heappop(heap);exact.append(value)
    for factor in factors:
        n=value*factor
        if n not in seen:seen.add(n);heapq.heappush(heap,n)
assert all(render(p)==str(n) for p,n in zip(values[88000:88200],exact[88000:88200]))
first=next(i for i,(p,n) in enumerate(zip(values,exact)) if render(p)!=str(n))
assert 88200<=first<98000
(root/'overflow.txt').write_text(f'First mathematical divergence at zero-based index {first}: source {render(values[first])}, exact {exact[first]}\n')
print('First source overflow divergence:',first)
