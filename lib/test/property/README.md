# Property testing

<!-- Area: Testing -->

Property testing in the style of QuickCheck. Generators draw values,
observers say what a generated function sees of its argument, printers show
a counterexample, and an arbitrary holds those with the equality of a type.
A property is what must hold for every value a generator draws, and it is
run over many cases, each from its own seed.
