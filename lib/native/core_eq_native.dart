import 'dart:ffi';

import 'package:flutter/foundation.dart';

/// Status codes returned by the CORE-EQ C ABI.
enum CoreEqStatus {
  ok(0),
  invalidArgument(1),
  queueFull(2),
  unknown(-1);

  const CoreEqStatus(this.code);
  final int code;

  static CoreEqStatus fromCode(int code) => CoreEqStatus.values.firstWhere(
        (status) => status.code == code,
        orElse: () => CoreEqStatus.unknown,
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
  static const int supportedAbiVersion = 1;

  /// Resolves the shared library name used by supported Flutter targets.
  static String libraryNameForPlatform(TargetPlatform platform) {
    switch (platform) {
      case TargetPlatform.android:
      case TargetPlatform.linux:
        return 'libcore_eq.so';
      case TargetPlatform.windows:
        return 'core_eq.dll';
      case TargetPlatform.macOS:
        return 'libcore_eq.dylib';
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'CORE-EQ uses an iOS player/AUv3 integration; DynamicLibrary.open '
          'is not the iOS packaging path.',
        );
      case TargetPlatform.fuchsia:
        throw UnsupportedError('CORE-EQ has no Fuchsia native build yet.');
    }
  }

  /// Loads the packaged native library and rejects incompatible ABI versions.
  factory CoreEqNative.openDefault() {
    final libraryName = libraryNameForPlatform(defaultTargetPlatform);
    final DynamicLibrary library;
    try {
      library = DynamicLibrary.open(libraryName);
    } on ArgumentError catch (error) {
      throw StateError(
        'Unable to load CORE-EQ native library "$libraryName". '
        'Build/package the native library for this platform first. Details: $error',
      );
    }
    final native = CoreEqNative(library);
    if (native.abiVersion != supportedAbiVersion) {
      throw StateError(
        'CORE-EQ ABI mismatch: Dart expects $supportedAbiVersion, '
        'native library reports ${native.abiVersion}.',
      );
    }
    return native;
  }

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
/// The raw handle and low-level bindings stay private so callers cannot bypass
/// the session's disposed-state checks.
final class CoreEqEngineSession {
  CoreEqEngineSession._(this._native, this._handle);

  static const supportedAbiVersion = 1;

  final CoreEqNative _native;
  final Pointer<CoreEqHandle> _handle;
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
    return _native.setInputGainDb(_handle, db);
  }

  CoreEqStatus setOutputGainDb(double db) {
    _ensureOpen();
    return _native.setOutputGainDb(_handle, db);
  }

  CoreEqStatus setBypassed(bool bypassed) {
    _ensureOpen();
    return _native.setBypassed(_handle, bypassed);
  }

  CoreEqStatus configureBand({
    required int band,
    required double frequencyHz,
    required double q,
    required double gainDb,
    required double sampleRateHz,
  }) {
    _ensureOpen();
    return _native.configureBand(
      _handle,
      band: band,
      frequencyHz: frequencyHz,
      q: q,
      gainDb: gainDb,
      sampleRateHz: sampleRateHz,
    );
  }

  CoreEqStatus reset() {
    _ensureOpen();
    return _native.reset(_handle);
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
    return _native.process(
      _handle,
      samples: samples,
      frames: frames,
      channels: channels,
    );
  }

  /// Releases the native handle. Repeated disposal is harmless.
  ///
  /// Stop and join any render thread using this session before disposing it;
  /// disposal is not synchronized with an in-flight native process call.
  void dispose() {
    if (_disposed) return;
    _native.destroy(_handle);
    _disposed = true;
  }
}
