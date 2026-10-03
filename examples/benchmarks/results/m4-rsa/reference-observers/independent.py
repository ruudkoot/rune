from pathlib import Path
modulus = 2036450659413645137870851576872812267542175329986469156678671505255564383842535488743101632280716717779536712424613501441720195827856504007305662157107
exponent = 387784473137902876992546516170169092918207676456888779623592396031349415024943784869634893342729620092877891356118467738167515879252473323905128540213
width = len(str(modulus))*47//100
suite = Path("examples/benchmarks/rsa-lazy")
for profile, repetitions in [("smoke",1),("normal",10),("large",150)]:
    data = (suite/"DATA"/(profile+".txt")).read_bytes()
    blocks = []
    for offset in range(0,len(data),width):
        number = 0
        for byte in data[offset:offset+width]:
            number = 128*number+byte
        blocks.append(str(pow(number,exponent,modulus)))
    ciphertext = "\n".join(blocks)+"\n" if blocks else ""
    assert ciphertext == (suite/"expected"/(profile+".txt")).read_text()
    hash_value = 0
    for byte in ciphertext.encode("ascii"):
        hash_value = (hash_value*31+byte)%2**64
    if hash_value >= 2**63:
        hash_value -= 2**64
    expected = int((suite/(profile+".expected")).read_text().replace("~","-"))
    assert repetitions*hash_value == expected
    print(profile,"all ciphertext blocks and hash sums agree")
