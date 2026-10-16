from pathlib import Path
p=Path(__file__).resolve().parent
f=p/'parsing.sml';s=f.read_text();f.with_name('parsing-before-spines.sml').write_text(s)
s=s.replace('struct\n  datatype','struct\n  structure L = BenchLazy\n  val defer = L.delay\n  val expose = L.force\n  datatype',1).replace("'a node D.t","'a node L.delay")
a=s.index('  type \'a parser');head,tail=s[:a],s[a:]
head=head.replace('D.delay','L.delay').replace('D.force xs','L.force xs').replace('D.force (ys ())','L.force (ys ())').replace('D.force (append','L.force (append')
# Sequence spines use L; result and data value cells still use selected D.
head=head.replace('Cons (L.delay (fn () => f (D.force x))','Cons (D.delay (fn () => f (D.force x))').replace('Cons (L.delay (fn () => x),','Cons (D.delay (fn () => x),')
tail=tail.replace('let val first = D.delay','let val first = L.delay').replace('case D.force (parser input)','case L.force (parser input)').replace('case D.force (parser (D.delay','case L.force (parser (D.delay')
f.write_text(head+tail)
f=p/'kernel.sml';s=f.read_text();f.with_name('kernel-before-spines.sml').write_text(s)
for before,after in [
 ('D.delay (fn () => P.Cons','P.defer (fn () => P.Cons'),
 ('case D.force entries of','case P.expose entries of'),
 ('fun loop seen xs = D.delay','fun loop seen xs = P.defer'),
 ('case D.force xs of','case P.expose xs of'),
 ('D.force (loop seen rest)','P.expose (loop seen rest)'),
 ('fun remove name names = D.delay','fun remove name names = P.defer'),
 ('case D.force names of','case P.expose names of'),
 ('then D.force rest','then P.expose rest'),
 ('fun freeMono mono = D.delay (fn () => D.force (freeNode','fun freeMono mono = P.defer (fn () => P.expose (freeNode'),
 ('(D.force first, D.force second)','(P.expose first, P.expose second)'),
 ('fun zip first second = D.delay','fun zip first second = P.defer'),
 ('returnI (All (D.delay','returnI (All (P.defer'),
 ('in D.force (minus','in P.expose (minus'),
 ('val testEnv = D.delay','val testEnv = P.defer'),
 ('fun cat parts = D.delay','fun cat parts = P.defer'),
 ('| first :: rest => D.force (P.append','| first :: rest => P.expose (P.append'),
 ('fun separated separator render values = D.delay','fun separated separator render values = P.defer'),
 ('and prefixed separator render values = D.delay','and prefixed separator render values = P.defer'),
 ('case D.force values of','case P.expose values of'),
 ('P.Cons (x,rest) => D.force (P.append','P.Cons (x,rest) => P.expose (P.append'),
 ('P.Cons (x,rest) => D.force (cat','P.Cons (x,rest) => P.expose (cat'),
 ('case D.force args of','case P.expose args of'),
 ('case D.force rest of','case P.expose rest of'),
 ('case D.force last of','case P.expose last of'),
 ('fun showMono depth input = D.delay (fn () => D.force (case D.force input','fun showMono depth input = P.defer (fn () => P.expose (case D.force input'),
 ('fun showTerm depth input = D.delay (fn () => D.force (case D.force input','fun showTerm depth input = P.defer (fn () => P.expose (case D.force input'),
 ('and showAbs input = D.delay (fn () => D.force (case D.force input','and showAbs input = P.defer (fn () => P.expose (case D.force input'),
 ('fun readInferShow line = D.delay (fn () => D.force (','fun readInferShow line = P.defer (fn () => P.expose ('),
 ('case D.force (P.lexactlyP','case P.expose (P.lexactlyP'),
 ('fun app emit text = case D.force text of','fun app emit text = case P.expose text of'),
]:s=s.replace(before,after)
# Arrow's second list cell is also a list spine.
s=s.replace('P.Cons (first, D.delay','P.Cons (first, P.defer')
f.write_text(s)
