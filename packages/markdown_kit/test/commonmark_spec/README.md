# CommonMark specification examples

`spec.json` is the example set of the CommonMark specification 0.31.2
(https://spec.commonmark.org/0.31.2/), by John MacFarlane, licensed
CC BY-SA 4.0 (https://creativecommons.org/licenses/by-sa/4.0/). It is used
unmodified as test input.

`commonmark_spec_test.dart` runs every example through `GfmMarkdownParser` and
compares against the baseline in `baseline.json`. See the comment at the top of
that test for how the baseline works and how to regenerate it.
