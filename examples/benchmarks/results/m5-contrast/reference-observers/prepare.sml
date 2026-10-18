structure SauvolaPrepare=
struct
 structure I=BenchSauvolaImage
 val image=I.read"tests/out/benchmarks/sauvola-originals/source/example2_small.ppm"
 val _=I.writeP3"tests/out/benchmarks/sauvola-originals/smoke.ppm"(I.sub image 0 0 32 32)
 val _=I.writeP3"tests/out/benchmarks/sauvola-originals/normal.ppm"(I.sub image 40 40 64 48)
 val _=I.writeP3"tests/out/benchmarks/sauvola-originals/large.ppm"image
end
