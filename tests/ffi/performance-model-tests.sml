structure FfiPerformanceModelTests =
struct
  structure M=FfiPerformanceModel
  val row=Json.Object[("phase",Json.String "scalar"),("iterations",Json.int 2),("checksum",Json.String "2"),
    ("cpuSeconds",Json.Number "0.002"),("wallSeconds",Json.Number "0.003"),
    ("foreignResourcesBefore",Json.String "3"),("foreignResourcesAfter",Json.String "3"),
    ("smlAllocatedBytes",Json.int 8),("smlAllocatedObjects",Json.int 1),("collections",Json.int 0),
    ("bufferPayloadAllocatedBytes",Json.int 0),("peakBufferPayloadBytes",Json.int 0)]
  fun update(Json.Object fields) changes=Json.Object(List.filter(fn(key,_)=>not(List.exists(fn(name,_)=>key=name)changes))fields @ changes)
    | update _ _=raise Fail "expected object"
  fun rejects label body=Expect.raises(label,fn Fail _=>true | _=>false,body)
  val tests=Test.describe "ffi/performance-report"
    [Test.it "hand-calculated-quantiles"(fn()=>
       let val result=M.distribution[5.0,1.0,4.0,2.0,3.0]
       in List.app(fn(key,want)=>Expect.equal(Real.==,Real.toString)(key,want,fn()=>M.real(M.field key result)))
            [("min",1.0),("p25",2.0),("median",3.0),("p75",4.0),("p95",5.0),("max",5.0)] end),
     Test.it "even-median-and-empty-distribution"(fn()=>
       (Expect.equal(Real.==,Real.toString)("midpoint",2.5,fn()=>M.real(M.field "median"(M.distribution[4.0,1.0,3.0,2.0])));
        Expect.that("no samples stay unmeasured",M.distribution[]=Json.Null))),
     Test.it "valid-scalar-and-first-buffer"(fn()=>
       (M.checkRow row;
        M.checkRow(update row[("phase",Json.String "marshal-256-first"),("iterations",Json.int 1),("checksum",Json.String "1"),
          ("bufferPayloadAllocatedBytes",Json.int 256),("peakBufferPayloadBytes",Json.int 256)]))),
     Test.it "planted-checksum-failure"(fn()=>rejects "wrong native result"(fn()=>M.checkRow(update row[("checksum",Json.String "999")]))),
     Test.it "planted-resource-and-payload-failures"(fn()=>
       (rejects "resource delta"(fn()=>M.checkRow(update row[("foreignResourcesAfter",Json.String "4")]));
        rejects "unaccounted payload"(fn()=>M.checkRow(update row[("bufferPayloadAllocatedBytes",Json.int 256)])))),
     Test.it "planted-invalid-counter-failures"(fn()=>
       (rejects "negative CPU"(fn()=>M.checkRow(update row[("cpuSeconds",Json.Number "-1")]));
        rejects "negative allocation"(fn()=>M.checkRow(update row[("smlAllocatedBytes",Json.int ~1)]));
        rejects "no iterations"(fn()=>M.checkRow(update row[("iterations",Json.int 0)])))),
     Test.it "phase-inventory-failures"(fn()=>
       (rejects "missing phase"(fn()=>M.expectedPhases["scalar","callback"][row]);
        rejects "duplicate phase"(fn()=>M.expectedPhases["scalar","callback"][row,row]);
        M.expectedPhases["scalar"][row]))]
end
val ()=let val result=Suite.run{args=CommandLine.arguments(),print=print}FfiPerformanceModelTests.tests
  in if #failed result=0 then () else OS.Process.exit OS.Process.failure end
