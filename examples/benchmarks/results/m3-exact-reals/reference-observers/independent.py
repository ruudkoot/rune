from pathlib import Path
import json
import mpmath as m
p=Path(__file__).resolve().parent
m.mp.dps=120
values={"pi":m.pi,"third":m.mpf(1)/3,"negative-third":-m.mpf(1)/3,"sqrt-half":m.sqrt(m.mpf(1)/2),"sin-quarter":m.sin(m.pi/4),"cos-quarter":m.cos(m.pi/4),"sin-negative-quarter":m.sin(-m.pi/4),"atan-minus-five":m.atan(-5),"atan-minus-one":m.atan(-1),"atan-minus-half":m.atan(-m.mpf(1)/2),"atan-zero":m.mpf(0),"atan-fifth":m.atan(m.mpf(1)/5),"atan-one":m.atan(1),"atan-five":m.atan(5)}
integer_errors=[];text_errors=[]
for line in (p/"extra-values.txt").read_text().splitlines():
    name,kind,*fields=line.split()
    if kind=="bits":
        precision,actual=map(int,fields)
        error=abs(m.mpf(actual)-values[name]*m.power(2,precision))
        assert error<=1,(name,precision,error)
        integer_errors.append(error)
    else:
        assert kind=="text"
        error=abs(m.mpf(fields[0])-values[name])
        assert error<=m.mpf("5.1e-41"),(name,error)
        text_errors.append(error)
metadata=dict(mpmath=m.__version__,decimal_digits=m.mp.dps,scaled_integer_checks=len(integer_errors),maximum_scaled_error=str(max(integer_errors)),decimal_text_checks=len(text_errors),scope="independent numerical reference for GHC approximants, not a formal proof")
assert metadata["scaled_integer_checks"]==84 and metadata["decimal_text_checks"]==14
(p/"independent-metadata.json").write_text(json.dumps(metadata,indent=2)+"\n")
print(json.dumps(metadata,indent=2))
