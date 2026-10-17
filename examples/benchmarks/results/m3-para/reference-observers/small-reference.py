from pathlib import Path
import subprocess
p=Path(__file__).resolve().parent
raw=(p/'source/runtime_files/input-data').read_bytes()
# Preserve complete paragraphs, not arbitrary truncations inside words.
marker=b'*END*THE SMALL PRINT! FOR PUBLIC DOMAIN ETEXTS*Ver.04.29.93*END*'
start=raw.index(marker)+len(marker)
start=raw.find(b'FAR FROM THE MADDING CROWD',start)
cut=raw.find(b'\n\n',start+10000)+2
selected=raw[start:cut]
assert cut>start+10000 and b'Gutenberg'not in selected and b'GUTENBERG'not in selected
(p/'small.input').write_bytes(selected)
import json,hashlib
(p/'smoke-selection.json').write_text(json.dumps(dict(source='spectral/para/runtime_files/input-data',start_byte=start,end_byte=cut,bytes=len(selected),sha256=hashlib.sha256(selected).hexdigest(),selection='complete body paragraphs after the full historical header; no Project Gutenberg references retained'),indent=2)+'\n')
r=subprocess.run([str(p/'observer-source/observer'),str(p/'small.input')],stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=30,check=True)
(p/'small.reference').write_bytes(r.stdout)
print(cut,len(r.stdout))
