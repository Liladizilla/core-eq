#pragma once

#include <stddef.h>
#include <stdint.h>

#if defined(_WIN32)
  #if defined(CORE_EQ_C_API_BUILD)
    #define CORE_EQ_API __declspec(dllexport)
  #else
    #define CORE_EQ_API __declspec(dllimport)
  #endif
#else
  #define CORE_EQ_API __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef struct core_eq_handle core_eq_handle;

typedef enum core_eq_status {
  CORE_EQ_STATUS_OK = 0,
  CORE_EQ_STATUS_INVALID_ARGUMENT = 1,
  CORE_EQ_STATUS_QUEUE_FULL = 2
} core_eq_status;

CORE_EQ_API uint32_t core_eq_abi_version(void);
CORE_EQ_API core_eq_handle* core_eq_create(void);
CORE_EQ_API void core_eq_destroy(core_eq_handle* handle);

CORE_EQ_API core_eq_status core_eq_set_input_gain_db(core_eq_handle* handle, float gain_db);
CORE_EQ_API core_eq_status core_eq_set_output_gain_db(core_eq_handle* handle, float gain_db);
CORE_EQ_API core_eq_status core_eq_set_bypassed(core_eq_handle* handle, int bypassed);
CORE_EQ_API core_eq_status core_eq_configure_band(core_eq_handle* handle, uint32_t band,
                                                  float frequency_hz, float q,
                                                  float gain_db, float sample_rate_hz);
CORE_EQ_API core_eq_status core_eq_reset(core_eq_handle* handle);
CORE_EQ_API core_eq_status core_eq_process(core_eq_handle* handle, float* interleaved,
                                           size_t frames, size_t channels);

#ifdef __cplusplus
}
#endif
