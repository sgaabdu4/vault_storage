import 'dart:ffi';

const _rusageBytes = 256;
const _timevalBytes = 16;
const _microsecondsOffset = 8;
const _selfUsage = 0;

typedef _MallocNative = Pointer<Uint8> Function(IntPtr size);
typedef _Malloc = Pointer<Uint8> Function(int size);
typedef _FreeNative = Void Function(Pointer<Uint8> pointer);
typedef _Free = void Function(Pointer<Uint8> pointer);
typedef _GetrusageNative = Int32 Function(Int32 who, Pointer<Uint8> usage);
typedef _Getrusage = int Function(int who, Pointer<Uint8> usage);

/// Processor time this process has used, so a budget does not grow when the machine is busy.
Duration processCpuTime() {
  final malloc = DynamicLibrary.process().lookupFunction<_MallocNative, _Malloc>('malloc');
  final free = DynamicLibrary.process().lookupFunction<_FreeNative, _Free>('free');
  final getrusage = DynamicLibrary.process().lookupFunction<_GetrusageNative, _Getrusage>(
    'getrusage',
  );
  final usage = malloc(_rusageBytes);
  try {
    getrusage(_selfUsage, usage);
    return _timeval(usage) + _timeval(usage + _timevalBytes);
  } finally {
    free(usage);
  }
}

Duration _timeval(Pointer<Uint8> timeval) {
  final seconds = timeval.cast<Int64>().value;
  final microseconds = (timeval + _microsecondsOffset).cast<Int32>().value;
  return Duration(seconds: seconds, microseconds: microseconds);
}
