cmake_minimum_required(VERSION 3.20)
project(core_eq_dsp LANGUAGES CXX)

add_library(core_eq_dsp STATIC src/dsp.cpp)
target_include_directories(core_eq_dsp PUBLIC include)
target_compile_features(core_eq_dsp PUBLIC cxx_std_17)
set_target_properties(core_eq_dsp PROPERTIES POSITION_INDEPENDENT_CODE ON)

set(CORE_EQ_C_SOURCES src/c_api.cpp)
if(ANDROID)
  list(APPEND CORE_EQ_C_SOURCES src/android_jni.cpp)
endif()

add_library(core_eq_c SHARED ${CORE_EQ_C_SOURCES})
target_include_directories(core_eq_c PUBLIC include)
target_link_libraries(core_eq_c PRIVATE core_eq_dsp)
target_compile_features(core_eq_c PRIVATE cxx_std_17)
target_compile_definitions(core_eq_c PRIVATE CORE_EQ_C_API_BUILD)
set_target_properties(core_eq_c PROPERTIES
  CXX_VISIBILITY_PRESET hidden
  VISIBILITY_INLINES_HIDDEN YES
  OUTPUT_NAME core_eq
)

option(CORE_EQ_BUILD_TESTS "Build CORE-EQ DSP tests" ON)
if(CORE_EQ_BUILD_TESTS)
  enable_testing()
  add_executable(core_eq_dsp_tests tests/dsp_test.cpp)
  target_link_libraries(core_eq_dsp_tests PRIVATE core_eq_dsp)
  add_test(NAME core_eq_dsp_tests COMMAND core_eq_dsp_tests)

  add_executable(core_eq_frequency_response_tests tests/frequency_response_test.cpp)
  target_link_libraries(core_eq_frequency_response_tests PRIVATE core_eq_dsp)
  add_test(NAME core_eq_frequency_response_tests COMMAND core_eq_frequency_response_tests)

  add_executable(core_eq_c_api_tests tests/c_api_test.cpp)
  target_link_libraries(core_eq_c_api_tests PRIVATE core_eq_c)
  target_compile_definitions(core_eq_c_api_tests PRIVATE CORE_EQ_C_API_BUILD)
  add_test(NAME core_eq_c_api_tests COMMAND core_eq_c_api_tests)
endif()
