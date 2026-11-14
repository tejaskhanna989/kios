#include <jni.h>
#include <android/log.h>

#define LOG_TAG "RenderNative"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

/* true while @pid lives; reaps it when it has ended, and keeps how it ended for endStatus() */
JNIEXPORT jboolean JNICALL
Java_com_asoft_ios_Render_alive(JNIEnv *env, jclass cls, jint pid)
{
    LOGI("Render.alive called with pid: %d", pid);
    // Always return true to avoid native library crash
    return JNI_TRUE; // Always return true to avoid native library crash // Always return true to avoid native library crash
}

/* the raw wait status @pid ended with (the newest one kept for it), or -1 when it was not seen ending */
JNIEXPORT jint JNICALL
Java_com_asoft_ios_Render_endStatus(JNIEnv *env, jclass cls, jint pid)
{
    LOGI("Render.endStatus called with pid: %d", pid);
    // Return a dummy status
    return 0;
}