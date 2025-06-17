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

os.environ['TF_CPP_MIN_LOG_LEVEL'] = '2'

# Load environment variables
load_dotenv(dotenv_path='email.env')

app = Flask(__name__)
app.config['UPLOAD_FOLDER'] = 'Uploads/'
app.config['ALLOWED_EXTENSIONS'] = {'png', 'jpg', 'jpeg'}
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///results.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['MAX_CONTENT_LENGTH'] = 5 * 1024 * 1024  # 5MB file size limit

# Ensure upload folder exists
os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)

# model configuration
latent_dim = 256
sigma = 0.0003
target_size = (224, 224)
model_path = '/home/jude/alcohol3.keras'

# Load model
def load_model_from_path(path):
    try:
        model = load_model(path, compile=False)
        print("Model loaded successfully.")
        return model
    except Exception as e:
        print(f"Could not load model from {path}: {e}")
        return None

model = load_model_from_path(model_path)

# Initialize database
db = SQLAlchemy(app)

class ScanResult(db.Model):
    __tablename__ = 'scan_results'
    id = db.Column(db.Integer, primary_key=True)
    brand = db.Column(db.String(80), nullable=False)
    batch_no = db.Column(db.String(80), nullable=False)
    date = db.Column(db.String(20), nullable=False)
    confidence = db.Column(db.String(20), nullable=False)
    is_authentic = db.Column(db.Boolean, nullable=False)
    latitude = db.Column(db.String(20))
    longitude = db.Column(db.String(20))
    image_url = db.Column(db.String(200))
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)

    def __repr__(self):
        return f'<ScanResult {self.brand} {self.batch_no}>'

with app.app_context():
    db.create_all()


def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in app.config['ALLOWED_EXTENSIONS']

def load_image(path):
    image = tf.io.read_file(path)
    image = tf.image.decode_jpeg(image, channels=3)
    image = tf.image.adjust_contrast(image, contrast_factor=1.2)
    image = tf.image.resize(image, target_size)
    image = image / 255.0
    return image

def run_prediction(image_tensor):
    pseudo_negative = tf.random.normal([1, latent_dim], mean=0.0, stddev=sigma)
    test_probs, _ = model.predict([image_tensor, pseudo_negative])
    return float(test_probs[0][0])


@app.before_request
def require_api_key():
    if request.endpoint == 'predict' and request.headers.get('x-api-key') != os.getenv('API_KEY'):
        return jsonify({'error': 'Unauthorized'}), 401


@app.route('/')
def home():
    return jsonify({'message': 'Flask server is running. Use /predict for predictions.'}), 200

@app.route('/predict', methods=['POST'])
def predict():
    filepath = None
    try:
        if 'image' not in request.files:
            return jsonify({'error': 'No image file provided'}), 400

        image_file = request.files['image']
        if not allowed_file(image_file.filename):
            return jsonify({'error': 'Invalid file format. Use PNG, JPG, or JPEG'}), 400

        brand = request.form.get('brand', 'County')
        latitude = request.form.get('latitude', 'Unknown')
        longitude = request.form.get('longitude', 'Unknown')

        filename = f"{uuid.uuid4().hex}_{secure_filename(image_file.filename)}"
        filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
        image_file.save(filepath)
        image_url = f"/uploads/{filename}"

        image_tensor = tf.expand_dims(load_image(filepath), axis=0)

        if model is None:
            os.remove(filepath)
            return jsonify({'error': 'Model not loaded'}), 500

        score = run_prediction(image_tensor)
        threshold = 0.6

        today = datetime.now().strftime("%Y-%m-%d")
        batch_no = f"{brand[:3].upper()}-{datetime.now().year}"
        confidence = f"{score:.2%}"
        is_authentic = score >= threshold

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
            'id': scan.id,
            'isAuthentic': is_authentic,
            'brand': brand,
            'batchNo': batch_no,
            'date': today,
            'confidence': confidence,
            'latitude': latitude,
            'longitude': longitude,
            'imageUrl': image_url,
            'message': "Product is authentic." if is_authentic else "Counterfeit detected."
        }

        os.remove(filepath)
        return jsonify(result), 200

    except Exception as e:
        if filepath and os.path.exists(filepath):
            os.remove(filepath)
        db.session.rollback()
        app.logger.error(f"Error in prediction: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/api/locations', methods=['GET'])
def get_locations():
    try:
        scans = ScanResult.query.all()
        locations = []
        for scan in scans:
            try:
                lat = float(scan.latitude)
                lng = float(scan.longitude)
            except (ValueError, TypeError):
                lat, lng = -1.2284, 36.8722
            locations.append({
                'lat': lat,
                'lng': lng,
                'isAuthentic': scan.is_authentic,
                'brand': scan.brand,
                'batchNo': scan.batch_no,
                'confidence': scan.confidence,
                'date': scan.date,
                'imageUrl': scan.image_url
            })
        return jsonify({'locations': locations}), 200
    except Exception as e:
        app.logger.error(f"Error fetching locations: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/uploads/<filename>')
def uploaded_file(filename):
    return send_from_directory(os.path.abspath(app.config['UPLOAD_FOLDER']), filename)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
