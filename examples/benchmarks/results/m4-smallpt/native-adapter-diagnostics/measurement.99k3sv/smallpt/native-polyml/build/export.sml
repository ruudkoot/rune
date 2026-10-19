val _ = use "/home/ruud/rune/.worktrees/benchmarks/tests/out/benchmarks/measurement.99k3sv/smallpt/native-polyml/build/sources/1.sml";
val _ = use "/home/ruud/rune/.worktrees/benchmarks/tests/out/benchmarks/measurement.99k3sv/smallpt/native-polyml/build/sources/2.sml";
val _ = use "/home/ruud/rune/.worktrees/benchmarks/tests/out/benchmarks/measurement.99k3sv/smallpt/native-polyml/build/sources/3.sml";
val _ = use "/home/ruud/rune/.worktrees/benchmarks/tests/out/benchmarks/measurement.99k3sv/smallpt/native-polyml/build/sources/4.sml";
val _ = use "/home/ruud/rune/.worktrees/benchmarks/tests/out/benchmarks/measurement.99k3sv/smallpt/native-polyml/build/sources/5.sml";
fun main () = OS.Process.exit (BenchMeasure.main ());
