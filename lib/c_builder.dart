import 'package:code_buffer/code_buffer.dart';
import 'package:meta/meta.dart';

String _escapeQuotes(String str) {
  return str
      .replaceAll('"', '\\"')
      .replaceAll('\b', '\\b')
      .replaceAll('\r', '\\r')
      .replaceAll('\f', '\\f')
      .replaceAll('\n', '\\n')
      .replaceAll('\t', '\\t');
}

final Expression NULL = new Expression('NULL');

final Code breakStatement = new Code('break;');

/// A C code generator.
class Code {
  String _code;

  Code._();

  /// Generates C code, verbatim.
  Code(String code) : _code = code;

  factory Code.empty() => new Code('');

  void generate(CodeBuffer buffer) {
    buffer.writeln(_code);
  }
}

/// Wraps code in an `#IFNDEF` block.
class Ifndef extends Code {
  final List<Code> body = [];
  final String name;

  Ifndef(this.name) : super._();

  @override
  void generate(CodeBuffer buffer) {
    buffer..writeln('#ifndef $name')..writeln('#define $name');
    body.forEach((c) => c.generate(buffer));
    buffer.writeln('#endif');
  }
}

/// A code generator that supports adding comments before the relevant constructor.
class CodeWithComments extends Code {
  final List<String> _comments = [];

  CodeWithComments([Iterable<String> comments]) : super._() {
    _comments.addAll(comments ?? []);
  }

  List<String> get comments => _comments;

  @override
  @virtual
  void generate(CodeBuffer buffer) {
    if (_comments.length == 1) {
      buffer.writeln('// ${comments[0]}');
    } else if (_comments.length > 1) {
      buffer.writeln('/*');
      _comments.forEach((c) => buffer.writeln(' * $c'));
      buffer.writeln(' */');
    }
  }
}

/// A unit of C code.
class CompilationUnit extends CodeWithComments {
  final List<Code> body = [];

  @override
  void generate(CodeBuffer buffer) {
    super.generate(buffer);
    body.forEach((c) => c.generate(buffer));
  }
}

/// Includes another file.
class Include extends CodeWithComments {
  final String source;

  /// Includes a header file, relative to the source directory.
  Include.quotes(String path) : source = '"${_escapeQuotes(path)}"';

  /// Includes a system-predefined header file.
  Include.system(String path) : source = '<$path>';

  @override
  void generate(CodeBuffer buffer) {
    super.generate(buffer);
    buffer.writeln('#include $source');
  }
}

/// Generates a C type.
class CType extends Code {
  static final CType char = new CType('char'),
      int = new CType('int'),
      float = new CType('float'),
      double = new CType('double'),
      int8_t = new CType('int8_t'),
      int16_t = new CType('int16_t'),
      int32_t = new CType('int32_t'),
      int64_t = new CType('int64_t'),
      uint16_t = new CType('uint16_t'),
      uint32_t = new CType('uint32_t'),
      uint64_t = new CType('uint64_t'),
      size_t = new CType('size_t'),
      ptrdiff_t = new CType('ptrdiff_t'),
      void$ = new CType('void');

  final String code;

  CType._()
      : code = null,
        super._();

  CType(this.code) : super._();

  CType pointer() => new CType('$code*');

  CType prefix(String text) => new CType('$text $code');

  CType suffix(String text) => new CType('$code $text');

  CType unsigned() => prefix('unsigned');

  CType extern([String str]) =>
      str == null ? prefix('extern') : prefix('extern "${_escapeQuotes(str)}"');

  CType register() => prefix('register');

  CType struct() => prefix('struct');

  CType static() => prefix('static');

  CType volatile() => prefix('volatile');

  CType const$() => prefix('const');

  CType short() => prefix('short');

  CType long() => prefix('long');

  CType inline() => prefix('inline');

  CType enum$() => prefix('enum');

  Expression sizeof() => new Expression('sizeof($code)');

  CType array([size]) {
    if (size == null) return new CType('$code[$size]');
    return new CType('$code[]');
  }

  @override
  void generate(CodeBuffer buffer) {
    buffer.writeln(code);
  }
}

/// An fixed-size data structure in C.
class Struct extends CType {
  final List<Field> fields = [];

  Struct() : super._();

  @override
  String get code {
    return 'struct { ${fields.join('; ')} }';
  }
}

/// A member of a C [Struct], OR a top-level declaration.
class Field extends CodeWithComments {
  final CType type;
  final String name;
  final Expression value;

  Field(this.type, this.name, this.value);

  @override
  void generate(CodeBuffer buffer) {
    super.generate(buffer);
    buffer.writeln('$this;');
  }

  @override
  String toString() {
    if (value == null) return '${type.code} $name';
    return '${type.code} $name = ${value.code}';
  }
}

/// Generates a C `typedef`.
class Typedef extends CodeWithComments {
  final CType type;
  final String name;

  Typedef(this.type, this.name);

  @override
  void generate(CodeBuffer buffer) {
    super.generate(buffer);

    if (type is Struct) {
      buffer
        ..writeln('typedef struct {')
        ..indent();
      (type as Struct).fields.forEach((f) => f.generate(buffer));
      buffer
        ..outdent()
        ..writeln('} $name;');
    } else {
      buffer.writeln('typedef ${type.code} $name;');
    }
  }
}

/// The signature of a C function.
class FunctionSignature extends CodeWithComments {
  final CType returnType;
  final String name;
  final List<Parameter> parameters = [];

  FunctionSignature(this.returnType, this.name);

  String get signature {
    return '${returnType.code} $name(${parameters.join(', ')})';
  }

  /// Returns a CType that references a pointer of this type.
  ///
  /// Ex: `int(*)(int,int);`
  CType pointerType() {
    return new CType('${returnType.code}(*)(${parameters.map((p) => p.type.code).join(', ')})');
  }

  /// Returns a [Parameter] referencing a pointer of this type.
  ///
  /// Ex: `int(*mypointer)(int,int);`
  Parameter asParameter() {
    return new _FunctionParameter(this);
  }

  @override
  void generate(CodeBuffer buffer) {
    super.generate(buffer);
    buffer.writeln('$signature;');
  }
}

class _FunctionParameter extends Parameter {
  final FunctionSignature signature;

  _FunctionParameter(this.signature):super(signature.pointerType(), signature.name);

  @override
  String toString() {
    return '${signature.returnType.code}(*$name)(${signature.parameters.map((p) => p.type.code).join(', ')})';
  }
}

/// Generates a C function.
class CFunction extends CodeWithComments {
  final List<Code> body = [];
  final FunctionSignature signature;

  CFunction(this.signature);

  @override
  void generate(CodeBuffer buffer) {
    super.generate(buffer);
    buffer
      ..writeln('${signature.signature} {')
      ..indent();
    body.forEach((c) => c.generate(buffer));
    buffer
      ..outdent()
      ..writeln('}');
  }
}

/// A parameter for a C function.
class Parameter extends Code {
  final CType type;
  final String name;

  Parameter(this.type, this.name):super._();

  @override
  String toString() {
    return '${type.code} $name';
  }

  @override
  void generate(CodeBuffer buffer) {
    buffer.writeln(toString());
  }
}

/// A control-flow statement in C.
class ControlFlow extends CodeWithComments {
  final List<Code> body = [];
  final String preamble;
  String _suffix = '';

  ControlFlow._(String preamble) : this.preamble = preamble;

  ControlFlow.while$(Expression condition)
      : preamble = 'while (${condition.code})';

  ControlFlow.doWhile(Expression condition)
      : preamble = 'do',
        _suffix = 'while (${condition.code});';

  ControlFlow.if$(Expression condition) : preamble = 'if (${condition.code})';

  ControlFlow.elseIf$(Expression condition)
      : preamble = 'else if (${condition.code})';

  ControlFlow.else$() : preamble = 'else';

  ControlFlow.try$() : preamble = 'try';

  ControlFlow.catch$(Parameter parameter) : preamble = 'catch ($parameter)';

  ControlFlow.finally$() : preamble = 'finally';

  ControlFlow.switch$(Expression condition)
      : preamble = 'switch (${condition.code})';

  factory ControlFlow.for$(
      Code initializer, Expression condition, Code accumulator) {
    var bufs = [initializer, condition, accumulator].map((c) {
      var b = new CodeBuffer();
      c.generate(b);
      return c.toString();
    });

    return new ControlFlow._('for (${bufs.join('; ')})');
  }

  @override
  void generate(CodeBuffer buffer) {
    super.generate(buffer);
    buffer
      ..writeln('$preamble {')
      ..indent();
    body.forEach((c) => c.generate(buffer));
    buffer
      ..outdent()
      ..writeln('} $_suffix'.trim());
  }
}

/// Represents a `switch` case in C.
class SwitchCase extends Code {
  final Expression expression;
  final List<Code> body = [];

  SwitchCase(this.expression) : super._();

  SwitchCase.default$()
      : expression = null,
        super._();

  @override
  void generate(CodeBuffer buffer) {
    if (expression == null)
      buffer.write('default:');
    else
      buffer.write('case ${expression.code}:');
    buffer
      ..writeln()
      ..indent();
    body.forEach((c) => c.generate(buffer));
    buffer.outdent();
  }
}

/// Generates a C expression.
class Expression extends CodeWithComments {
  final String code;

  Expression(this.code);

  /// Creates an [Expression] from a Dart value.
  factory Expression.value(x) {
    if (x == null) return NULL;

    if (x is String) {
      return new Expression('"${_escapeQuotes(x)}"');
    }

    if (x is num) return new Expression(x.toString());

    throw new ArgumentError(
        'Cannot express a value of type ${x.runtimeType} as a C expression.');
  }

  factory Expression.array(Iterable<Expression> values) {
    return new Expression('{ ${values.map((v) => v.code).join(', ')} }');
  }

  @override
  void generate(CodeBuffer buffer) {
    buffer.writeln('$code;');
  }

  Code asReturn() => new Code('return $code;');

  Code asThrow() => new Code('throw $code;');

  Expression invoke(Iterable<Expression> arguments) {
    return new Expression('$code(${arguments.map((a) => a.code).join(', ')})');
  }

  /// Assigns this value to a variable with the given [name].
  Expression assignTo(String name, [String op = '=']) =>
      new Expression('$name $op $code');

  Expression increment() => new Expression('$code++');

  Expression decrement() => new Expression('$code--');

  Expression incrementPre() => new Expression('++$code');

  Expression decrementPre() => new Expression('--$code');

  Expression conditional(Expression ifTrue, Expression ifFalse) {
    return new Expression('$code ? ${ifTrue.code} : ${ifFalse.code}');
  }

  Expression cast(CType type) => new Expression('(${type.code}) $code');

  Expression reference() => new Expression('&$code');

  Expression dereference() => new Expression('*$code');

  Expression parentheses() => new Expression('($code)');

  Expression sizeof() => new Expression('sizeof($code)');

  Expression operator *(Expression other) =>
      new Expression('$code * ${other.code}');

  Expression operator /(Expression other) =>
      new Expression('$code / ${other.code}');

  Expression operator %(Expression other) =>
      new Expression('$code % ${other.code}');

  Expression operator +(Expression other) =>
      new Expression('$code + ${other.code}');

  Expression operator -(Expression other) =>
      new Expression('$code - ${other.code}');

  Expression equals(Expression other) =>
      new Expression('$code == ${other.code}');

  Expression negate(Expression other) => new Expression('!$code');

  Expression or(Expression other) => new Expression('$code || ${other.code}');

  Expression and(Expression other) => new Expression('$code && ${other.code}');

  Expression operator <(Expression other) =>
      new Expression('$code < ${other.code}');

  Expression operator <=(Expression other) =>
      new Expression('$code <= ${other.code}');

  Expression operator >(Expression other) =>
      new Expression('$code >= ${other.code}');

  Expression operator >=(Expression other) =>
      new Expression('$code >= ${other.code}');

  Expression operator <<(Expression other) =>
      new Expression('$code << ${other.code}');

  Expression operator >>(Expression other) =>
      new Expression('$code >> ${other.code}');

  Expression operator &(Expression other) =>
      new Expression('$code & ${other.code}');

  Expression operator |(Expression other) =>
      new Expression('$code | ${other.code}');

  Expression operator ^(Expression other) =>
      new Expression('$code ^ ${other.code}');

  Expression operator [](Expression other) =>
      new Expression('$code[${other.code}]');
}

/// Represents an `enum` in C.
class Enum extends CodeWithComments {
  final String name;
  final List<String> values = [];

  @override
  void generate(CodeBuffer buffer) {
    super.generate(buffer);
    buffer
      ..writeln('enum $name {')
      ..indent();

    for (int i = 0; i < values.length; i++) {
      var trail = i == values.length - 1 ? '' : ',';
      buffer.writeln('${values[i]} = $i$trail');
    }

    buffer
      ..outdent()
      ..writeln('}');
  }

  Enum(this.name);
}
