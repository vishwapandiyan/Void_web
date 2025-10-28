from flask import Flask, request
from flask_socketio import SocketIO, emit, join_room
from flask_cors import CORS
from werkzeug.utils import secure_filename
import os
import base64

app = Flask(__name__)

# Add CORS support for HTTP requests
CORS(app, resources={r"/*": {"origins": "*"}})

# Configure SocketIO with CORS and logging
socketio = SocketIO(
    app, 
    cors_allowed_origins="*",
    logger=True,
    engineio_logger=True
)

UPLOAD_DIR = "uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)

# -------------------------------
# 🤖 AI Backend Placeholder Function
# -------------------------------
def call_ai_backend(image_path, session_id, page_number):
    """
    AI Backend Placeholder - Simulates evaluation of scanned answer sheet.
    TODO: Integrate with actual AI model for answer evaluation.
    
    Args:
        image_path: Path to the scanned image
        session_id: Session identifier
        page_number: Page number of the answer sheet
    
    Returns:
        dict: Mock evaluation results
    """
    # TODO: Replace with actual AI model integration
    # For now, return mock evaluation data
    
    # Simulate processing time
    import time
    time.sleep(0.5)  # Simulate AI processing
    
    # Mock evaluation data
    mock_evaluation = {
        "score": 85.5,
        "total_marks": 100,
        "correct_answers": 17,
        "total_questions": 20,
        "detailed_results": [
            {"question": 1, "correct": True, "marks": 5},
            {"question": 2, "correct": True, "marks": 5},
            {"question": 3, "correct": False, "marks": 0},
            {"question": 4, "correct": True, "marks": 5},
            {"question": 5, "correct": True, "marks": 5},
        ],
        "status": "completed"
    }
    
    print(f"[AI] ✅ Evaluated page {page_number} - Score: {mock_evaluation['score']}/100")
    return mock_evaluation

# Add CORS headers to all responses
@app.after_request
def after_request(response):
    response.headers.add('Access-Control-Allow-Origin', '*')
    response.headers.add('Access-Control-Allow-Headers', 'Content-Type, Authorization, ngrok-skip-browser-warning')
    response.headers.add('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
    return response

# -------------------------------
# 📲 Route: Web uploads Question + Answer Key
# -------------------------------
@app.route('/upload_docs', methods=['POST', 'OPTIONS'])
def upload_docs():
    """Called by web app to upload question paper & answer key."""
    # Handle preflight OPTIONS request
    if request.method == 'OPTIONS':
        return {}, 200
    
    try:
        # Validate session_id
        session_id = request.form.get('session_id')
        if not session_id:
            print("[WEB] ❌ Missing session_id")
            return {"status": "error", "message": "Missing session_id"}, 400

        # Validate files
        if 'question' not in request.files or 'answer' not in request.files:
            print("[WEB] ❌ Missing files (question or answer)")
            return {"status": "error", "message": "Missing question or answer files"}, 400

        question_file = request.files['question']
        answer_file = request.files['answer']

        # Check if files are empty
        if question_file.filename == '' or answer_file.filename == '':
            print("[WEB] ❌ Empty files")
            return {"status": "error", "message": "Empty files"}, 400

        folder_path = os.path.join(UPLOAD_DIR, session_id)
        os.makedirs(folder_path, exist_ok=True)

        question_path = os.path.join(folder_path, secure_filename("question.pdf"))
        answer_path = os.path.join(folder_path, secure_filename("answer.pdf"))
        question_file.save(question_path)
        answer_file.save(answer_path)

        print(f"[WEB] ✅ Uploaded QP + Key for session {session_id}")
        return {"status": "success", "session_id": session_id}
    except Exception as e:
        print(f"[WEB] ❌ Upload error: {e}")
        return {"status": "error", "message": str(e)}, 500

# -------------------------------
# 📱 Route: Mobile uploads captured answer sheet
# -------------------------------
@app.route('/upload_answer', methods=['POST', 'OPTIONS'])
def upload_answer():
    """Called by mobile app after scanning QR and capturing image."""
    # Handle preflight OPTIONS request
    if request.method == 'OPTIONS':
        return {}, 200
    
    try:
        # Validate session_id
        session_id = request.form.get('session_id')
        if not session_id:
            print("[MOBILE] ❌ Missing session_id")
            return {"status": "error", "message": "Missing session_id"}, 400

        # Validate page_number
        page_number = request.form.get('page_number')
        if not page_number:
            print("[MOBILE] ❌ Missing page_number")
            return {"status": "error", "message": "Missing page_number"}, 400

        # Validate image file
        if 'image' not in request.files:
            print("[MOBILE] ❌ Missing image file")
            return {"status": "error", "message": "Missing image file"}, 400

        image_file = request.files['image']
        if image_file.filename == '':
            print("[MOBILE] ❌ Empty image file")
            return {"status": "error", "message": "Empty image file"}, 400

        folder_path = os.path.join(UPLOAD_DIR, session_id)
        os.makedirs(folder_path, exist_ok=True)
        filename = secure_filename(f"page_{page_number}.jpg")
        file_path = os.path.join(folder_path, filename)
        image_file.save(file_path)

        # Convert image to Base64
        with open(file_path, "rb") as f:
            b64_img = base64.b64encode(f.read()).decode('utf-8')

        # Emit event to web app with image
        socketio.emit('new_upload', {
            'session_id': session_id,
            'page': page_number,
            'img': b64_img
        }, room=session_id)

        # Call AI backend for evaluation
        print(f"[AI] 🔄 Processing page {page_number} for session {session_id}")
        evaluation_result = call_ai_backend(file_path, session_id, page_number)
        
        # Emit evaluation result to web app
        socketio.emit('evaluation_result', {
            'session_id': session_id,
            'page': page_number,
            'evaluation': evaluation_result
        }, room=session_id)

        print(f"[MOBILE] ✅ Uploaded Page {page_number} for session {session_id}")
        return {"status": "success", "message": f"Page {page_number} uploaded"}
    except Exception as e:
        print(f"[MOBILE] ❌ Upload error: {e}")
        return {"status": "error", "message": str(e)}, 500

# -------------------------------
# 🌐 Socket: Web joins session
# -------------------------------
@socketio.on('join')
def handle_join(data):
    session_id = data.get('session_id')
    join_room(session_id)
    print(f"[WEB] ✅ Connected to session {session_id}")
    emit('joined', {'message': f'Joined room {session_id}'})

# -------------------------------
# 🚀 Run Flask Server
# -------------------------------
if __name__ == '__main__':
    print("Flask backend running on http://0.0.0.0:5000")
    socketio.run(app, host='0.0.0.0', port=5001, debug=True, allow_unsafe_werkzeug=True)