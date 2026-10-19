val _ = use "/home/ruud/rune/.worktrees/benchmarks/tests/out/benchmarks/measurement.JADYnf/bytes_blit/native-smlnj-legacy/build/sources/1.sml";
val _ = use "/home/ruud/rune/.worktrees/benchmarks/tests/out/benchmarks/measurement.JADYnf/bytes_blit/native-smlnj-legacy/build/sources/2.sml";
val _ = use "/home/ruud/rune/.worktrees/benchmarks/tests/out/benchmarks/measurement.JADYnf/bytes_blit/native-smlnj-legacy/build/sources/3.sml";
val _ = use "/home/ruud/rune/.worktrees/benchmarks/tests/out/benchmarks/measurement.JADYnf/bytes_blit/native-smlnj-legacy/build/sources/4.sml";
val _ = use "/home/ruud/rune/.worktrees/benchmarks/tests/out/benchmarks/measurement.JADYnf/bytes_blit/native-smlnj-legacy/build/sources/5.sml";
val _ = use "/home/ruud/rune/.worktrees/benchmarks/tests/out/benchmarks/measurement.JADYnf/bytes_blit/native-smlnj-legacy/build/sources/6.sml";
val _ = SMLofNJ.exportFn ("/home/ruud/rune/.worktrees/benchmarks/tests/out/benchmarks/measurement.JADYnf/bytes_blit/native-smlnj-legacy/build/prog", fn _ => BenchMeasure.main ());
val _ = OS.Process.exit OS.Process.success;
