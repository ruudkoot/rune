structure MiniLightProfileTests=struct
 val _=print(BenchMiniCheck.run "tests/out/benchmarks/minilight-originals/smoke.model" "tests/out/benchmarks/minilight-originals/smoke.reference"^"\n")
 val _=print(BenchMiniCheck.run "tests/out/benchmarks/minilight-originals/normal.model" "tests/out/benchmarks/minilight-originals/normal.reference"^"\n")
end
