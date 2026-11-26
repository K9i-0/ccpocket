# Notices

`markdown_kit` is released under the MIT License (see [LICENSE](LICENSE)), with
the one exception below.

## Third-party content under a different license

- `test/commonmark_spec/spec.json` — the example set of the
  [CommonMark specification 0.31.2](https://spec.commonmark.org/0.31.2/) by
  John MacFarlane, licensed
  [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/). It is
  included unmodified and used only as test input. It is not covered by the MIT
  License.

## Acknowledgements

The design of this package and the scope of its test suite were informed by two
packages. No source code or test code was copied from them.

- [flutter_md](https://github.com/DoctorinaAI/md) (MIT) — selection engine,
  edge autoscroll and copy formatters.
- [gpt_markdown](https://github.com/useval/gpt_markdown) (BSD-style) —
  `RenderParagraph`-based rendering, tables, streaming, caching and slivers.
