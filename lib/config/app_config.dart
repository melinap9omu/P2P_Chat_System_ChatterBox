const String NGROK_HTTP_URL = "https://4a0a-27-34-73-225.ngrok-free.app";

// Changed from 'const' to 'final' to allow the substring method call
final String NGROK_WS_URL = "ws${NGROK_HTTP_URL.substring(5)}/signal";

const String SERVER_HTTP_BASE_URL = NGROK_HTTP_URL;
final String SERVER_WS_URL = NGROK_WS_URL; // Also changed to final, as it depends on NGROK_WS_URL
final String SIGNALING_SERVER_URL = NGROK_WS_URL; 