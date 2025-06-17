from flask import Flask, request, jsonify, send_from_directory
from werkzeug.utils import secure_filename
import os
from tensorflow.keras.models import load_model
import tensorflow as tf
import numpy as np
from datetime import datetime
from dotenv import load_dotenv
from flask_sqlalchemy import SQLAlchemy
import uuid

# Load environment variables from email.env (optional, can be removed if not used)
load_dotenv(dotenv_path='email.env')

app = Flask(__name__)
app.config['UPLOAD_FOLDER'] = 'Uploads/'
app.config['ALLOWED_EXTENSIONS'] = {'png', 'jpg', 'jpeg'}
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///scans.db'

# Model parameters
latent_dim = 256
sigma = 0.0003
target_size = (224, 224)

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
db = SQLAlchemy(app)

class ScanResult(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    brand = db.Column(db.String(80))
    batch_no = db.Column(db.String(80))
    date = db.Column(db.String(80))
    confidence = db.Column(db.String(20))
    is_authentic = db.Column(db.Boolean)
    latitude = db.Column(db.String(20))
    longitude = db.Column(db.String(20))
    image_url = db.Column(db.String(200))

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in app.config['ALLOWED_EXTENSIONS']

def load_image(path):
    image = tf.io.read_file(path)
    image = tf.image.decode_jpeg(image, channels=3)
    image = tf.image.adjust_contrast(image, contrast_factor=1.2)
    image = tf.image.resize(image, target_size)
    image = image / 255.0
    return image

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
        latitude = float(request.form.get('latitude', 0))
        longitude = float(request.form.get('longitude', 0))

        filename = f"{uuid.uuid4().hex}_{secure_filename(image_file.filename)}"
        filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
        image_file.save(filepath)
        image_url = f"/uploads/{filename}"

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

        # Save scan result to database
        scan = ScanResult(
            brand=brand,
            batch_no=batch_no,
            date=today,
            confidence=confidence,
            is_authentic=is_authentic,
            latitude=latitude,
            longitude=longitude,
            image_url=image_url
        )
        db.session.add(scan)
        db.session.commit()

        result = {
            'is_authentic': is_authentic,
            'brand': brand,
            'batch_no': batch_no,
            'date': today,
            'confidence': confidence,
            'latitude': latitude,
            'longitude': longitude,
            'image_url': image_url,
            'message': "Product is authentic." if not is_authentic else "Counterfeit detected."
        }

        os.remove(filepath)
        return jsonify(result), 200
    except Exception as e:
        if os.path.exists(filepath):
            os.remove(filepath)
        return jsonify({'error': str(e)}), 500

@app.route('/api/locations')
def get_locations():
    scans = ScanResult.query.all()
    data = []
    for scan in scans:
        data.append({
            'latitude': scan.latitude,
            'longitude': scan.longitude,
            'result': "Real" if not scan.is_authentic else "Fake",
            'timestamp': scan.date,
            'brand': scan.brand,
            'batch_no': scan.batch_no,
            'confidence': scan.confidence,
            'image_url': scan.image_url
        })
    return jsonify(data)

@app.route('/uploads/<filename>')
def uploaded_file(filename):
    return send_from_directory(app.config['UPLOAD_FOLDER'], filename)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
