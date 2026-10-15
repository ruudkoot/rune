from pathlib import Path
from collections import Counter
for profile,n in [('smoke',500),('normal',3500),('large',16000)]:
    values=[];seed=1967
    for _ in range(n):values.append(seed);seed=(77*seed+1)%1024
    expected=''.join(f'{k} {v}\n' for k,v in sorted(Counter(values).items()))
    actual=(Path(__file__).parent/(profile+'-ghc-histogram.txt')).read_text()
    assert expected==actual
    print(profile,n,sum(values),'matches both original sorts and independent RNG histogram')
