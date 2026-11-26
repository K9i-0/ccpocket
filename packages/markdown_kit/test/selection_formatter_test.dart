import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_kit/markdown_kit.dart';

MarkdownSelectedContent _selectWholeDoc(
  MarkdownDocument doc, {
  String docId = 'doc1',
}) {
  final lastBlockIdx = doc.blocks.length - 1;
  final lastBlockLen = extractBlockRenderedText(
    doc.blocks[lastBlockIdx],
  ).length;
  return MarkdownSelectedContent.extract(
    selection: MarkdownSelection(
      base: MarkdownPosition(documentId: docId, blockIndex: 0, offset: 0),
      extent: MarkdownPosition(
        documentId: docId,
        blockIndex: lastBlockIdx,
        offset: lastBlockLen,
      ),
    ),
    documents: [MarkdownDocumentRef(id: docId, document: doc)],
  );
}

void main() {
  final parser = GfmMarkdownParser();
  const plainFormatter = MarkdownPlainTextFormatter();
  const markupFormatter = MarkdownMarkupFormatter();

  group('MarkdownPlainTextFormatter', () {
    test('returns empty string for empty or collapsed selections', () {
      final doc = parser.parse('Hello world');
      final collapsed = MarkdownSelectedContent.extract(
        selection: const MarkdownSelection.collapsed(
          MarkdownPosition(documentId: 'd1', blockIndex: 0, offset: 3),
        ),
        documents: [MarkdownDocumentRef(id: 'd1', document: doc)],
      );
      expect(plainFormatter.format(collapsed), '');
    });

    test('joins blocks with blank lines and skips thematic breaks', () {
      const doc = MarkdownDocument(
        blocks: [
          HeadingBlock(level: 1, inlines: [TextInline('Title')]),
          ParagraphBlock(inlines: [TextInline('First paragraph')]),
          ThematicBreakBlock(),
          ParagraphBlock(inlines: [TextInline('Second paragraph')]),
        ],
      );
      final content = _selectWholeDoc(doc);
      expect(
        plainFormatter.format(content),
        'Title\n\nFirst paragraph\n\nSecond paragraph',
      );
    });

    test('preserves list newlines, table tabs/newlines, and raw code', () {
      const doc = MarkdownDocument(
        blocks: [
          ListBlock(
            ordered: false,
            items: [
              ListItemNode(
                checked: true,
                children: [
                  ParagraphBlock(inlines: [TextInline('Done task')]),
                ],
              ),
              ListItemNode(
                checked: false,
                children: [
                  ParagraphBlock(inlines: [TextInline('Open task')]),
                ],
              ),
            ],
          ),
          TableBlock(
            alignments: [TableColumnAlign.left, TableColumnAlign.right],
            header: TableRowNode(
              cells: [
                [TextInline('Name')],
                [TextInline('Value')],
              ],
            ),
            rows: [
              TableRowNode(
                cells: [
                  [TextInline('Alpha')],
                  [TextInline('42')],
                ],
              ),
              TableRowNode(
                cells: [
                  [TextInline('Beta')],
                  [],
                ],
              ),
            ],
          ),
          CodeBlock(language: 'dart', code: 'void main() {\n  print(1);\n}'),
        ],
      );

      final content = _selectWholeDoc(doc);
      expect(
        plainFormatter.format(content),
        'Done task\nOpen task\n\n'
        'Name\tValue\nAlpha\t42\nBeta\t\n\n'
        'void main() {\n  print(1);\n}',
      );
    });

    test('formats cross-document selections in reading order', () {
      final doc1 = parser.parse('First doc block 1\n\nFirst doc block 2');
      final doc2 = parser.parse('Second doc block');
      const customPlain = MarkdownPlainTextFormatter(
        blockSeparator: '\n\n',
        documentSeparator: '\n---\n',
      );

      final content = MarkdownSelectedContent.extract(
        selection: const MarkdownSelection(
          base: MarkdownPosition(documentId: 'm1', blockIndex: 0, offset: 6),
          extent: MarkdownPosition(documentId: 'm2', blockIndex: 0, offset: 10),
        ),
        documents: [
          MarkdownDocumentRef(id: 'm2', document: doc2, order: 2),
          MarkdownDocumentRef(id: 'm1', document: doc1, order: 1),
        ],
      );

      expect(
        customPlain.format(content),
        'doc block 1\n\nFirst doc block 2\n---\nSecond doc',
      );
    });
  });

  group('MarkdownMarkupFormatter', () {
    test('reconstructs headings and rich inline formatting', () {
      const doc = MarkdownDocument(
        blocks: [
          HeadingBlock(level: 2, inlines: [TextInline('Overview')]),
          ParagraphBlock(
            inlines: [
              TextInline('Mix '),
              StrongInline(children: [TextInline('bold')]),
              TextInline(', '),
              EmphasisInline(children: [TextInline('italic')]),
              TextInline(', '),
              StrikethroughInline(children: [TextInline('gone')]),
              TextInline(', '),
              InlineCodeInline('x`y'),
              TextInline(', '),
              LinkInline(
                destination: 'https://example.com',
                title: 'Site',
                children: [TextInline('Example')],
              ),
              TextInline(', '),
              LinkInline(
                destination: 'https://auto.dev',
                isAutolink: true,
                children: [TextInline('https://auto.dev')],
              ),
              TextInline(', '),
              ImageInline(source: 'pic.png', alt: 'Pic'),
              TextInline(', '),
              UnderlineInline(children: [TextInline('u')]),
              TextInline(', '),
              SubscriptInline(children: [TextInline('2')]),
              TextInline(', '),
              SuperscriptInline(children: [TextInline('3')]),
              TextInline(', '),
              KeyboardInline(children: [TextInline('Esc')]),
              TextInline(', '),
              FootnoteRefInline(label: 'note', index: 1),
              TextInline(', '),
              InlineLatexInline('a+b'),
              LineBreakInline(isHard: true),
              TextInline('next line'),
            ],
          ),
        ],
      );

      final md = markupFormatter.format(_selectWholeDoc(doc));
      expect(
        md,
        '## Overview\n\n'
        'Mix **bold**, *italic*, ~~gone~~, ``x`y``, '
        '[Example](https://example.com "Site"), <https://auto.dev>, '
        '![Pic](pic.png), <u>u</u>, <sub>2</sub>, <sup>3</sup>, '
        '<kbd>Esc</kbd>, [^note], \$a+b\$  \n'
        'next line',
      );
    });

    test('reconstructs code blocks with adaptive fence length', () {
      const doc = MarkdownDocument(
        blocks: [
          CodeBlock(language: 'dart', code: 'final x = 1;'),
          CodeBlock(
            language: 'markdown',
            infoString: 'markdown title="demo"',
            code: '```dart\nprint(1);\n```',
          ),
        ],
      );

      expect(
        markupFormatter.format(_selectWholeDoc(doc)),
        '```dart\nfinal x = 1;\n```\n\n'
        '````markdown title="demo"\n```dart\nprint(1);\n```\n````',
      );
    });

    test('reconstructs nested blockquotes and all GFM alert kinds', () {
      const doc = MarkdownDocument(
        blocks: [
          BlockquoteBlock(
            children: [
              ParagraphBlock(inlines: [TextInline('Outer')]),
              BlockquoteBlock(
                children: [
                  ParagraphBlock(inlines: [TextInline('Inner')]),
                ],
              ),
            ],
          ),
          AlertBlock(
            kind: AlertKind.note,
            children: [
              ParagraphBlock(inlines: [TextInline('Useful info')]),
            ],
          ),
          AlertBlock(
            kind: AlertKind.tip,
            children: [
              ParagraphBlock(inlines: [TextInline('Helpful tip')]),
            ],
          ),
          AlertBlock(
            kind: AlertKind.important,
            children: [
              ParagraphBlock(inlines: [TextInline('Key detail')]),
            ],
          ),
          AlertBlock(
            kind: AlertKind.warning,
            children: [
              ParagraphBlock(inlines: [TextInline('Watch out')]),
            ],
          ),
          AlertBlock(
            kind: AlertKind.caution,
            children: [
              ParagraphBlock(inlines: [TextInline('Danger zone')]),
            ],
          ),
        ],
      );

      expect(
        markupFormatter.format(_selectWholeDoc(doc)),
        '> Outer\n>\n> > Inner\n\n'
        '> [!NOTE]\n> Useful info\n\n'
        '> [!TIP]\n> Helpful tip\n\n'
        '> [!IMPORTANT]\n> Key detail\n\n'
        '> [!WARNING]\n> Watch out\n\n'
        '> [!CAUTION]\n> Danger zone',
      );
    });

    test('reconstructs ordered, unordered, nested, and task lists', () {
      const doc = MarkdownDocument(
        blocks: [
          ListBlock(
            ordered: false,
            items: [
              ListItemNode(
                checked: true,
                children: [
                  ParagraphBlock(inlines: [TextInline('Parent')]),
                  ListBlock(
                    ordered: true,
                    start: 3,
                    items: [
                      ListItemNode(
                        children: [
                          ParagraphBlock(inlines: [TextInline('Child A')]),
                        ],
                      ),
                      ListItemNode(
                        children: [
                          ParagraphBlock(inlines: [TextInline('Child B')]),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              ListItemNode(
                checked: false,
                children: [
                  ParagraphBlock(inlines: [TextInline('Sibling')]),
                ],
              ),
            ],
          ),
        ],
      );

      expect(
        markupFormatter.format(_selectWholeDoc(doc)),
        '- [x] Parent\n'
        '  3. Child A\n'
        '  4. Child B\n'
        '- [ ] Sibling',
      );
    });

    test(
      'reconstructs pipe tables, thematic breaks, details, math, and footnotes',
      () {
        const doc = MarkdownDocument(
          blocks: [
            TableBlock(
              alignments: [
                TableColumnAlign.left,
                TableColumnAlign.center,
                TableColumnAlign.right,
                TableColumnAlign.none,
              ],
              header: TableRowNode(
                cells: [
                  [TextInline('A|B')],
                  [TextInline('Center')],
                  [TextInline('Right')],
                  [TextInline('Plain')],
                ],
              ),
              rows: [
                TableRowNode(
                  cells: [
                    [
                      StrongInline(children: [TextInline('1')]),
                    ],
                    [TextInline('2')],
                    [TextInline('3')],
                    [TextInline('4')],
                  ],
                ),
              ],
            ),
            ThematicBreakBlock(),
            HtmlDetailsBlock(
              initiallyOpen: true,
              summary: [TextInline('More details')],
              children: [
                ParagraphBlock(inlines: [TextInline('Hidden body')]),
              ],
            ),
            BlockLatexBlock(expression: r'\sum_{i=1}^n i'),
            FootnoteDefinitionsBlock(
              definitions: [
                FootnoteDefinition(
                  label: '1',
                  index: 1,
                  children: [
                    ParagraphBlock(inlines: [TextInline('Footnote body')]),
                  ],
                ),
              ],
            ),
          ],
        );

        expect(
          markupFormatter.format(_selectWholeDoc(doc)),
          r'| A\|B | Center | Right | Plain |'
          '\n'
          '| :--- | :---: | ---: | --- |\n'
          '| **1** | 2 | 3 | 4 |\n\n'
          '---\n\n'
          '<details open>\n<summary>More details</summary>\n\nHidden body\n</details>\n\n'
          '\$\$\n\\sum_{i=1}^n i\n\$\$\n\n'
          '[^1]: Footnote body',
        );
      },
    );

    test(
      'falls back to sliced plain text for partial boundary blocks without leaking unselected text',
      () {
        const doc = MarkdownDocument(
          blocks: [
            HeadingBlock(
              level: 1,
              inlines: [
                TextInline('Prefix '),
                StrongInline(children: [TextInline('SelectedStart')]),
              ],
            ),
            CodeBlock(language: 'dart', code: 'final ok = true;'),
            ParagraphBlock(
              inlines: [
                TextInline('SelectedEnd '),
                EmphasisInline(children: [TextInline('UnselectedSuffix')]),
              ],
            ),
          ],
        );

        final content = MarkdownSelectedContent.extract(
          selection: const MarkdownSelection(
            base: MarkdownPosition(documentId: 'd1', blockIndex: 0, offset: 7),
            extent: MarkdownPosition(
              documentId: 'd1',
              blockIndex: 2,
              offset: 11,
            ),
          ),
          documents: [MarkdownDocumentRef(id: 'd1', document: doc)],
        );

        final formatted = markupFormatter.format(content);
        expect(
          formatted,
          'SelectedStart\n\n'
          '```dart\nfinal ok = true;\n```\n\n'
          'SelectedEnd',
        );
        expect(formatted, isNot(contains('Prefix')));
        expect(formatted, isNot(contains('UnselectedSuffix')));
      },
    );

    test('formats cross-document selections with documentSeparator', () {
      const doc1 = MarkdownDocument(
        blocks: [
          HeadingBlock(level: 1, inlines: [TextInline('Doc One')]),
        ],
      );
      const doc2 = MarkdownDocument(
        blocks: [
          HeadingBlock(level: 2, inlines: [TextInline('Doc Two')]),
        ],
      );

      final content = MarkdownSelectedContent.extract(
        selection: const MarkdownSelection(
          base: MarkdownPosition(documentId: 'd1', blockIndex: 0, offset: 0),
          extent: MarkdownPosition(documentId: 'd2', blockIndex: 0, offset: 7),
        ),
        documents: const [
          MarkdownDocumentRef(id: 'd1', document: doc1, order: 0),
          MarkdownDocumentRef(id: 'd2', document: doc2, order: 1),
        ],
      );

      expect(markupFormatter.format(content), '# Doc One\n\n## Doc Two');
    });
  });
}
