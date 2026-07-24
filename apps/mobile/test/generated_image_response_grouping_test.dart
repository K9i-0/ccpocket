import 'package:ccpocket/features/generated_image_preview/generated_image_response_grouping.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('groupGeneratedImageResponses', () {
    test('combines image results from the same response', () {
      final entries = <ChatEntry>[
        UserChatEntry('Create several directions'),
        ServerChatEntry(_assistant('Starting image generation')),
        ServerChatEntry(_imageResult('image-1')),
        ServerChatEntry(_assistant('Preparing the remaining directions')),
        ServerChatEntry(_imageResult('image-2', imageCount: 2)),
        ServerChatEntry(const ResultMessage(subtype: 'success')),
      ];

      final groups = groupGeneratedImageResponses(entries);

      expect(groups, hasLength(1));
      expect(groups.single.anchorEntryIndex, 4);
      expect(groups.single.memberEntryIndices, {2, 4});
      expect(groups.single.toolUseIds, {'image-1', 'image-2'});
      expect(
        groups.single.messages.expand((message) => message.images),
        hasLength(3),
      );
    });

    test('starts a new group after a result or user message', () {
      final entries = <ChatEntry>[
        ServerChatEntry(_imageResult('first')),
        ServerChatEntry(const ResultMessage(subtype: 'success')),
        UserChatEntry('Create one more'),
        ServerChatEntry(_imageResult('second')),
      ];

      final groups = groupGeneratedImageResponses(entries);

      expect(groups, hasLength(2));
      expect(groups[0].anchorEntryIndex, 0);
      expect(groups[1].anchorEntryIndex, 3);
    });

    test('ignores other tools and results without images', () {
      final entries = <ChatEntry>[
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

      expect(groupGeneratedImageResponses(entries), isEmpty);
      expect(completedGeneratedImageToolUseIds(entries), {'empty-image'});
    });
  });
}

AssistantServerMessage _assistant(String text) {
  return AssistantServerMessage(
    message: AssistantMessage(
      id: text,
      role: 'assistant',
      content: [TextContent(text: text)],
      model: 'gpt-5.6',
    ),
  );
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
