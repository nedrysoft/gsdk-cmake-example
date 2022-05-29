cmake_minimum_required(VERSION 3.10)

include(megadrive.cmake)

project(test)

add_executable(
        ${PROJECT_NAME} 

        boot/sega.s
        src/main.c
 )

target_include_directories(
        ${PROJECT_NAME} PUBLIC 

        ./boot 
)

megadrive_include_resources(./res/resources.res)

megadrive_create_rom()
