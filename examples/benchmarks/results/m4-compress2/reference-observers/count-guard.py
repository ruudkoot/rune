"""Bound a child process tree without changing its benchmark configuration."""
from pathlib import Path
import argparse,json,os,signal,subprocess,time

parser=argparse.ArgumentParser()
parser.add_argument('--log',required=True)
parser.add_argument('--record',required=True)
parser.add_argument('--rss-kib',type=int,default=8*1024*1024)
parser.add_argument('--available-kib',type=int,default=4*1024*1024)
parser.add_argument('command',nargs=argparse.REMAINDER)
args=parser.parse_args();command=args.command
if command and command[0]=='--':command=command[1:]
if not command:raise SystemExit('missing command')
def snapshot():
    result={}
    for path in Path('/proc').iterdir():
        if not path.name.isdigit():continue
        try:
            fields=(path/'stat').read_text().rsplit(') ',1)[1].split()
            result[int(path.name)]=(int(fields[1]),int(fields[21])*os.sysconf('SC_PAGE_SIZE')//1024)
        except(OSError,ValueError,IndexError):pass
    return result
def available():
    return next(int(line.split()[1])for line in Path('/proc/meminfo').read_text().splitlines()if line.startswith('MemAvailable:'))
peak=0;peak_processes=[];minimum=available();reason=None;start=time.monotonic()
with Path(args.log).open('w')as log:
    child=subprocess.Popen(command,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
    while child.poll()is None:
        processes=snapshot();owned={child.pid}
        while True:
            expanded=owned|{pid for pid,(parent,_)in processes.items()if parent in owned}
            if expanded==owned:break
            owned=expanded
        rss=sum(processes[pid][1]for pid in owned if pid in processes)
        free=available();minimum=min(minimum,free)
        if rss>peak:
            peak=rss;peak_processes=[]
            for pid in owned:
                if pid in processes:
                    try:name=Path('/proc',str(pid),'comm').read_text().strip()
                    except OSError:name='exited'
                    peak_processes.append({'pid':pid,'name':name,'rss_kib':processes[pid][1]})
        if rss>args.rss_kib:reason='process-tree-rss-guard'
        elif free<args.available_kib:reason='host-available-memory-guard'
        if reason:
            for pid in sorted(owned,reverse=True):
                try:os.kill(pid,signal.SIGKILL)
                except ProcessLookupError:pass
            break
        time.sleep(0.05)
    status=child.wait()
record={'command':command,'exit':status,'guard_reason':reason,'rss_limit_kib':args.rss_kib,
        'minimum_available_kib':args.available_kib,'observed_peak_tree_rss_kib':peak,
        'observed_minimum_available_kib':minimum,'peak_processes':peak_processes,'elapsed_seconds':time.monotonic()-start}
Path(args.record).write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps(record))
raise SystemExit(1 if reason else status if status>=0 else 128-status)
