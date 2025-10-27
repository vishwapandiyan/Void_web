# Quick Start Guide

## 1. Install Dependencies

```bash
flutter pub get
```

## 2. Run Flask Backend

Create a file named `app.py` with your Flask backend code and run:

```bash
python app.py
```

The server will start on `http://0.0.0.0:5000`

## 3. Configure Server URL (if needed)

Edit `lib/config.dart` if your server is running on a different host:

```dart
static const String serverUrl = 'http://YOUR_IP:5000';
static const String websocketUrl = 'ws://YOUR_IP:5000';
```

## 4. Run the Web App

```bash
flutter run -d chrome
```

The app will open in Chrome.

## 5. Usage Flow

### Step 1: Upload Files
- Click on "Question Paper" card to select a PDF
- Click on "Answer Key" card to select a PDF
- Click "Upload & Generate Session"

### Step 2: Get QR Code
- QR code is displayed with session ID
- Status shows "Listening for uploads..."
- Copy or screenshot the QR code

### Step 3: Mobile App
- Mobile app scans QR code to get session_id
- Mobile app captures answer sheets
- Uploads images via `/upload_answer`

### Step 4: Real-time Updates
- Answer sheet images appear in the grid
- Each image shows page number and time
- New uploads trigger notifications

## Testing Without Mobile App

You can test the SocketIO connection by sending a test event to the backend:

```python
from flask_socketio import emit
socketio.emit('new_upload', {
    'session_id': 'your-session-id',
    'page': '1',
    'img': 'base64_encoded_image_data'
}, room='your-session-id')
```

## Build for Deployment

```bash
flutter build web --release
```

Deploy the contents of `build/web/` to your web server.

## Troubleshooting

### Error: "Connection error"
- Verify Flask backend is running
- Check server URL in `lib/config.dart`
- Ensure port 5000 is open

### Error: "Upload failed"
- Check CORS settings in Flask backend
- Verify backend is accessible from browser
- Check browser console for detailed errors

### Images not displaying
- Check SocketIO events are being emitted correctly
- Verify base64 encoding in backend
- Check browser console for decoding errors


