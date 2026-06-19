set(CMAKE_FIND_LIBRARY_PREFIXES "lib" "")
set(CMAKE_FIND_LIBRARY_SUFFIXES ".so;.a")

set(CMAKE_SYSROOT "/usr")

set(CMAKE_LIBRARY_PATH "/usr/lib/x86_64-linux-gnu" "/lib/x86_64-linux-gnu")

set(CMAKE_EXE_LINKER_FLAGS "-L/usr/lib/x86_64-linux-gnu -L/lib/x86_64-linux-gnu")
set(CMAKE_SHARED_LINKER_FLAGS "-L/usr/lib/x86_64-linux-gnu -L/lib/x86_64-linux-gnu")