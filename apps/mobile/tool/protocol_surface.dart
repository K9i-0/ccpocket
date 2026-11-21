// Extracts what the app puts on the wire and what it reads off it, and writes
// that as TypeScript types the Bridge type check compares with its protocol.
//
//   dart run tool/protocol_surface.dart          # rewrite the generated file
//   dart run tool/protocol_surface.dart --print  # print a summary instead
//
// See docs/protocol-contract-check.md.
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

const generatedPath =
    '../../packages/bridge/src/protocol-contract/app-surface.generated.ts';
const messagesPath = 'lib/models/messages.dart';

/// One map literal the app sends as a client message.
class SentShape {
  SentShape(this.type, this.from);

  final String type;

  /// Where the literal is, e.g. `ClientMessage.gitStatus`.
  final String from;

  /// Keys present in every message built from this literal.
  final Set<String> always = {};

  /// Keys present only under a condition (`if`, `'k': ?v`, later assignment).
  final Set<String> sometimes = {};

  /// Why some keys could not be listed (a spread, a computed key).
  final List<String> unchecked = [];
}

/// The keys the app reads from one server message type.
class ReadShape {
  ReadShape(this.type);

  final String type;

  /// Keys cast to a non-nullable type: the message is dropped without them.
  final Set<String> required = {};

  /// Keys read in a way that tolerates their absence.
  final Set<String> optional = {};

  /// Calls that receive the whole message but could not be followed.
  final List<String> unchecked = [];
}

class ProtocolSurface {
  final List<SentShape> sent = [];
  final List<ReadShape> read = [];

  /// Factories whose message is not a map literal with a literal `type`.
  final List<String> factoriesWithoutLiteral = [];

  /// Default `supportedServerMessages` of `ClientMessage.clientCapabilities`.
  final List<String> supportedServerMessages = [];
}

ProtocolSurface extractProtocolSurface({
  required String messagesSource,
  Map<String, String> otherSources = const {},
}) {
  final surface = ProtocolSurface();
  final unit = parseString(content: messagesSource).unit;
  final index = _DeclarationIndex(unit);

  final clientMessage = index.classes['ClientMessage'];
  if (clientMessage == null) {
    throw StateError('class ClientMessage not found in $messagesPath');
  }
  for (final member in clientMessage.members) {
    if (member is! ConstructorDeclaration || member.factoryKeyword == null) {
      continue;
    }
    final name = member.name?.lexeme;
    if (name == null) continue;
    final from = 'ClientMessage.$name';
    final collector = _SentCollector(from);
    member.body.accept(collector);
    surface.sent.addAll(collector.shapes);
    if (collector.shapes.isEmpty && name != 'raw') {
      surface.factoriesWithoutLiteral.add(from);
    }
    if (name == 'clientCapabilities') {
      for (final parameter in member.parameters.parameters) {
        if (parameter.name?.lexeme != 'supportedServerMessages') continue;
        final value = parameter.defaultClause?.value;
        if (value is ListLiteral) {
          for (final element in value.elements) {
            if (element is SimpleStringLiteral) {
              surface.supportedServerMessages.add(element.value);
            }
          }
        }
      }
    }
  }

  // Messages built outside ClientMessage and sent as raw maps.
  for (final entry in otherSources.entries) {
    final other = parseString(content: entry.value).unit;
    final collector = _RawSendCollector(entry.key);
    other.accept(collector);
    surface.sent.addAll(collector.shapes);
  }

  final serverMessage = index.classes['ServerMessage'];
  final fromJson = serverMessage?.members
      .whereType<ConstructorDeclaration>()
      .where((c) => c.name?.lexeme == 'fromJson')
      .firstOrNull;
  if (fromJson == null) {
    throw StateError('ServerMessage.fromJson not found in $messagesPath');
  }
  final dispatch = _findDispatch(fromJson.body);
  if (dispatch == null) {
    throw StateError('ServerMessage.fromJson has no switch on json[\'type\']');
  }
  for (final switchCase in dispatch.cases) {
    final types = _patternStrings(switchCase.guardedPattern.pattern);
    if (types.isEmpty) continue; // the wildcard
    final reader = _ReadCollector(index, 'json');
    switchCase.expression.accept(reader);
    for (final type in types) {
      final shape = ReadShape(type)
        ..required.addAll(reader.required)
        ..optional.addAll(reader.optional.difference(reader.required))
        ..unchecked.addAll(reader.unchecked);
      surface.read.add(shape);
    }
  }

  surface.sent.sort((a, b) {
    final byType = a.type.compareTo(b.type);
    return byType != 0 ? byType : a.from.compareTo(b.from);
  });
  surface.read.sort((a, b) => a.type.compareTo(b.type));
  return surface;
}

// ---------------------------------------------------------------------------
// Declarations by name, to follow `X.fromJson(json)` and `_helper(json)`.
// ---------------------------------------------------------------------------

class _DeclarationIndex {
  _DeclarationIndex(CompilationUnit unit) {
    for (final declaration in unit.declarations) {
      if (declaration is ClassDeclaration) {
        final name = declaration.namePart.typeName.lexeme;
        classes[name] = _ClassInfo(declaration);
      } else if (declaration is EnumDeclaration) {
        final name = declaration.namePart.typeName.lexeme;
        classes[name] = _ClassInfo.fromMembers(declaration.body.members);
      } else if (declaration is ExtensionTypeDeclaration) {
        continue;
      } else if (declaration is FunctionDeclaration) {
        functions[declaration.name.lexeme] = declaration;
      }
    }
  }

  final Map<String, _ClassInfo> classes = {};
  final Map<String, FunctionDeclaration> functions = {};
}

class _ClassInfo {
  _ClassInfo(ClassDeclaration declaration)
    : members = switch (declaration.body) {
        final BlockClassBody body => body.members,
        _ => const [],
      };

  _ClassInfo.fromMembers(this.members);

  final List<ClassMember> members;

  /// The body and first-parameter name of `name`, a constructor or method.
  ({AstNode body, String parameter})? callable(String name) {
    for (final member in members) {
      if (member is ConstructorDeclaration && member.name?.lexeme == name) {
        final first = member.parameters.parameters.firstOrNull?.name?.lexeme;
        if (first == null) return null;
        return (body: member.body, parameter: first);
      }
      if (member is MethodDeclaration && member.name.lexeme == name) {
        final first = member.parameters?.parameters.firstOrNull?.name?.lexeme;
        if (first == null) return null;
        return (body: member.body, parameter: first);
      }
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// Client messages
// ---------------------------------------------------------------------------

String? _stringValue(AstNode? node) =>
    node is SimpleStringLiteral ? node.value : null;

/// The `'type': '<literal>'` value of a map literal, if it has one.
String? _typeOf(SetOrMapLiteral literal) {
  for (final element in literal.elements) {
    if (element is MapLiteralEntry && _stringValue(element.key) == 'type') {
      return _stringValue(element.value);
    }
  }
  return null;
}

void _collectElements(
  Iterable<CollectionElement> elements,
  SentShape shape, {
  required bool conditional,
}) {
  for (final element in elements) {
    switch (element) {
      case MapLiteralEntry():
        final key = _stringValue(element.key);
        if (key == null) {
          shape.unchecked.add('computed key ${element.key.toSource()}');
          continue;
        }
        // `'k': ?v` and `?k: v` leave the entry out when the operand is null.
        final nullAware =
            element.keyQuestion != null || element.valueQuestion != null;
        (conditional || nullAware ? shape.sometimes : shape.always).add(key);
      case IfElement():
        _collectElements([element.thenElement], shape, conditional: true);
        final otherwise = element.elseElement;
        if (otherwise != null) {
          _collectElements([otherwise], shape, conditional: true);
        }
      case ForElement():
        _collectElements([element.body], shape, conditional: true);
      case NullAwareElement():
        shape.unchecked.add('null-aware element ${element.toSource()}');
      case SpreadElement():
        final spread = element.expression;
        if (spread is SetOrMapLiteral) {
          _collectElements(spread.elements, shape, conditional: conditional);
        } else {
          shape.unchecked.add('spread ${spread.toSource()}');
        }
      default:
        shape.unchecked.add('element ${element.toSource()}');
    }
  }
}

class _SentCollector extends RecursiveAstVisitor<void> {
  _SentCollector(this.from);

  final String from;
  final List<SentShape> shapes = [];

  /// Local variables initialised with a typed map literal.
  final Map<String, SentShape> _locals = {};

  @override
  void visitSetOrMapLiteral(SetOrMapLiteral node) {
    final type = _typeOf(node);
    if (type == null) {
      super.visitSetOrMapLiteral(node);
      return;
    }
    final shape = SentShape(type, from);
    _collectElements(node.elements, shape, conditional: false);
    // A key set twice under opposite conditions is still only "sometimes".
    shape.sometimes.removeAll(shape.always);
    shapes.add(shape);
    final parent = node.parent;
    if (parent is VariableDeclaration) _locals[parent.name.lexeme] = shape;
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    // `json['key'] = value` on a map built earlier in the same factory.
    final target = node.leftHandSide;
    if (target is IndexExpression) {
      final receiver = target.target;
      final shape = receiver is SimpleIdentifier
          ? _locals[receiver.name]
          : null;
      if (shape != null) {
        final key = _stringValue(target.index);
        if (key == null) {
          shape.unchecked.add('computed key ${target.index.toSource()}');
        } else if (!shape.always.contains(key)) {
          shape.sometimes.add(key);
        }
      }
    }
    super.visitAssignmentExpression(node);
  }
}

class _RawSendCollector extends RecursiveAstVisitor<void> {
  _RawSendCollector(this.file);

  final String file;
  final List<SentShape> shapes = [];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final name = node.methodName.name;
    if (name == 'raw' || name == 'request') {
      for (final entry in node.argumentList.arguments) {
        final argument = entry.argumentExpression;
        if (argument is! SetOrMapLiteral) continue;
        final type = _typeOf(argument);
        if (type == null) continue;
        final shape = SentShape(type, '$file ($name)');
        _collectElements(argument.elements, shape, conditional: false);
        shape.sometimes.removeAll(shape.always);
        shapes.add(shape);
      }
    }
    super.visitMethodInvocation(node);
  }
}

// ---------------------------------------------------------------------------
// Server messages
// ---------------------------------------------------------------------------

SwitchExpression? _findDispatch(AstNode body) {
  final finder = _DispatchFinder();
  body.accept(finder);
  return finder.found;
}

class _DispatchFinder extends RecursiveAstVisitor<void> {
  SwitchExpression? found;

  @override
  void visitSwitchExpression(SwitchExpression node) {
    found ??= node;
  }
}

List<String> _patternStrings(DartPattern pattern) {
  switch (pattern) {
    case ConstantPattern():
      final value = _stringValue(pattern.expression);
      return value == null ? const [] : [value];
    case LogicalOrPattern():
      return [
        ..._patternStrings(pattern.leftOperand),
        ..._patternStrings(pattern.rightOperand),
      ];
    case ParenthesizedPattern():
      return _patternStrings(pattern.pattern);
    default:
      return const [];
  }
}

/// Collects `<variable>['key']` reads, following calls that take the map.
class _ReadCollector extends RecursiveAstVisitor<void> {
  _ReadCollector(this.index, this.variable, [Set<String>? visiting])
    : _visiting = visiting ?? {};

  final _DeclarationIndex index;
  final String variable;
  final Set<String> _visiting;

  final Set<String> required = {};
  final Set<String> optional = {};
  final List<String> unchecked = [];

  bool _isVariable(AstNode? node) =>
      node is SimpleIdentifier && node.name == variable;

  @override
  void visitIndexExpression(IndexExpression node) {
    if (_isVariable(node.target)) {
      final key = _stringValue(node.index);
      if (key == null) {
        unchecked.add('computed key ${node.index.toSource()}');
      } else if (_isNonNullCast(node) && !_isGuarded(node, key)) {
        required.add(key);
      } else {
        optional.add(key);
      }
    }
    super.visitIndexExpression(node);
  }

  /// Whether a read sits behind a test of the same key, as in
  /// `json['k'] is Map ? Foo.fromJson(json['k'] as Map) : null`.
  bool _isGuarded(AstNode node, String key) {
    AstNode child = node;
    for (var parent = node.parent; parent != null; parent = parent.parent) {
      final AstNode? test = switch (parent) {
        ConditionalExpression() when child != parent.condition =>
          parent.condition,
        IfElement() when child != parent.expression => parent.expression,
        IfStatement() when child != parent.expression => parent.expression,
        BinaryExpression()
            when child == parent.rightOperand &&
                parent.operator.lexeme == '&&' =>
          parent.leftOperand,
        SwitchExpression() when child != parent.expression => parent.expression,
        SwitchStatement() when child != parent.expression => parent.expression,
        _ => null,
      };
      if (test != null && _mentions(test, key)) return true;
      if (parent is FunctionBody) break;
      child = parent;
    }
    return false;
  }

  bool _mentions(AstNode node, String key) {
    final finder = _KeyMention(variable, key);
    node.accept(finder);
    return finder.found;
  }

  /// `json['k'] as T` with a non-nullable `T` throws when the key is absent.
  bool _isNonNullCast(IndexExpression node) {
    AstNode? parent = node.parent;
    while (parent is ParenthesizedExpression) {
      parent = parent.parent;
    }
    if (parent is! AsExpression) return false;
    final type = parent.type;
    if (type.question != null) return false;
    if (type is NamedType) {
      final name = type.name.lexeme;
      if (name == 'dynamic') return false;
    }
    return true;
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_isVariable(node.target)) {
      // json.containsKey('k'), json.remove('k')
      final name = node.methodName.name;
      final key = _stringValue(node.argumentList.arguments.firstOrNull);
      if ((name == 'containsKey' || name == 'remove') && key != null) {
        optional.add(key);
      }
    }
    _follow(
      node.argumentList,
      owner: switch (node.target) {
        final SimpleIdentifier target => target.name,
        _ => null,
      },
      name: node.methodName.name,
      source: node.toSource(),
    );
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final constructor = node.constructorName;
    _follow(
      node.argumentList,
      owner: constructor.type.name.lexeme,
      name: constructor.name?.name,
      source: node.toSource(),
    );
    super.visitInstanceCreationExpression(node);
  }

  /// When the whole map is passed on, read the callee as well.
  void _follow(
    ArgumentList arguments, {
    required String? owner,
    required String? name,
    required String source,
  }) {
    final passesMap = arguments.arguments.any((argument) {
      return _isVariable(argument.argumentExpression);
    });
    if (!passesMap) return;

    ({AstNode body, String parameter})? callee;
    String label;
    if (owner != null && index.classes.containsKey(owner)) {
      label = '$owner.${name ?? 'new'}';
      callee = name == null ? null : index.classes[owner]!.callable(name);
    } else {
      label = name ?? '?';
      final function = owner == null && name != null
          ? index.functions[name]
          : null;
      final first = function
          ?.functionExpression
          .parameters
          ?.parameters
          .firstOrNull
          ?.name
          ?.lexeme;
      if (function != null && first != null) {
        callee = (body: function.functionExpression.body, parameter: first);
      }
    }
    if (callee == null) {
      unchecked.add('passes the message to $label');
      return;
    }
    if (!_visiting.add(label)) return;
    final nested = _ReadCollector(index, callee.parameter, _visiting);
    callee.body.accept(nested);
    _visiting.remove(label);
    required.addAll(nested.required);
    optional.addAll(nested.optional);
    unchecked.addAll(nested.unchecked);
  }
}

class _KeyMention extends RecursiveAstVisitor<void> {
  _KeyMention(this.variable, this.key);

  final String variable;
  final String key;
  bool found = false;

  @override
  void visitIndexExpression(IndexExpression node) {
    final target = node.target;
    if (target is SimpleIdentifier &&
        target.name == variable &&
        _stringValue(node.index) == key) {
      found = true;
    }
    super.visitIndexExpression(node);
  }
}

// ---------------------------------------------------------------------------
// TypeScript output
// ---------------------------------------------------------------------------

String _union(Iterable<String> keys) {
  final sorted = keys.toList()..sort();
  return sorted.isEmpty ? 'never' : sorted.map((k) => '"$k"').join(' | ');
}

String renderTypeScript(ProtocolSurface surface) {
  final out = StringBuffer()
    ..writeln('// GENERATED by apps/mobile/tool/protocol_surface.dart.')
    ..writeln('// Do not edit: run `dart run tool/protocol_surface.dart` in')
    ..writeln('// apps/mobile. See docs/protocol-contract-check.md.')
    ..writeln()
    ..writeln('/** One map literal the app sends as a client message. */')
    ..writeln('export type AppSent =');
  for (final shape in surface.sent) {
    out
      ..writeln('  | {')
      ..writeln('      type: "${shape.type}";')
      ..writeln('      from: "${shape.from}";')
      ..writeln('      always: ${_union(shape.always)};')
      ..writeln('      sometimes: ${_union(shape.sometimes)};')
      ..writeln('    }');
  }
  out
    ..writeln(';')
    ..writeln()
    ..writeln('/** The keys the app reads from one server message type. */')
    ..writeln('export type AppRead =');
  for (final shape in surface.read) {
    out
      ..writeln('  | {')
      ..writeln('      type: "${shape.type}";')
      ..writeln('      required: ${_union(shape.required)};')
      ..writeln('      optional: ${_union(shape.optional)};')
      ..writeln('    }');
  }
  out
    ..writeln(';')
    ..writeln()
    ..writeln('/** Opt-in server messages the app asks for by default. */')
    ..writeln('export type AppSupportedServerMessage =')
    ..writeln(
      '  | ${_union(surface.supportedServerMessages).replaceAll(' | ', '\n  | ')};',
    );

  final unchecked = <String>[
    for (final from in surface.factoriesWithoutLiteral)
      'sent by $from: not a map literal with a literal type',
    for (final shape in surface.sent)
      for (final reason in shape.unchecked)
        'sent ${shape.type} (${shape.from}): $reason',
    for (final shape in surface.read)
      for (final reason in shape.unchecked) 'read ${shape.type}: $reason',
  ];
  if (unchecked.isNotEmpty) {
    out
      ..writeln()
      ..writeln(
        '// Not covered, because the keys are not visible in the source:',
      );
    for (final line in unchecked) {
      out.writeln('// - ${line.replaceAll('\n', ' ')}');
    }
  }
  return out.toString();
}

/// Reads the app sources relative to `apps/mobile` and extracts the surface.
ProtocolSurface extractFromWorkingTree() {
  final others = <String, String>{};
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final path = entity.path.replaceAll(r'\', '/');
    if (path == messagesPath || path.contains('/mock/')) continue;
    if (path.endsWith('.g.dart') || path.endsWith('.freezed.dart')) continue;
    final source = entity.readAsStringSync();
    if (!source.contains("'type':")) continue;
    others[path] = source;
  }
  return extractProtocolSurface(
    messagesSource: File(messagesPath).readAsStringSync(),
    otherSources: others,
  );
}

void main(List<String> arguments) {
  final surface = extractFromWorkingTree();
  if (arguments.contains('--print')) {
    stdout
      ..writeln('sent shapes: ${surface.sent.length}')
      ..writeln('read types: ${surface.read.length}')
      ..writeln(
        'supported server messages: ${surface.supportedServerMessages.length}',
      );
    for (final from in surface.factoriesWithoutLiteral) {
      stdout.writeln('unchecked factory $from');
    }
    for (final shape in surface.sent) {
      for (final reason in shape.unchecked) {
        stdout.writeln('unchecked sent ${shape.type} (${shape.from}): $reason');
      }
    }
    for (final shape in surface.read) {
      for (final reason in shape.unchecked) {
        stdout.writeln('unchecked read ${shape.type}: $reason');
      }
    }
    return;
  }
  File(generatedPath)
    ..createSync(recursive: true)
    ..writeAsStringSync(renderTypeScript(surface));
  stdout.writeln('wrote $generatedPath');
}
