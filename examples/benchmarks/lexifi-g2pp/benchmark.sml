structure Benchmark=struct
 val name="lexifi-g2pp"
 fun run[limitText,path]=
   let val limit=BenchInput.between(1,20000)(BenchInput.integer limitText)
   in BenchG2Driver.run limit path end
 |run _=raise Fail"expected optimizer evaluation budget and reviewed reference"
end
