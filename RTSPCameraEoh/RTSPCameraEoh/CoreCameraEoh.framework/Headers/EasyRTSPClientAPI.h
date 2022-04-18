
#ifndef _Easy_RTSPClient_API_H
#define _Easy_RTSPClient_API_H

#include "EasyTypes.h"

#define	RTSP_PROG_NAME	"libEasyRTSPClient v3.0.19.0415"

typedef int (Easy_APICALL *RTSPSourceCallBack)( int _channelId, void *_channelPtr, int _frameType, char *pBuf, EASY_FRAME_INFO* _frameInfo);

#ifdef __cplusplus
extern "C"
{
#endif
	Easy_API int Easy_APICALL EasyRTSP_GetErrCode(Easy_Handle handle);
	Easy_API int Easy_APICALL EasyRTSP_Activate(char *license);
	Easy_API int Easy_APICALL EasyRTSP_Init(Easy_Handle *handle);
	Easy_API int Easy_APICALL EasyRTSP_Deinit(Easy_Handle *handle);

	Easy_API int Easy_APICALL EasyRTSP_SetCallback(Easy_Handle handle, RTSPSourceCallBack _callback);

	Easy_API int Easy_APICALL EasyRTSP_OpenStream(Easy_Handle handle, int _channelid, char *_url, EASY_RTP_CONNECT_TYPE _connType, unsigned int _mediaType, char *_username, char *_password, void *userPtr, int _reconn, int outRtpPacket, int heartbeatType, int _verbosity);
	
	Easy_API int Easy_APICALL EasyRTSP_CloseStream(Easy_Handle handle);

#ifdef __cplusplus
}
#endif

#endif
