String firstPositionalName(Invocation invocation) => switch (invocation.positionalArguments) {
  [final String name, ...] => name,
  _ => '',
};

String? namedStringValue(Invocation invocation) => switch (invocation.namedArguments[#value]) {
  final String value => value,
  _ => null,
};
