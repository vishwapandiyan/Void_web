# System Architecture

## Communication Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    FLUTTER WEB APP                           │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐            │
│  │   Upload   │  │    QR      │  │   Image    │            │
│  │  Section   │→ │   Code     │  │   Grid     │            │
│  └────────────┘  └────────────┘  └────────────┘            │
│        ↓              ↓              ↑                       │
└────────┼──────────────┼──────────────┼───────────────────────┘
         │              │              │
         │ HTTP POST    │ SocketIO     │ SocketIO
         │ /upload_docs │ join         │ new_upload
         ↓              ↓              │
┌─────────────────────────────────────────────────────────────┐
│                    FLASK BACKEND                             │
│  ┌─────────────────┐         ┌─────────────────┐           │
│  │  POST /upload_  │         │   SocketIO      │           │
│  │      docs       │         │   Server        │           │
│  │  - Saves PDFs   │         │  - Room mgmt    │           │
│  │  - Stores by    │◄───────►│  - Event emit   │           │
│  │    session_id   │         │  - Broadcast   │           │
│  └─────────────────┘         └─────────────────┘           │
│           ↑                           ↑                     │
└───────────┼───────────────────────────┼─────────────────────┘
            │                           │
            │ HTTP POST                 │ SocketIO
            │ /upload_answer            │ emit(new_upload)
            ↓                           ↓
┌─────────────────────────────────────────────────────────────┐
│                FLUTTER MOBILE APP                           │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐            │
│  │ Scan QR    │→ │  Capture   │→ │  Upload    │            │
│  │  Code      │  │   Image    │  │  to Flask  │            │
│  └────────────┘  └────────────┘  └────────────┘            │
└─────────────────────────────────────────────────────────────┘
```

## Data Flow

### 1. Upload Documents
```
Web App                          Flask Backend
   │                                  │
   ├─ POST /upload_docs ─────────────►│
   │   - session_id                  │
   │   - question.pdf                │─ Save to uploads/session_id/
   │   - answer.pdf                  │
   │                                  │
   │◄─── {"status": "success"}────────┤
   │                                  │
```

### 2. Generate QR & Connect
```
Web App                          Flask Backend
   │                                  │
   ├─ socket.emit('join') ──────────►│
   │   {'session_id': 'abc'}         │─ Join room(session_id)
   │                                  │
   │◄─── socket.on('joined') ─────────┤
   │     {'message': 'Joined'}       │
   │                                  │
```

### 3. Receive Uploads
```
Mobile App                      Flask Backend             Web App
   │                                  │                      │
   ├─ POST /upload_answer ───────────►│                      │
   │   - session_id                   │                      │
   │   - page_number                  │                      │
   │   - image.jpg                    │                      │
   │                                  │                      │
   │                                  ├─ Save to              │
   │                                  │  uploads/session_id/ │
   │                                  │                      │
   │                                  ├─ Convert to base64   │
   │                                  │                      │
   │                                  ├─ emit('new_upload')  │
   │                                  │                      │
   │                                  └──────────────────────►│
   │                                                          │─ Display
   │                                                          │  in grid
   │◄─── {"status": "success"}────────┤                      │
   │                                  │                      │
```

## Component Details

### Web App Components

```
MainScreen (StatefulWidget)
├── Upload Section
│   ├── FileUploadWidget (Question Paper)
│   ├── FileUploadWidget (Answer Key)
│   └── Upload Button
│
├── QR Code Section (after upload)
│   ├── QrImageView
│   ├── Session ID Display
│   └── Status Indicator
│
└── Image Grid Section (real-time)
    └── GridView.builder
        └── AnswerSheetCard (per image)
```

### SocketIO Events

#### Web App → Backend
```javascript
{
  event: 'join',
  data: {
    'session_id': 'abc-123-def-456'
  }
}
```

#### Backend → Web App
```javascript
// Connection confirmed
{
  event: 'joined',
  data: {
    'message': 'Joined room abc-123-def-456'
  }
}

// New image uploaded
{
  event: 'new_upload',
  data: {
    'session_id': 'abc-123-def-456',
    'page': '1',
    'img': 'iVBORw0KGgoAAAANS...'  // base64
  }
}
```

### File Upload Format

#### To /upload_docs
```
multipart/form-data:
  session_id: "abc-123-def-456"
  question: <PDF file>
  answer: <PDF file>
```

#### To /upload_answer
```
multipart/form-data:
  session_id: "abc-123-def-456"
  page_number: "1"
  image: <JPG file>
```

## File Storage Structure

```
uploads/
└── {session_id}/
    ├── question.pdf
    ├── answer.pdf
    ├── page_1.jpg
    ├── page_2.jpg
    ├── page_3.jpg
    └── ...
```

## Session Flow Diagram

```
Step 1: User uploads PDFs
│
├─► Generate UUID for session_id
├─► Upload to Flask: POST /upload_docs
├─► Flask saves: uploads/{session_id}/
└─► Response: {"status": "success"}

Step 2: Connect & Generate QR
│
├─► Connect to SocketIO
├─► Emit: join with session_id
├─► Receive: joined confirmation
└─► Display QR code with session_id

Step 3: Mobile app scans & uploads
│
├─► Mobile: Scans QR → gets session_id
├─► Mobile: Captures image
├─► Mobile: POST /upload_answer
├─► Flask: Saves image, converts to base64
├─► Flask: Emits 'new_upload' to room
└─► Web: Receives event → displays image

Step 4: Repeat for more pages
```

## Security Considerations

### Current Implementation
- ✅ Session-based isolation via SocketIO rooms
- ✅ Unique session IDs (UUID v4)
- ✅ File validation (PDF format)

### Recommended Additions
- 🔐 Authentication for sessions
- 🔐 HTTPS/WSS for secure communication
- 🔐 Rate limiting for uploads
- 🔐 File size limits
- 🔐 Virus scanning

## Deployment Architecture

```
┌─────────────────────────────────────────────────────┐
│                    Client Layer                      │
│                                                     │
│  ┌─────────────┐          ┌─────────────┐         │
│  │ Web Browser │          │ Mobile App  │         │
│  │ (Flutter    │          │ (Flutter    │         │
│  │  Web App)   │          │  App)       │         │
│  └──────┬──────┘          └──────┬──────┘         │
│         │                         │                │
└─────────┼─────────────────────────┼────────────────┘
          │                         │
          │ HTTPS/WSS              │ HTTPS
          ↓                         ↓
┌─────────────────────────────────────────────────────┐
│                   Server Layer                      │
│                                                     │
│  ┌────────────────────────────────────────────┐   │
│  │        Flask Application                    │   │
│  │  ┌──────────────────────────────────────┐ │   │
│  │  │   HTTP Server (port 5000)            │ │   │
│  │  │   - POST /upload_docs                │ │   │
│  │  │   - POST /upload_answer              │ │   │
│  │  └──────────────────────────────────────┘ │   │
│  │  ┌──────────────────────────────────────┐ │   │
│  │  │   SocketIO Server                     │ │   │
│  │  │   - WebSocket transport               │ │   │
│  │  │   - Room-based messaging              │ │   │
│  │  │   - Events: join, joined, new_upload  │ │   │
│  │  └──────────────────────────────────────┘ │   │
│  └────────────────────────────────────────────┘   │
│                                                     │
│  ┌────────────────────────────────────────────┐   │
│  │        File Storage                          │   │
│  │   uploads/{session_id}/                     │   │
│  │   - question.pdf                            │   │
│  │   - answer.pdf                              │   │
│  │   - page_*.jpg                              │   │
│  └────────────────────────────────────────────┘   │
│                                                     │
└─────────────────────────────────────────────────────┘
```

## Network Protocol

### HTTP Endpoints
- **Protocol**: HTTP/1.1
- **Port**: 5000
- **Format**: multipart/form-data
- **CORS**: Enabled (*)

### WebSocket Protocol
- **Protocol**: WebSocket
- **Port**: 5000
- **Transport**: websocket
- **Origin**: * (configurable)

## Technology Stack

### Frontend (Web App)
- Flutter Web
- SocketIO Client
- QR Flutter
- HTTP Client

### Backend
- Flask
- Flask-SocketIO
- Werkzeug (file handling)
- Base64 encoding

### Mobile (Separate)
- Flutter
- Camera
- QR Scanner
- Dio/HTTP Client


