// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'github_selection_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GitHubSelectedItem _$GitHubSelectedItemFromJson(Map<String, dynamic> json) =>
    _GitHubSelectedItem(
      number: (json['number'] as num).toInt(),
      title: json['title'] as String,
      url: json['url'] as String,
      isPullRequest: json['isPullRequest'] as bool? ?? false,
    );

Map<String, dynamic> _$GitHubSelectedItemToJson(_GitHubSelectedItem instance) =>
    <String, dynamic>{
      'number': instance.number,
      'title': instance.title,
      'url': instance.url,
      'isPullRequest': instance.isPullRequest,
    };
