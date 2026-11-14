LOCAL_PATH := $(call my-dir)
include $(CLEAR_VARS)
LOCAL_MODULE := librender
LOCAL_SRC_FILES := render.c
LOCAL_LDLIBS := -llog
include $(BUILD_SHARED_LIBRARY)
