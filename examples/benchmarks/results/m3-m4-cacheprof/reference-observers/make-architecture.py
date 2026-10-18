from pathlib import Path
import re,json,hashlib
p=Path(__file__).resolve().parent
source=(p.parent/'pinned/nofib/real/cacheprof/Arch_x86.hs').read_text()
notice=re.search(r'\{-\n   This file is part of Cacheprof.*?-\}',source,re.S)[0][2:-2]
assert 'Copyright (C) 1999 Julian Seward'in notice
enum=source.split('data Opcode',1)[1].split('deriving',1)[0]
ops=re.findall(r'\bO_[a-zA-Z0-9_]+\b',enum)
assert len(ops)==len(set(ops))
body=source.split('x86info\n',1)[1].split('data OperandInfo',1)[0]
body=re.sub(r'--[^\n]*','',body)
entries=re.findall(r'\((O_\w+),\s*(OI\s*\[[^\]]*\]|OI_\w+)\s*\)',body)
assert len(entries)==len(ops)and{op for op,info in entries}==set(ops),(len(entries),len(ops))
def info(text):
 def effect(match):
  name=match[1];values=match[2].split()
  return name+' '+values[0]if len(values)==1 else name+'('+','.join(values)+')'
 return re.sub(r'(OE_\w+)((?:\s+\d+)+)',effect,text)
lines=['(*'+notice+'*)','structure BenchCacheprofArch=struct',' datatype opcode='+'|'.join(ops),
' datatype effect=OE_RR of int*int|OE_RM of int*int|OE_RW of int*int|OE_R of int|OE_M of int|OE_W of int|OE_nW of int|OE_RRM of int*int*int',
' datatype operandInfo=OI of effect list|OI_Jumpy|OI_NoEffect|OI_Error|OI_Special',
' val x86info=['+','.join('('+op+','+info(oi)+')'for op,oi in entries)+']',
' fun name opcode=case opcode of '+'|'.join(op+'=>"' +op[2:]+'"'for op in ops),
' val nonJumpyOpcodes=['+','.join(re.findall(r'\bO_\w+\b',re.search(r'(?m)^nonJumpyOpcodes\s*\n\s*=\s*\[([^\]]*)\]',source)[1]))+']',
' fun getOperandInfo opcode=case List.filter(fn(opc,_)=>opc=opcode)x86info of[(_,info)]=>info|_=>raise Fail"cacheann: missing operand information"',
'end']
(p/'architecture.sml').write_text('\n'.join(lines)+'\n')
(p/'architecture-identities.json').write_text(json.dumps({'source_sha256':hashlib.sha256(source.encode()).hexdigest(),'opcodes':len(ops),'entries':len(entries),'enum_order':ops,'table':entries},indent=2)+'\n')
print('Generated',len(ops),'original opcode constructors and table entries')
