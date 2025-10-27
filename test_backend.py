"""
Test script to simulate mobile app uploads
Run this to test the web app's real-time display functionality
"""
import requests
import base64
from io import BytesIO
from PIL import Image

# Configuration
SERVER_URL = "http://localhost:5000"
SESSION_ID = "test-session-123"

def create_test_image():
    """Create a simple test image"""
    # Create a simple image with PIL
    img = Image.new('RGB', (800, 600), color='white')
    
    # Add some text or shapes for testing
    from PIL import ImageDraw, ImageFont
    draw = ImageDraw.Draw(img)
    
    # Draw a simple border
    draw.rectangle([50, 50, 750, 550], outline='black', width=3)
    
    # Draw some lines (simulating answer sheet)
    for i in range(20):
        y = 100 + i * 25
        draw.line([100, y, 700, y], fill='gray', width=1)
    
    # Convert to bytes
    img_buffer = BytesIO()
    img.save(img_buffer, format='JPEG')
    img_bytes = img_buffer.getvalue()
    
    return base64.b64encode(img_bytes).decode('utf-8')

def upload_test_image(session_id, page_number):
    """Upload a test image to simulate mobile app"""
    base64_img = create_test_image()
    
    # Note: This is a direct HTTP upload simulation
    # In the real Flask backend, you would use:
    # socketio.emit('new_upload', {...})
    
    print(f"Uploading page {page_number} for session {session_id}")
    print(f"Base64 length: {len(base64_img)} characters")
    
    # In a real scenario, you would send this via SocketIO from the backend
    # For testing, you can manually emit the event in your Flask terminal:
    # socketio.emit('new_upload', {
    #     'session_id': session_id,
    #     'page': page_number,
    #     'img': base64_img
    # }, room=session_id)
    
    return base64_img

if __name__ == "__main__":
    print("=" * 60)
    print("Backend Test Script")
    print("=" * 60)
    print(f"Server: {SERVER_URL}")
    print(f"Session ID: {SESSION_ID}")
    print("\nThis script creates test images.")
    print("To test the web app:")
    print("1. Start your Flask backend")
    print("2. Open the web app in browser")
    print("3. Upload files and get session_id")
    print("4. In Flask terminal, run:")
    print(f"   socketio.emit('new_upload', {{")
    print(f"       'session_id': 'your-session-id',")
    print(f"       'page': '1',")
    print(f"       'img': '{upload_test_image(SESSION_ID, '1')[:50]}...'")
    print(f"   }}, room='your-session-id')")
    print("=" * 60)


