# c_builder
[![Pub](https://img.shields.io/pub/v/c_builder.svg)](https://pub.dartlang.org/packages/c_builder)

An API for generating C code in Dart. Especially helpful for
compiler development. Supports generating every possible unit of
C code.

## Example
```dart
import 'package:c_builder/c_builder.dart';
import 'package:code_buffer/code_buffer.dart';

/// Generates a simple "Hello, world"
main() {
  var unit = new CompilationUnit()
    ..body.addAll([
      new Include.system('stdio.h'),
      new CFunction(new FunctionSignature(CType.int, 'main')
        ..parameters.addAll([
          new Parameter(CType.int, 'argc'),
          new Parameter(CType.char.pointer().pointer(), 'argv'),
        ]))
        ..comments.addAll([
          'This is the entry point.',
          'The system calls this function when starting the program.'
        ])
        ..body.addAll([
          new Expression.value(0).asReturn(),
        ]),
    ]);
  var buf = new CodeBuffer();
  unit.generate(buf);
  print(buf);
}
```