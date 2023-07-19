#  Copyright (c) 2023 Intel Corporation
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
if(WIN32 OR UNIX)
	if(CMAKE_SIZEOF_VOID_P EQUAL 8)
		set(ARCH x86_64)
	else()
		set(ARCH i386)
	endif()
endif()

if(WIN32)
	foreach (flag_var
			CMAKE_C_FLAGS CMAKE_C_FLAGS_DEBUG CMAKE_C_FLAGS_RELEASE
			CMAKE_C_FLAGS_MINSIZEREL CMAKE_C_FLAGS_RELWITHDEBINFO
			CMAKE_CXX_FLAGS CMAKE_CXX_FLAGS_DEBUG CMAKE_CXX_FLAGS_RELEASE
			CMAKE_CXX_FLAGS_MINSIZEREL CMAKE_CXX_FLAGS_RELWITHDEBINFO)
		string(REPLACE "/MD" "/MT" ${flag_var} "${${flag_var}}")
	endforeach()
	add_compile_definitions(_CRT_SECURE_NO_WARNINGS NOMINMAX )
	string(APPEND CMAKE_CXX_FLAGS " /MP /FS /wd4275 /wd4819")
	string(APPEND CMAKE_C_FLAGS " /MP /FS")
else()
	if(CMAKE_CXX_COMPILER_VERSION VERSION_LESS 7.2.1)
		message(FATAL_ERROR "GCC version less then the minimum required for neural_engine build which is 7.2.1, skip the neural_engine build")
	endif()
	string(APPEND CMAKE_CXX_FLAGS " -fPIC ")
	string(APPEND CMAKE_C_FLAGS " -fPIC ")
endif()

 set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")
 set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")
 set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")
 set(CMAKE_PDB_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")
 set(CMAKE_COMPILE_PDB_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")
