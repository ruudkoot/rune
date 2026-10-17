from pathlib import Path
import json
p=Path(__file__).resolve().parent
wins=((0,1,2),(3,4,5),(6,7,8),(0,3,6),(1,4,7),(2,5,8),(0,4,8),(2,4,6))
def static(b):
    total=0
    for line in wins:
        v=sum(1 if b[i]=='X' else -1 if b[i]=='O' else 0 for i in line)
        if v==3:return(1,0)
        if v==-3:return(-1,0)
        total+=v
    return(0,total)
def evaluate(b,p,depth):
    s=static(b)
    if depth==0 or s[0] or '.'not in b:return s
    values=[evaluate(b[:i]+p+b[i+1:],'O'if p=='X'else'X',depth-1)for i,v in enumerate(b)if v=='.']
    return (max if p=='X'else min)(values)
def game(b):
    result="OXO\n";p='X'
    while '.'in b and not static(b)[0]:
        choices=[b[:i]+p+b[i+1:]for i,v in enumerate(b)if v=='.']
        values=[evaluate(c,'O'if p=='X'else'X',5)for c in choices]
        v=(max if p=='X'else min)(values);b=choices[values.index(v)]
        result+=show(v)+"\n"+"\n------\n".join("|".join(b[i:i+3]).replace('.',' ')for i in [0,3,6])+"\n\n"
        p='O'if p=='X'else'X'
    return result
def show(v):
    return "XWin"if v[0]==1 else"OWin"if v[0]==-1 else"Score "+str(v[1])if v[1]>=0 else"Score ("+str(v[1])+")"
default=".O..X...."
assert game(default)==(p/'game.txt').read_text()
cases=[default,"XO.XO....","XOXXO.O..","XXXOO....","OOOXX....","XOXOXOXOX","XXXOOO...","OOOXXX...",".XO.OXX..","XX.OO....","X.O.O.X.."]
(p/'cases.json').write_text(json.dumps([dict(board=b,static=show(static(b)),max=show(evaluate(b,'X',5)),min=show(evaluate(b,'O',5)))for b in cases],indent=2)+"\n")
print("Independent full game and",len(cases),"position analyses ready")
