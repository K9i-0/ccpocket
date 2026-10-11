import 'package:ccpocket/features/generated_image_preview/generated_image_tool_results.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('completedGeneratedImageToolUseIds', () {
    test('hides successful and failed image-generation tool results', () {
      final entries = <ChatEntry>[
        ServerChatEntry(_imageResult('generated')),
        ServerChatEntry(
          const ToolResultMessage(
            toolUseId: 'read',
            toolName: 'Read',
            content: 'file contents',
          ),
        ),
        ServerChatEntry(
          const ToolResultMessage(
            toolUseId: 'empty-image',
            toolName: 'ImageGeneration',
            content: 'status: failed',
          ),
        ),
      ];

      expect(completedGeneratedImageToolUseIds(entries), {
        'generated',
        'empty-image',
      });
    });
  });
}

ToolResultMessage _imageResult(String id, {int imageCount = 1}) {
  return ToolResultMessage(
    toolUseId: id,
    toolName: 'ImageGeneration',
    content: 'status: completed\nrevisedPrompt: Prompt for $id',
    images: [
      for (var index = 0; index < imageCount; index++)
        ImageRef(
          id: '$id-$index',
          url: '/images/$id-$index.png',
          mimeType: 'image/png',
        ),
    ],
  );
}
