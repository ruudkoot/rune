from pathlib import Path
import json,re
p=Path(__file__).resolve().parent
def paras(text):
 groups=[];current=[]
 for line in text.splitlines():
  words=line.split()
  if words:current.extend(words)
  elif current:groups.append(current);current=[]
 if current:groups.append(current)
 return groups
original=paras((p/'source/runtime_files/input-data').read_text())
rendered=(p/'formatted.reference').read_text().split('\n\n')
if rendered and not rendered[-1].strip():rendered.pop()
assert len(original)==len(rendered)
total=0;lines=0;gaps=[]
for index,(words,block) in enumerate(zip(original,rendered)):
 rows=block.splitlines()
 assert [w for row in rows for w in row.split()]==words
 assert all(len(row)<=70 for row in rows)
 dp=[0]*(len(words)+1)
 for i in range(len(words)-1,-1,-1):
  best=None;width=-1
  for j in range(i,len(words)):
   width+=1+len(words[j])
   if width>70:break
   value=0 if j+1==len(words)else(63-width)**2+dp[j+1]
   best=value if best is None else min(best,value)
  assert best is not None;dp[i]=best
 cost=sum((63-len(row))**2 for row in rows[:-1])
 assert cost>=dp[0]
 if cost!=dp[0]:gaps.append(dict(paragraph=index,source_cost=cost,optimal_cost=dp[0],word_prefix=words[:5]))
 total+=cost;lines+=len(rows)
record=dict(paragraphs=len(original),words=sum(map(len,original)),lines=lines,cost=total,all_widths_valid=True,all_words_preserved=True,optimal_cost_agreements=len(original)-len(gaps),source_suboptimal_paragraphs=gaps)
(p/'independent-metadata.json').write_text(json.dumps(record,indent=2)+'\n');print(record)
