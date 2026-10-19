structure Benchmark=struct
 val name="contrast"
 fun run[image,referencePrefix]=BenchSauvolaDriver.run image referencePrefix
 |run _=raise Fail"expected PPM image and reviewed reference prefix"
end
