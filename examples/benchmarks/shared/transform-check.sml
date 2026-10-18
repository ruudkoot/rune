functor BenchTransformCheckFn(K:sig val run:int->(string*string*int)list->int end)=struct
 fun expected count=
   let val sizes=List.map #3 BenchTransformInputs.selected
       val total=List.foldl op+ 0 sizes
   in count div List.length sizes*total+List.foldl op+ 0(List.take(sizes,count mod List.length sizes))end
 fun run[countText]=
   let val count=BenchInput.between(0,20000)(BenchInput.integer countText)
       val result=K.run count BenchTransformInputs.selected
   in if result=expected count then Int.toString result
      else raise Fail"incorrect result: transform aggregate report length"end
 |run _=raise Fail"expected program count"
end
