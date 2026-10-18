from pathlib import Path
import subprocess
p=Path(__file__).resolve().parent
subprocess.run(['python3',str(p/'make-tests.py')],check=True)
text=(p/'tests.sml').read_text();assert text.endswith('end\n')
(p/'tests-final.sml').write_text(text[:-4]+(p/'tests-extra.sml').read_text()+'end\n')
