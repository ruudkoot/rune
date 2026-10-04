from pathlib import Path
from itertools import combinations
import ast
root=Path(__file__).parent
for i,text in enumerate((root/'cycle.txt').read_text().splitlines(),1):
    i%=100
    people=[('Simon',[35,27,40,i,34,21]),('Hans',[23,19,45,i,17,10,5,8,14]),('Phil',[1,18,i,20,21,19,34,8,16,21]),('Kevin',[9,23,17,54,i,41,9,18,14])]
    actual=ast.literal_eval(text)
    expected=[]
    for name,scores in people:
        selected=[]
        while True:
            candidates=sorted((sum(triple),list(triple))for triple in combinations(scores,3))
            choice=None
            for award,threshold in [('Gold',70),('Silver',60),('Bronze',50)]:
                eligible=[pair for pair in candidates if pair[0]>=threshold]
                if eligible:choice=(award,eligible[0]);break
            if choice is None:break
            selected.append(choice)
            for score in choice[1][1]:scores.remove(score)
        expected.append((name,selected))
    assert actual==expected,(i,actual,expected)
print('All 100 source inputs agree with independent combinations/sort/greedy selection')
