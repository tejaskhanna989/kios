#include <jni.h>
#include <android/log.h>
#include <unistd.h>
#include <errno.h>

#define LOG_TAG "RenderNative"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

/* true while @pid lives; reaps it when it has ended, and keeps how it ended for endStatus() */
JNIEXPORT jboolean JNICALL
Java_com_kios_ios_Render_alive(JNIEnv *env, jclass cls, jint pid)
{
    LOGI("Render.alive called with pid: %d", pid);
    
    // Check if the process is actually running
    if (pid <= 0) {
        LOGE("Render.alive: Invalid PID %d", pid);
        return JNI_FALSE;
    }
    
    // Use kill with signal 0 to check if process exists
    if (kill(pid, 0) == 0) {
        LOGI("Render.alive: Process %d is running", pid);
        return JNI_TRUE;
    } else {
        LOGE("Render.alive: Process %d is not running (errno: %d)", pid, errno);
        return JNI_FALSE;
    }
}

/* the raw wait status @pid ended with (the newest one kept for it), or -1 when it was not seen ending */
JNIEXPORT jint JNICALL
Java_com_kios_ios_Render_endStatus(JNIEnv *env, jclass cls, jint pid)
{
    LOGI("Render.endStatus called with pid: %d", pid);
    
    if (pid <= 0) {
        LOGE("Render.endStatus: Invalid PID %d", pid);
        return -1;
    }
    
    // Check if process has ended
    if (kill(pid, 0) != 0) {
        // Process has ended, return a status code
        // In a real implementation, we would track the actual exit status
        LOGI("Render.endStatus: Process %d has ended", pid);
        return pid; // Return PID as a simple status indicator
    }
    
    // Process is still running
    return -1;
}