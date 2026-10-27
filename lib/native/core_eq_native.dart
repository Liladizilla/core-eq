import 'dart:ffi';

/// Status codes returned by the CORE-EQ C ABI.
enum CoreEqStatus {
  ok(0),
  invalidArgument(1),
  queueFull(2);

  const CoreEqStatus(this.code);
  final int code;

  static CoreEqStatus fromCode(int code) => CoreEqStatus.values.firstWhere(
        (status) => status.code == code,
        orElse: () => CoreEqStatus.invalidArgument,
      );
}

final class CoreEqHandle extends Opaque {}

typedef _AbiVersionNative = Uint32 Function();
typedef _AbiVersionDart = int Function();
typedef _CreateNative = Pointer<CoreEqHandle> Function();
typedef _CreateDart = Pointer<CoreEqHandle> Function();
typedef _DestroyNative = Void Function(Pointer<CoreEqHandle>);
typedef _DestroyDart = void Function(Pointer<CoreEqHandle>);
typedef _SetGainNative = Int32 Function(Pointer<CoreEqHandle>, Float);
typedef _SetGainDart = int Function(Pointer<CoreEqHandle>, double);
typedef _SetBypassNative = Int32 Function(Pointer<CoreEqHandle>, Int32);
typedef _SetBypassDart = int Function(Pointer<CoreEqHandle>, int);
typedef _ConfigureBandNative = Int32 Function(
  Pointer<CoreEqHandle>, Uint32, Float, Float, Float, Float,
);
typedef _ConfigureBandDart = int Function(
  Pointer<CoreEqHandle>, int, double, double, double, double,
);
typedef _ResetNative = Int32 Function(Pointer<CoreEqHandle>);
typedef _ResetDart = int Function(Pointer<CoreEqHandle>);
typedef _ProcessNative = Int32 Function(
  Pointer<CoreEqHandle>, Pointer<Float>, IntPtr, IntPtr,
);
typedef _ProcessDart = int Function(
  Pointer<CoreEqHandle>, Pointer<Float>, int, int,
);

/// Typed Dart FFI bindings. The caller must load the platform library and
/// serialize parameter setters because the native queue is single-producer.
final class CoreEqNative {
  CoreEqNative(DynamicLibrary library)
      : _abiVersion = library.lookupFunction<_AbiVersionNative, _AbiVersionDart>(
          'core_eq_abi_version',
        ),
        _create = library.lookupFunction<_CreateNative, _CreateDart>(
          'core_eq_create',
        ),
        _destroy = library.lookupFunction<_DestroyNative, _DestroyDart>(
          'core_eq_destroy',
        ),
        _setInputGain = library.lookupFunction<_SetGainNative, _SetGainDart>(
          'core_eq_set_input_gain_db',
        ),
        _setOutputGain = library.lookupFunction<_SetGainNative, _SetGainDart>(
          'core_eq_set_output_gain_db',
        ),
        _setBypassed = library.lookupFunction<_SetBypassNative, _SetBypassDart>(
          'core_eq_set_bypassed',
        ),
        _configureBand =
            library.lookupFunction<_ConfigureBandNative, _ConfigureBandDart>(
          'core_eq_configure_band',
        ),
        _reset = library.lookupFunction<_ResetNative, _ResetDart>(
          'core_eq_reset',
        ),
        _process = library.lookupFunction<_ProcessNative, _ProcessDart>(
          'core_eq_process',
        );

  final _AbiVersionDart _abiVersion;

  /// Returns the native ABI major version.
  int get abiVersion => _abiVersion();
  final _CreateDart _create;
  final _DestroyDart _destroy;
  final _SetGainDart _setInputGain;
  final _SetGainDart _setOutputGain;
  final _SetBypassDart _setBypassed;
  final _ConfigureBandDart _configureBand;
  final _ResetDart _reset;
  final _ProcessDart _process;

  /// Creates an engine handle. A null pointer indicates allocation failure.
  Pointer<CoreEqHandle> create() => _create();

  /// Destroys a handle returned by [create].
  void destroy(Pointer<CoreEqHandle> handle) => _destroy(handle);

  CoreEqStatus setInputGainDb(Pointer<CoreEqHandle> handle, double db) =>
      CoreEqStatus.fromCode(_setInputGain(handle, db));

  CoreEqStatus setOutputGainDb(Pointer<CoreEqHandle> handle, double db) =>
      CoreEqStatus.fromCode(_setOutputGain(handle, db));

  CoreEqStatus setBypassed(Pointer<CoreEqHandle> handle, bool bypassed) =>
      CoreEqStatus.fromCode(_setBypassed(handle, bypassed ? 1 : 0));

  CoreEqStatus configureBand(
    Pointer<CoreEqHandle> handle, {
    required int band,
    required double frequencyHz,
    required double q,
    required double gainDb,
    required double sampleRateHz,
  }) =>
      CoreEqStatus.fromCode(
        _configureBand(handle, band, frequencyHz, q, gainDb, sampleRateHz),
      );

  CoreEqStatus reset(Pointer<CoreEqHandle> handle) =>
      CoreEqStatus.fromCode(_reset(handle));

  /// Processes interleaved float PCM in caller-owned native memory.
  CoreEqStatus process(
    Pointer<CoreEqHandle> handle, {
    required Pointer<Float> samples,
    required int frames,
    required int channels,
  }) =>
      CoreEqStatus.fromCode(_process(handle, samples, frames, channels));
}


/// Owns one native engine handle and enforces its lifecycle.
///
/// Library discovery/loading remains the platform host's responsibility. This
/// class intentionally does not claim that a device audio stream is connected.
final class CoreEqEngineSession {
  CoreEqEngineSession._(this.native, this.handle);

  static const supportedAbiVersion = 1;

  final CoreEqNative native;
  final Pointer<CoreEqHandle> handle;
  bool _disposed = false;

  /// Binds the provided library, validates its ABI, and creates an engine.
  ///
  /// Throws [StateError] for an incompatible ABI or native allocation failure.
  factory CoreEqEngineSession.open(DynamicLibrary library) {
    final native = CoreEqNative(library);
    final version = native.abiVersion;
    if (version != supportedAbiVersion) {
      throw StateError(
        'Unsupported CORE-EQ native ABI $version; '
        'expected $supportedAbiVersion.',
      );
    }

    final handle = native.create();
    if (handle == nullptr) {
      throw StateError('CORE-EQ native engine allocation failed.');
    }
    return CoreEqEngineSession._(native, handle);
  }

  bool get isDisposed => _disposed;

  void _ensureOpen() {
    if (_disposed) {
      throw StateError('CORE-EQ engine session has been disposed.');
    }
  }

  CoreEqStatus setInputGainDb(double db) {
    _ensureOpen();
    return native.setInputGainDb(handle, db);
  }

  CoreEqStatus setOutputGainDb(double db) {
    _ensureOpen();
    return native.setOutputGainDb(handle, db);
  }

  CoreEqStatus setBypassed(bool bypassed) {
    _ensureOpen();
    return native.setBypassed(handle, bypassed);
  }

  CoreEqStatus configureBand({
    required int band,
    required double frequencyHz,
    required double q,
    required double gainDb,
    required double sampleRateHz,
  }) {
    _ensureOpen();
    return native.configureBand(
      handle,
      band: band,
      frequencyHz: frequencyHz,
      q: q,
      gainDb: gainDb,
      sampleRateHz: sampleRateHz,
    );
  }

  CoreEqStatus reset() {
    _ensureOpen();
    return native.reset(handle);
  }

  /// Processes caller-owned interleaved PCM in native memory.
  ///
  /// The caller must keep [samples] valid for the entire call and invoke
  /// processing from only one render thread. Parameter setters must be
  /// serialized through a single producer.
  CoreEqStatus process({
    required Pointer<Float> samples,
    required int frames,
    required int channels,
  }) {
    _ensureOpen();
    return native.process(
      handle,
      samples: samples,
      frames: frames,
      channels: channels,
    );
  }

  /// Releases the native handle. Repeated disposal is harmless.
  void dispose() {
    if (_disposed) return;
    native.destroy(handle);
    _disposed = true;
  }
}
