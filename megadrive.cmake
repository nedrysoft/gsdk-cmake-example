# Uses the marsdev system for easy setup of the build environment.
#
# This CMakeLists file is based on the Makefile example supplied with marsdev.
#
# https://github.com/andwn/marsdev

# if the user HAS NOT defined the MARSDEV variable in the invokation of CMake, then we set our MARSDEV variable
# to the value of the MARSDEV environment variable, providing that it has been defined.
#
# if the user has defined the MARSDEV variable in the invokation of CMake, then that value is used for the script.

if(NOT DEFINED MARSDEV AND DEFINED ENV{MARSDEV})
        set(MARSDEV $ENV{MARSDEV})
endif()

# if the user HAS NOT defined the SGDK variable in the invokation of CMake, then we set our SGDK variable to the 
# value of the SGDK environment variable, providing that it has been defined.
#
# if the user has defined the SGDK variable in the invokation of CMake, then that value is used for the script.

if (DEFINED ENV{SGDK})
        set(SGDK $ENV{SGDK})
endif()

# now check that both MARSDEV and SGDK have been defined, we can't continue without them.

if(NOT DEFINED MARSDEV)
        message(FATAL_ERROR "MARSDEV has not been defined, to build this ROM you must have marsdev installed and the MARSDEV variable set to the location where it is installed.  (see: https://github.com/andwn/marsdev)")
endif()

if(NOT DEFINED SGDK)
        message(FATAL_ERROR "SGDK has not been defined, to build this ROM you must have marsdev installed and the SGDK variable set to the location where it is installed.  (see: https://github.com/andwn/marsdev)")
endif()

set(MARSBIN ${MARSDEV}/m68k-elf/bin)

# we're told we shouldn't do this, but in our case where we're using a standalone compiler built for a specific
# purpose, we'll forego that and do it anyway.

set(CMAKE_SYSTEM_NAME Generic)

set(CMAKE_AR ${MARSBIN}/m68k-elf-ar)
set(CMAKE_ASM_COMPILER ${MARSBIN}/m68k-elf-as)
set(CMAKE_C_COMPILER ${MARSBIN}/m68k-elf-gcc)
set(CMAKE_LINKER ${MARSBIN}/m68k-elf-ld)
set(CMAKE_OBJCOPY ${MARSDEV}/m68k-elf/bin/m68k-elf-objcopy)
set(CMAKE_RANLIB ${MARSDEV}/m68k-elf/bin/m68k-elf-ranlib)
set(CMAKE_SIZE ${MARSDEV}/m68k-elf/bin/m68k-elf-size)
set(CMAKE_STRIP ${MARSDEV}/m68k-elf/bin/m68k-elf-strip)

set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

execute_process(COMMAND ${CMAKE_C_COMPILER} -dumpversion OUTPUT_VARIABLE GCC_VERSION OUTPUT_STRIP_TRAILING_WHITESPACE)

enable_language(ASM)

# now check for tools and things that we will definitely need, they should be there providing marsdev is installed....

if(NOT EXISTS "${MARSDEV}/bin/rescomp.jar")
        message(FATAL_ERROR "the rescomp tool was not found.")
endif()

# set the appropriate flags for the compiler, assembler and linker

set(CMAKE_ASM_FLAGS "-m68000 --register-prefix-optional")

set(CMAKE_EXE_LINKER_FLAGS "-T ${MARSDEV}/ldscripts/sgdk.ld -lgcc -nostdlib -fcommon")

set(CMAKE_EXECUTABLE_SUFFIX ".elf")

# now that we have had both MARSDEV and SGDK defined, it's time now to check that we actually have the tools there.

set(SGDK_INCLUDES
        ${SGDK}
        ${SGDK}/inc
        ${SGDK}/res
)

set(MARSDEV_INCLUDES
        ${MARSDEV}/m68k-elf/lib/gcc/m68k-elf/${GCC_VERSION}/include
        ${MARSDEV}/m68k-elf/include
        ${MARSDEV}/m68k-elf/m68k-elf/include
)

find_library(
        LIBMD_LIBRARY md 
        HINTS ${MARSDEV}/m68k-elf/lib 
        REQUIRED
)

find_library(
        LIBGCC_LIBRARY gcc 
        HINTS ${MARSDEV}/m68k-elf/lib/gcc/m68k-elf/${GCC_VERSION} 
        REQUIRED
)

include_directories(
        ${SGDK_INCLUDES} 
        ${MARSDEV_INCLUDES} 
        ${CMAKE_CURRENT_BINARY_DIR}
)

link_libraries(
        ${LIBMD_LIBRARY} 
        ${LIBGCC_LIBRARY}
)

# produces a raw ROM binary from an .elf binary

function(megadrive_create_rom)
        add_custom_command(
                TARGET ${PROJECT_NAME}
                
                POST_BUILD

                COMMAND ${CMAKE_OBJCOPY} ARGS -O binary ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}.elf ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}.md
        )
endfunction()

# takes a .res file, adds a custom command to build it and adds the resulting source and header files to the executable target

function(megadrive_include_resources FILE)
        get_filename_component(RESOURCE_NAME ${FILE} NAME_WLE)
        get_filename_component(RESOURCE_PATH ${FILE} DIRECTORY)

        # we open the resource file, read it line by line to extract the filenames of the images that are referenced

        file(STRINGS ${FILE} RES_FILE_CONTENT)

        foreach(RES_FILE_LINE ${RES_FILE_CONTENT})

                string(REPLACE " " ";" RES_FILE_LINE_LIST ${RES_FILE_LINE})

                list(LENGTH RES_FILE_LINE_LIST LIST_LENGTH)

                list(GET RES_FILE_LINE_LIST 2 RES_ITEM_FILENAME)

                string(REPLACE "\"" "" RES_ITEM_FILENAME ${RES_ITEM_FILENAME})

                list(APPEND RES_DEPENDS "${CMAKE_SOURCE_DIR}/${RESOURCE_PATH}/${RES_ITEM_FILENAME}")
        endforeach()

        # add the custom command to compile the resources into the assembler and header files.
        #
        # the .res file is made a dependency, so any changes to that will result in the resources being re-built, and
        # any changes to the actual files referenced inside the .res file will also invoke the compiler as well

        add_custom_command(
            OUTPUT  ${RESOURCE_NAME}.s ${RESOURCE_NAME}.h
            COMMAND java -jar ${MARSDEV}/bin/rescomp.jar ${CMAKE_SOURCE_DIR}/${FILE} ${CMAKE_CURRENT_BINARY_DIR}/${RESOURCE_NAME}.s
            DEPENDS ${FILE} ${RES_DEPENDS}
        )

        target_sources(${PROJECT_NAME} PRIVATE 
                ${CMAKE_CURRENT_BINARY_DIR}/${RESOURCE_NAME}.s 
                ${CMAKE_CURRENT_BINARY_DIR}/${RESOURCE_NAME}.h
        )
endfunction()