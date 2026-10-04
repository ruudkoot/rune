from pathlib import Path
root=Path(__file__).parent
for profile in ['smoke','normal','large']:
    text=(root/profile/'input').read_text()
    rows=text.split('\n');rows.pop() if text.endswith('\n') else None
    entries=[];entry=[]
    for row in rows:
        if row.strip(' \t')=='':
            if entry:entries.append(entry);entry=[]
        else:entry.append(row)
    if entry:entries.append(entry)
    result='% Latex Mailing List.\n\n\\input{labels.sty}\n\n\\begin{document}\n\n'
    for start in range(0,len(entries),30):
        page=entries[start:start+30];page+= [[]]*(30-len(page))
        result+='\\lpage\n'
        for offset,size,kind in [(0,9,'l'),(9,9,'l'),(18,9,'l'),(27,3,'s')]:
            labels=[''.join(line+'\\\\ ' for line in (entry[:4]+['']*4)[:4]) for entry in page[offset:offset+size]]
            result+='{\\'+kind+'block{\n'+'\n}{\n'.join(labels)+'\n}}\n'
    result+='\n\\end{document}\n'
    assert result==(root/profile/'input.tex').read_text()
    print(profile,len(entries),len(result),'bytes: complete independent output agrees')
