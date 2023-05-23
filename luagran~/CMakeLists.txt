include(${CMAKE_CURRENT_SOURCE_DIR}/../../max-sdk-base/script/max-pretarget.cmake)

#############################################################
# MAX EXTERNAL
#############################################################
set(LUADIR ${CMAKE_CURRENT_SOURCE_DIR}/lua)

include_directories( 
	"${MAX_SDK_INCLUDES}"
	"${MAX_SDK_MSP_INCLUDES}"
	"${MAX_SDK_JIT_INCLUDES}"
	"${LUADIR}"
)
if(UNIX)
	link_libraries(${LUADIR}/liblua.a)
else()
	link_libraries(${LUADIR}/lua54.lib)
endif()

file(GLOB PROJECT_SRC
     "*.h"
	 "*.c"
     "*.cpp"
)

add_library( 
	${PROJECT_NAME} 
	MODULE
	${PROJECT_SRC}
)

include(${CMAKE_CURRENT_SOURCE_DIR}/../../max-sdk-base/script/max-posttarget.cmake)