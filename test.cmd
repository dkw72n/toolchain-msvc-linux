cmake -G Ninja -B build -DCMAKE_TOOLCHAIN_FILE=cmake\toolchain-msvc-linux.cmake -DWDKBASE="C:\Program Files (x86)\Windows Kits\10" -DMSVCBASE="C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\14.44.35207"  -DWDKVERSION=10.0.22621.0

cmake --build build
