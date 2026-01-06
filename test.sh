cmake -B build -DCMAKE_TOOLCHAIN_FILE=cmake/toolchain-msvc-linux.cmake -DWDKBASE=$HOME/winsdk/sdk -DMSVCBASE=$HOME/winsdk/crt

cmake --build build
