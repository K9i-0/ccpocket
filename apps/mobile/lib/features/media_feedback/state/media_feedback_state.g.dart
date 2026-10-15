// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_feedback_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_FeedbackMedia _$FeedbackMediaFromJson(Map<String, dynamic> json) =>
    _FeedbackMedia(
      key: json['key'] as String,
      label: json['label'] as String,
      isVideo: json['isVideo'] as bool? ?? false,
      path: json['path'] as String?,
      projectPath: json['projectPath'] as String?,
      url: json['url'] as String?,
      base64: json['base64'] as String?,
      mimeType: json['mimeType'] as String? ?? 'image/png',
      modifiedAt: (json['modifiedAt'] as num?)?.toInt(),
    );

Map<String, dynamic> _$FeedbackMediaToJson(_FeedbackMedia instance) =>
    <String, dynamic>{
      'key': instance.key,
      'label': instance.label,
      'isVideo': instance.isVideo,
      'path': instance.path,
      'projectPath': instance.projectPath,
      'url': instance.url,
      'base64': instance.base64,
      'mimeType': instance.mimeType,
      'modifiedAt': instance.modifiedAt,
    };

_MediaFeedback _$MediaFeedbackFromJson(Map<String, dynamic> json) =>
    _MediaFeedback(
      id: json['id'] as String,
      media: FeedbackMedia.fromJson(json['media'] as Map<String, dynamic>),
      text: json['text'] as String,
      positionMs: (json['positionMs'] as num?)?.toInt(),
    );

Map<String, dynamic> _$MediaFeedbackToJson(_MediaFeedback instance) =>
    <String, dynamic>{
      'id': instance.id,
      'media': instance.media,
      'text': instance.text,
      'positionMs': instance.positionMs,
    };
