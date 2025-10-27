# AI Answer Sheet Evaluator - Web App

A Flutter web application for an AI-based answer sheet evaluation platform. Upload question papers and answer keys, generate unique session QR codes, and receive real-time answer sheet uploads from mobile devices.

## Features

- 📄 **Upload PDF Documents**: Upload question paper and answer key as PDF files
- 🔑 **Unique Session Generation**: Each session gets a unique session ID
- 📱 **QR Code Display**: Display session ID as QR code for mobile apps to scan
- 🔌 **Real-time Updates**: Connect via SocketIO to receive answer sheet images in real-time
- 🖼️ **Image Grid Display**: View uploaded answer sheets in a responsive grid layout

## Architecture

### Components

1. **Web App (This Project)**: Flutter web application that:
   - Uploads question paper and answer key to Flask backend
   - Generates and displays QR code with session ID
   - Connects via SocketIO for real-time updates
   - Displays uploaded answer sheet images

2. **Mobile App (Separate Project)**: 
   - Scans QR code to get session ID
   - Captures answer sheet images
   - Uploads images to Flask backend

3. **Flask Backend**:
   - Handles file uploads
   - Manages SocketIO connections
   - Broadcasts uploaded images to web app

## Setup Instructions

### 1. Install Dependencies

```bash
flutter pub get
```

### 2. Configure Backend Server

Update the server URL in `lib/main.dart`:

```dart
String _serverUrl = 'ws://localhost:5000'; // Change to your server IP
```

For production, use:
```dart
String _serverUrl = 'ws://YOUR_SERVER_IP:5000';
```

### 3. Run the Flask Backend

Make sure your Flask backend is running on port 5000. You can use the provided Flask code from the project requirements.

```bash
python app.py
```

The backend should run on `http://0.0.0.0:5000`

### 4. Run the Flutter Web App

```bash
flutter run -d chrome
```

Or build for web deployment:

```bash
flutter build web
```

## Usage

### Step 1: Upload Documents

1. Launch the web app
2. Click "Tap to select PDF file" under "Question Paper"
3. Select your question paper PDF
4. Click "Tap to select PDF file" under "Answer Key"
5. Select your answer key PDF
6. Click "Upload & Generate Session"

### Step 2: Generate QR Code

Once uploaded successfully:
- A unique session ID is generated
- A QR code is displayed with the session ID
- SocketIO connection is established
- Status shows "Listening for uploads..."

### Step 3: Mobile App Integration

Mobile app should:
1. Scan the QR code to get the session ID
2. Capture answer sheet images
3. Upload images to the Flask backend at `/upload_answer`

### Step 4: Real-time Display

As mobile apps upload answer sheets:
- Images appear in real-time in a grid layout
- Each image shows page number and timestamp
- Notification appears when new upload is received

## Project Structure

```
lib/
├── main.dart               # Main application with UI and SocketIO integration
└── web_file_upload.dart   # Web-specific file upload handling

pubspec.yaml               # Dependencies configuration
```

## Dependencies

- `qr_flutter`: QR code generation and display
- `socket_io_client`: SocketIO connection for real-time updates
- `http`: HTTP requests for file uploads
- `uuid`: Generate unique session IDs
- `image`: Image processing for display

## API Endpoints

### Flask Backend Endpoints

**POST /upload_docs**
- Uploads question paper and answer key
- Parameters: `session_id`, `question` (file), `answer` (file)
- Returns: `{"status": "success", "session_id": "..."}`

**POST /upload_answer**
- Receives answer sheet images from mobile app
- Parameters: `session_id`, `page_number`, `image` (file)
- Triggers SocketIO event: `new_upload`

### SocketIO Events

**Web App Emits:**
- `join` with `{'session_id': sessionId}`

**Web App Listens:**
- `joined`: Confirmation of successful connection
- `new_upload`: New answer sheet image received
  ```json
  {
    "session_id": "...",
    "page": "1",
    "img": "base64_encoded_image"
  }
  ```

## Configuration

To use this with a remote server, update the server URL:

```dart
// In lib/main.dart
String _serverUrl = 'ws://192.168.1.100:5000'; // Your server IP
```

## Troubleshooting

### Connection Issues

If SocketIO connection fails:
1. Check if Flask backend is running
2. Verify server URL is correct
3. Check CORS settings in Flask backend
4. Ensure websocket protocol is enabled

### File Upload Issues

If file upload fails:
1. Check backend is accessible from browser
2. Verify backend URL in HTTP request
3. Check browser console for errors
4. Ensure PDF files are valid

### Display Issues

If images don't display:
1. Check base64 encoding in SocketIO events
2. Verify image format is supported
3. Check browser console for decoding errors

## Development

### Running in Development Mode

```bash
flutter run -d chrome --web-port=8080
```

### Building for Production

```bash
flutter build web --release
```

The built files will be in `build/web/` directory.

## Notes

- This web app only handles the web interface
- Mobile app is a separate Flutter project
- Both apps communicate through the Flask backend
- SocketIO enables real-time bidirectional communication
- QR codes provide easy session ID sharing between devices

## License

This project is developed for AI-based answer sheet evaluation platform.