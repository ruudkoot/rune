from pathlib import Path
import ast
import json
p = Path(__file__).resolve().parent
lines = (p / 'circuit.output').read_text().splitlines()
names = ast.literal_eval(lines[0])
items = []
for line in lines[1:]:
    tokens = line.split()
    i, plus, minus = map(int, tokens[:3])
    tag, args = tokens[3], tokens[4:]
    if tag in 'gr':
        constructor = 'Conductor' if tag == 'g' else 'Resistor'
        expr = 'T.' + constructor + '(q ' + json.dumps(args[0]) + ' ' + json.dumps(args[1]) + ')'
    elif tag in 'clj':
        count = 3 if tag == 'j' else 2
        values = ['q ' + json.dumps(args[2*k]) + ' ' + json.dumps(args[2*k+1]) for k in range(count)]
        expr = 'T.' + {'c': 'Capacitor', 'l': 'Inductor', 'j': 'Junction'}[tag] + '(' + ','.join(values) + ')'
    else:
        count = int(args[0])
        values = ['(v ' + json.dumps(args[1+4*k]) + ' ' + json.dumps(args[2+4*k]) +
                  ',v ' + json.dumps(args[3+4*k]) + ' ' + json.dumps(args[4+4*k]) + ')' for k in range(count)]
        expr = 'T.' + ('Vsource' if tag == 'v' else 'Isource') + '(BenchStream.fromList [' + ','.join(values) + '])'
    items.append('(' + str(i) + ',' + str(plus) + ',' + str(minus) + ',' + expr + ')')
text = '''structure BenchScsCircuitFixture =
struct
  structure Q=BenchScsRational
  structure L=BenchLazy
  structure T=BenchScsTypes
  fun large text=valOf(IntInf.fromString(String.translate(fn #"-"=>"~"|c=>String.str c)text))
  fun q n d=L.delay(fn()=>Q.make(large n,large d))
  fun v n d=L.delay(fn()=>Q.real(Q.make(large n,large d)))
  val names=[''' + ','.join(json.dumps(n) for n in names) + ''']
  val circuit=[''' + ',\n    '.join(items) + ''']
end
'''
(p / 'circuit-fixture.sml').write_text(text)
