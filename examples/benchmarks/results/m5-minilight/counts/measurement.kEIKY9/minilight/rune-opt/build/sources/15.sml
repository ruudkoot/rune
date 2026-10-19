structure Benchmark=struct
 val name="minilight"
 fun run[model,reference]=BenchMiniCheck.run model reference
 |run _=raise Fail"expected MiniLight model and reviewed image reference"
end
