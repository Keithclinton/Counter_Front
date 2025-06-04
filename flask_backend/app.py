from flask import Flask, request, jsonify
from werkzeug.utils import secure_filename
import os
from tensorflow.keras.models import load_model
import tensorflow as tf
import numpy as np
from datetime import datetime
import smtplib
from email.message import EmailMessage
from dotenv import load_dotenv

# Load environment variables from email.env
load_dotenv(dotenv_path='email.env')

app = Flask(__name__)
app.config['UPLOAD_FOLDER'] = 'Uploads/'
app.config['ALLOWED_EXTENSIONS'] = {'png', 'jpg', 'jpeg'}

# Model parameters
latent_dim = 256
sigma = 0.0003
target_size = (224, 224)

# Email configuration
EMAIL_ADDRESS = os.getenv('EMAIL_ADDRESS')
EMAIL_PASSWORD = os.getenv('EMAIL_PASSWORD')
REPORT_EMAIL = 'judekotiano154@gmail.com'

# Debug: Verify credentials
print(f"EMAIL_ADDRESS: {EMAIL_ADDRESS}")
print(f"EMAIL_PASSWORD: {'*' * len(EMAIL_PASSWORD) if EMAIL_PASSWORD else 'None'}")

# Ensure upload folder exists
os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)

# Model path
model_path = '/home/jude/alcohol3.keras'

def load_model_from_path(path):
    try:
        model = load_model(path, compile=False)
        print("Model loaded successfully.")
        return model
    except Exception as e:
        print(f"Could not load model from {path}: {e}")
        return None

model = load_model_from_path(model_path)

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in app.config['ALLOWED_EXTENSIONS']

def load_image(path):
    image = tf.io.read_file(path)
    image = tf.image.decode_jpeg(image, channels=3)
    image = tf.image.adjust_contrast(image, contrast_factor=1.2)
    image = tf.image.resize(image, target_size)
    image = image / 255.0
    return image

def send_email(brand, batch_no, date, confidence):
    try:
        msg = EmailMessage()
        msg.set_content(
            f"Counterfeit Alcohol Detected!\n\n"
            f"Brand: {brand}\n"
            f"Batch No: {batch_no}\n"
            f"Date: {date}\n"
            f"Confidence: {confidence}\n\n"
            f"Please investigate this counterfeit product."
        )
        msg['Subject'] = 'Counterfeit Alcohol Report'
        msg['From'] = EMAIL_ADDRESS
        msg['To'] = REPORT_EMAIL

        with smtplib.SMTP_SSL('smtp.gmail.com', 465) as smtp:
            smtp.login(EMAIL_ADDRESS, EMAIL_PASSWORD)
            smtp.send_message(msg)
        print("Email sent successfully to judekotiano@gmail154.com")
    except Exception as e:
        print(f"Failed to send email: {e}")

@app.route('/')
def home():
    return jsonify({'message': 'Flask server is running. Use /predict for predictions.'}), 200

@app.route('/predict', methods=['POST'])
def predict():
    try:
        if 'image' not in request.files:
            return jsonify({'error': 'No image file provided'}), 400
        
        image_file = request.files['image']
        if not allowed_file(image_file.filename):
            return jsonify({'error': 'Invalid file format. Use PNG, JPG, or JPEG'}), 400

        brand = request.form.get('brand', 'County')
        filename = secure_filename(image_file.filename)
        filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
        image_file.save(filepath)

        image_tensor = load_image(filepath)
        image_tensor = tf.expand_dims(image_tensor, axis=0)
        pseudo_negative = tf.random.normal([1, latent_dim], mean=0.0, stddev=sigma)

        if model is None:
            os.remove(filepath)
            return jsonify({'error': 'Model not loaded'}), 500
        test_probs, _ = model.predict([image_tensor, pseudo_negative])
        score = float(test_probs[0][0])
        threshold = 0.6

        today = datetime.now().strftime("%d %b %Y")
        batch_no = f"{brand[:3].upper()}-2025"
        confidence = f"{score:.2%}"
        is_authentic = score < threshold  # True if counterfeit (score < 0.5)

        if is_authentic:  # Send email for counterfeit detection
            send_email(brand, batch_no, today, confidence)

        result = {
            'is_authentic': is_authentic,
            'brand': brand,
            'batch_no': batch_no,
            'date': today,
            'confidence': confidence
        }

        os.remove(filepath)
        return jsonify(result), 200
    except Exception as e:
        if os.path.exists(filepath):
            os.remove(filepath)
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)