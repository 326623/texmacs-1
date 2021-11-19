### --------------------------------------------------------------------
### Set the executable target name and other stuff
### --------------------------------------------------------------------

if (APPLE)
  set (TeXmacs_binary_name "TeXmacs")
elseif (WIN32)
  set (TeXmacs_binary_name "texmacs")
else (APPLE)
  set (TeXmacs_binary_name "texmacs.bin")
endif (APPLE)

add_library(texmacs_body STATIC ${TeXmacs_All_SRCS})

if (WIN32)
  add_executable (${TeXmacs_binary_name} WIN32
    ./Texmacs/Texmacs/texmacs.cpp
  )
else (WIN32)
  add_executable (${TeXmacs_binary_name}
    ./Texmacs/Texmacs/texmacs.cpp
  )
endif (WIN32)

target_link_libraries (${TeXmacs_binary_name}
  texmacs_body
  ${TeXmacs_Libraries}
)

# TODO: some more work here -- include the Scheme source.
if (APPLE)
  set(MACOSX_BUNDLE_DISPLAY_NAME TeXmacs)
  set_target_properties (${TeXmacs_binary_name}
    PROPERTIES
    MACOSX_BUNDLE TRUE
    MACOSX_BUNDLE_INFO_PLIST ${TEXMACS_SOURCE_DIR}/packages/macos/Info.plist.in
    DEBUG_OUTPUT_NAME ${TeXmacs_binary_name}${EXE_DEBUG_EXTENSION}
    RELEASE_OUTPUT_NAME ${TeXmacs_binary_name}
    RUNTIME_OUTPUT_DIRECTORY ${TEXMACS_BINARY_DIR}
  )
elseif (WIN32)
#  # Doesn't need this for static builds -- sort of
#  install(
#          TARGETS ${}
#          ARCHIVE
#          DESTINATION lib
#          COMPONENT libraries
#  )
  install(
          TARGETS ${TeXmacs_binary_name}
          RUNTIME
          DESTINATION bin
          COMPONENT applications
  )
# Doesn't need this for shipping application
#  install(
#          FILES mylib.h
#          DESTINATION include
#          COMPONENT headers
#  )
  include(InstallRequiredSystemLibraries)
  set(CPACK_RESOURCE_FILE_LICENSE "${CMAKE_SOURCE_DIR}/LICENSE")
  set(CPACK_PACKAGE_VERSION_MAJOR "${VERSION_MAJOR}")
  set(CPACK_PACKAGE_VERSION_MINOR "${VERSION_MINOR}")
  set(CPACK_PACKAGE_VERSION_PATCH "${VERSION_BUILD}")
  include(CPack)
else (APPLE)
  install (TARGETS ${TeXmacs_binary_name} DESTINATION ${tmbin}/bin)
endif (APPLE)

