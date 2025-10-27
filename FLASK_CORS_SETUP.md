# Flask Backend CORS Setup

## Problem
The upload is failing with "Failed to fetch" error. This is typically a **CORS (Cross-Origin Resource Sharing)** issue.

## Solution: Update Your Flask Backend

Add these headers to your Flask app:

```python
from flask import Flask, request
from flask_cors import CORS
from flask_socketio import SocketIO
from werkzeug.utils import secure_filename
import os
import base64

app = Flask(__name__)

# IMPORTANT: Add CORS support
CORS(app, origins="*")  # Allow all origins during development

socketio = SocketIO(
    app, 
    cors_allowed_origins="*",  # This is the key line
    logger=True,
    engineio_logger=True
)

UPLOAD_DIR = "uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)

# Handle preflight requests
@app.after_request
def after_request(response):
    response.headers.add('Access-Control-Allow-Origin', '*')
    response.headers.add('Access-Control-Allow-Headers', 'Content-Type,Authorization,ngrok-skip-browser-warning')
    response.headers.add('Access-Control-Allow-Methods', 'GET,PUT,POST,DELETE,OPTIONS')
    return response

@app.route('/upload_docs', methods=['POST', 'OPTIONS'])
def upload_docs():
    """Called by web app to upload question paper & answer key."""
    if request.method == 'OPTIONS':
        return {}, 200
    
    session_id = request.form.get('session_id')
    question_file = request.files['question']
    answer_file = request.files['answer']

    folder_path = os.path.join(UPLOAD_DIR, session_id)
    os.makedirs(folder_path, exist_ok=True)

    question_path = os.path.join(folder_path, secure_filename("question.pdf"))
    answer_path = os.path.join(folder_path, secure_filename("answer.pdf"))
    question_file.save(question_path)
    answer_file.save(answer_path)

    print(f"[WEB] Uploaded QP + Key for session {session_id}")
    return {"status": "success", "session_id": session_id}

@app.route('/upload_answer', methods=['POST', 'OPTIONS'])
def upload_answer():
    """Called by mobile app after scanning QR and capturing image."""
    if request.method == 'OPTIONS':
        return {}, 200
    
    session_id = request.form.get('session_id')
    page_number = request.form.get('page_number')
    image_file = request.files['image']

    folder_path = os.path.join(UPLOAD_DIR, session_id)
    os.makedirs(folder_path, exist_ok=True)
    filename = secure_filename(f"page_{page_number}.jpg")
    file_path = os.path.join(folder_path, filename)
    image_file.save(file_path)

    # Convert image to Base64
    with open(file_path, "rb") as f:
        b64_img = base64.b64encode(f.read()).decode('utf-8')

    # Emit event to web app
    socketio.emit('new_upload', {
        'session_id': session_id,
        'page': page_number,
        'img': b64_img
    }, room=session_id)

    print(f"[MOBILE] Uploaded Page {page_number} for session {session_id}")
    return {"status": "success", "message": f"Page {page_number} uploaded"}

@socketio.on('join')
def handle_join(data):
    session_id = data.get('session_id')
    join_room(session_id)
    print(f"[WEB] Joined session {session_id}")
    emit('joined', {'message': f'Joined room {session_id}'})

if __name__ == '__main__':
    print("✅ Flask backend running on http://0.0.0.0:5000")
    socketio.run(app, host='0.0.0.0', port=5000, debug=True)
```

## Key Changes:

1. **Added CORS**: `CORS(app, origins="*")` allows all origins
2. **SocketIO CORS**: Added `cors_allowed_origins="*"` to SocketIO
3. **Handle OPTIONS**: Add OPTIONS method handlers for preflight requests
4. **After Request**: Add headers to every response

## Install flask-cors if not installed:

```bash
pip install flask-cors
```

## Test Your Backend:

```bash
curl -X OPTIONS https://7523c621be15.ngrok-free.app/upload_docs \
  -H "Origin: https://7523c621be15.ngrok-free.app" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: Content-Type"
```

You should get 200 status with CORS headers in the response.

## Ngrok Issues:

If ngrok is blocking requests:
1. Visit the ngrok URL in browser first and accept the warning
2. The app now sends `ngrok-skip-browser-warning` header
3. Make sure ngrok tunnel is active

## Quick Fix Command:

Restart your Flask backend after making these changes.

