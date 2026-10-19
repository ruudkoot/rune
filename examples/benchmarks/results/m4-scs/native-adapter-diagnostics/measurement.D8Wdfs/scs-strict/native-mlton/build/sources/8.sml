structure BenchScsTypes =
struct
  type exact = BenchScsRational.t BenchLazy.delay
  type waveform = (real BenchLazy.delay * real BenchLazy.delay) BenchStream.stream
  datatype element = Conductor of exact | Resistor of exact
    | Capacitor of exact * exact | Inductor of exact * exact
    | Vsource of waveform | Isource of waveform | Junction of exact * exact * exact
  type circuit = (int * int * int * element) list
end
