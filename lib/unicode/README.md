# Unicode

<!-- Area: Text and terminals -->

UTF-8, read and written strictly, the display width of a code point,
grapheme clusters as Unicode Standard Annex #29 defines them, the
normalisation forms NFC and NFD of Annex #15, the identifiers of Annex #31
with the profile that Rune takes for Standard ML, and the security
mechanisms of Unicode Technical Standard #39.

The tables are made from the Unicode Character Database by
`bin/rune-generate unicode`, all of one version. The profile of
`Identifier` leaves out two sets that the script writes down and freezes
at Unicode 18.0.0, so that no later version of Unicode changes which names
are valid; the data of `UnicodeSecurity` change with every version, and
suit warnings rather than rules.
