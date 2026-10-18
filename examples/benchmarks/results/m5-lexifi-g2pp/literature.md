# G2++ literature review scope

[Storn and Price (1997)](https://link.springer.com/article/10.1023/A:1008202821328),
publisher abstract and bibliographic record inspected on 2026-10-18, supplies
continuous global-optimization context. The full subscription article was not
reviewed. LexiFi's source establishes its actual population rule, changing
differential weight, best/random base choice, distinct-index draws and
recombination order. The paper does not establish those source-specific details.

[Brigo and Mercurio, second edition](https://link.springer.com/book/10.1007/978-3-540-34604-3),
publisher metadata inspected, records the 2006 edition. The source comments cite
the book with a 2005 date; the preserved README also points to a chapter excerpt.
These are literature anchors, not a claimed full derivation review. Original
prices, source equations and numerical checks support this translation.

Source inspection establishes the error-function approximation, Brent-style
root search, eleven quadrature nodes and shared mutable pricer arrays.
Independent date differences, erf/square-root observations, exact source
optimizer traces and recomputed RMS support narrower correctness claims.
Closure specialization, array representation, transcendental operations,
root stopping behavior and allocation remain performance hypotheses until
separately measured or established by compiler inspection.
