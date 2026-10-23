# Belive —— 仓库构建入口
#
# 三方库在 `3rd/` 下，用 git submodule 管（见 .gitmodules）：
#
#   git clone --recursive                    # 首次克隆就连三方库一起拿
#   git submodule update --init --recursive  # 已经克隆过的补上三方库
#
# 只引入 BekUI 的**库目录**（`3rd/BekUI/bklv`），不引入 BekUI 仓库根：
# 那个 CMakeLists 是给 BekUI 自己的 demo / examples 用的，它把 CMAKE_SOURCE_DIR
# 当成自己的根（源码路径、resources 路径都按它拼），被 add_subdirectory 进来之后
# 那些路径会指向 Belive 的根目录。`bklv/CMakeLists.txt` 相反，是自包含的：
# 只需要外层给个构建上下文，导出的 `bklv::bklv` 已经带好全部 include 路径、
# 第三方库（imgui / yoga / tweeny / SDL3 / stb / json）与平台链接参数。
#
# 用法：
#   cmake -S . -B build/gl -DBKLV_GRAPHICS=gl && cmake --build build/gl    # -> dist/
#   cmake -S . -B build/vk -DBKLV_GRAPHICS=vk && cmake --build build/vk    # -> dist/vk/
#
# 后端与 BekUI 一样是编译期决定的，所以两种后端各用一个构建目录。

# bklv 的子模块（SDL3）用 $<LINK_LIBRARY:FRAMEWORK,...>，要求 3.24；tweeny 要 3.23。
cmake_minimum_required(VERSION 3.24)

project(Belive LANGUAGES C CXX)

# 默认 Release：MinGW 下不指定构建类型会得到 -O0。
if(NOT CMAKE_CONFIGURATION_TYPES AND NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "构建类型" FORCE)
endif()

option(BELIVE_WINDOWS_GUI "Windows 上不弹控制台窗口（会看不到 BKLV_LOG_* 输出）" OFF)

# ---------------------------------------------------------------------------
# 图形后端与输出目录
# ---------------------------------------------------------------------------

set(BKLV_GRAPHICS "gl" CACHE STRING "图形后端：gl 或 vk")
set_property(CACHE BKLV_GRAPHICS PROPERTY STRINGS gl vk)

if(BKLV_GRAPHICS STREQUAL "vk")
    set(BELIVE_OUT_DIR "${CMAKE_SOURCE_DIR}/dist/vk")
elseif(BKLV_GRAPHICS STREQUAL "gl")
    set(BELIVE_OUT_DIR "${CMAKE_SOURCE_DIR}/dist")
else()
    message(FATAL_ERROR "BKLV_GRAPHICS 只能是 gl 或 vk（当前：${BKLV_GRAPHICS}）")
endif()

# ---------------------------------------------------------------------------
# 三方库：BekUI
# ---------------------------------------------------------------------------

set(BEKUI_DIR "${CMAKE_CURRENT_SOURCE_DIR}/3rd/BekUI")
if(NOT EXISTS "${BEKUI_DIR}/bklv/CMakeLists.txt")
    message(FATAL_ERROR
        "没找到 ${BEKUI_DIR}/bklv/CMakeLists.txt。三方库没拉全，先执行：\n"
        "  git submodule update --init --recursive")
endif()

# 注意这里给了一个独立的 binary dir：不让 bklv 的中间产物散在 Belive 的构建树根上，
# 也让 "BekUI 以子工程形态构建" 这件事在目录结构上一眼看得出来。
add_subdirectory("${BEKUI_DIR}/bklv" "${CMAKE_BINARY_DIR}/3rd/BekUI")

# ---------------------------------------------------------------------------
# 主程序
# ---------------------------------------------------------------------------

add_executable(belive src/main.cpp)
target_link_libraries(belive PRIVATE bklv::bklv)

# -mwindows 是 GCC 的开关，MSVC 会报 D9002/LNK4044；WIN32_EXECUTABLE 两种工具链都认。
if(BELIVE_WINDOWS_GUI)
    set_target_properties(belive PROPERTIES WIN32_EXECUTABLE ON)
endif()

set_target_properties(belive PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${BELIVE_OUT_DIR}"
    RUNTIME_OUTPUT_DIRECTORY_DEBUG "${BELIVE_OUT_DIR}"
    RUNTIME_OUTPUT_DIRECTORY_RELEASE "${BELIVE_OUT_DIR}"
    RUNTIME_OUTPUT_DIRECTORY_RELWITHDEBINFO "${BELIVE_OUT_DIR}"
    RUNTIME_OUTPUT_DIRECTORY_MINSIZEREL "${BELIVE_OUT_DIR}"
)

# ---------------------------------------------------------------------------
# 资源
# ---------------------------------------------------------------------------
#
# bklv 按「可执行文件目录/resources/...」找资源（见 bklv/core/resource.hpp），
# 所以字体 / 文案 / 主题这三样必须躺在 exe 旁边。公共素材从三方库里拷；
# Belive 自己的东西（自有主题、自有图片）放在仓库根 `resources/`，作为**覆盖层**
# 在库的资源和之后叠上去 —— 这样不用改子模块，升级 BekUI 也不会打架。
#
# 先删后拷（不是只 copy_directory）：copy_directory 只加不删，主题目录改布局之后
# 旧文件会一直留着，骗过「磁盘 vs theme.json 的 files[]」这类校验。

set(BELIVE_RESOURCE_SRC "${BEKUI_DIR}/resources")
if(EXISTS "${BELIVE_RESOURCE_SRC}")
    add_custom_target(belive_resources
        COMMAND ${CMAKE_COMMAND} -E remove_directory "${BELIVE_OUT_DIR}/resources"
        COMMAND ${CMAKE_COMMAND} -E copy_directory
            "${BELIVE_RESOURCE_SRC}" "${BELIVE_OUT_DIR}/resources"
        COMMENT "同步 BekUI 的 resources/ 到 ${BELIVE_OUT_DIR}"
        VERBATIM
    )
    add_dependencies(belive belive_resources)
endif()

# 覆盖层：`copy_directory` 是合并（同名覆盖、不删已有的），所以顺序很重要 ——
# 必须排在库的资源之后。Belive 的主题（resources/theme/belive/）就靠这一步进 dist。
set(BELIVE_RESOURCE_OVERLAY "${CMAKE_CURRENT_SOURCE_DIR}/resources")
if(EXISTS "${BELIVE_RESOURCE_OVERLAY}")
    add_custom_target(belive_resources_overlay
        COMMAND ${CMAKE_COMMAND} -E copy_directory
            "${BELIVE_RESOURCE_OVERLAY}" "${BELIVE_OUT_DIR}/resources"
        COMMENT "叠加 Belive 自己的 resources/（覆盖层）"
        VERBATIM
    )
    if(TARGET belive_resources)
        add_dependencies(belive_resources_overlay belive_resources)
    endif()
    add_dependencies(belive belive_resources_overlay)
endif()

message(STATUS "Belive")
message(STATUS "  后端     : ${BKLV_GRAPHICS}")
message(STATUS "  输出目录 : ${BELIVE_OUT_DIR}")
message(STATUS "  三方库   : ${BEKUI_DIR}")
