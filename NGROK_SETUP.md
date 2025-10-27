# Ngrok Setup Notes

## Current Configuration

Your Flask backend is accessible via ngrok at:
- **URL**: `https://7523c621be15.ngrok-free.app`
- **WebSocket**: `wss://7523c621be15.ngrok-free.app`

## Important Ngrok Considerations

### 1. Ngrok Browser Verification

Ngrok free tier shows a warning page the first time you access it. To bypass this in your web app, you may need to:

**Option A**: Accept the warning in browser manually first
1. Open https://7523c621be15.ngrok-free.app in browser
2. Click "Visit Site" button
3. Then use the web app

**Option B**: Add ngrok-skip-browser-warning header (if Flask supports it)

### 2. Flask CORS Configuration

Make sure your Flask backend allows your ngrok domain:

```python
from flask import Flask
from flask_cors import CORS
from flask_socketio import SocketIO

app = Flask(__name__)
# Allow all origins for development
CORS(app, origins="*")

socketio = SocketIO(
    app, 
    cors_allowed_origins="*"  # Allow all for development
)
```

### 3. Ngrok WebSocket Support

- **WSS**: Use `wss://` for secure WebSocket (required for HTTPS ngrok)
- **Transports**: Added both 'websocket' and 'polling' as fallback
- **Reconnection**: Enabled automatic reconnection

## Testing the Connection

### Step 1: Test Flask Backend
```bash
# Test HTTP endpoint
curl -X GET https://7523c621be15.ngrok-free.app

# Test upload endpoint
curl -X POST https://7523c621be15.ngrok-free.app/upload_docs \
  -F "session_id=test123" \
  -F "question=@question.pdf" \
  -F "answer=@answer.pdf"
```

### Step 2: Test WebSocket
- Open browser console in the web app
- Look for "Connected to server" message
- If connection fails, check ngrok tunnel is active

### Step 3: Verify SocketIO Events
- Flask should log when web app connects
- Use browser DevTools → Network → WS to see WebSocket frames

## Common Issues

### Issue: Connection Refused
- **Solution**: Check if ngrok tunnel is running
- **Command**: Check ngrok process is active

### Issue: CORS Error
- **Solution**: Update Flask CORS to allow ngrok domain
- **Code**: `CORS(app, origins=["https://7523c621be15.ngrok-free.app"])`

### Issue: WebSocket Not Connecting
- **Solution**: Use WSS instead of WS for ngrok
- **Check**: Ngrok plan supports WebSockets (free tier does)

### Issue: SSL/Certificate Errors
- **Solution**: Ngrok provides valid SSL certificates
- **Note**: Browser should trust ngrok's certificate automatically

## Mobile App Configuration

For your mobile app to upload images:

```dart
final String serverUrl = 'https://7523c621be15.ngrok-free.app';
final String uploadEndpoint = '$serverUrl/upload_answer';
```

## Production Recommendation

For production:
- Use a proper domain with SSL certificate
- Set up dedicated server (AWS, Heroku, etc.)
- Implement authentication
- Use environment variables for URLs
- Add rate limiting and security headers

## Current App Status

✅ Web app configured for ngrok URL
✅ WebSocket configured for WSS
✅ Reconnection enabled
✅ Fallback to polling transport

You can now run:
```bash
flutter run -d chrome
```

And the app will connect to your Flask backend via ngrok!

