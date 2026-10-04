from pathlib import Path
root=Path(__file__).parent
for n,index in [(5,0),(15,5),(27,49),(29,181)]:
    seed=[0,0,0,1,1,1,1,1,0,1,1,1,1,1,0,1,1,1,1,1,0,1,1,1,1,1,0]
    grid=[[int(y==14 and x<len(seed) and seed[x]) for x in range(n)]for y in range(n)]
    step=0
    while True:
        nxt=[]
        for y in range(n):
            row=[]
            for x in range(n):
                neighbours=sum(grid[j][i] for j in range(max(0,y-1),min(n,y+2)) for i in range(max(0,x-1),min(n,x+2)) if (i,j)!=(x,y))
                row.append(int(neighbours==3 or (neighbours==2 and grid[y][x])))
            nxt.append(row)
        if nxt==grid:break
        grid=nxt;step+=1
        assert step<1000
    rendered=str(step)+'\n\n'+''.join(''.join(' o' if cell else '  ' for cell in row)+'\n' for row in grid)
    assert step==index
    assert rendered==(root/f'{n}-display.txt').read_text()
print('Independent synchronous array oracle agrees on all four complete displays')
