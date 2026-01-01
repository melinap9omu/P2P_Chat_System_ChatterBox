const String NGROK_HTTP_URL = "http://192.168.16.108:8080";
// Changed from 'const' to 'final' to allow the substring method call
final String NGROK_WS_URL = NGROK_HTTP_URL.replaceFirst('http', 'ws');

const String SERVER_HTTP_BASE_URL = NGROK_HTTP_URL;
final String CHAT_WS_URL = "${NGROK_WS_URL}/websocket"; // Also changed to final, as it depends on NGROK_WS_URL
final String SIGNALING_SERVER_URL = "${NGROK_WS_URL}/signal";