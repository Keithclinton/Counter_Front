from flask import Flask, request, jsonify, send_from_directory, render_template, session, redirect, url_for
from werkzeug.utils import secure_filename
import os
import uuid
import logging
from logging.handlers import RotatingFileHandler
from datetime import datetime
from dotenv import load_dotenv
from flask_sqlalchemy import SQLAlchemy
from flask_cors import CORS
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
import tensorflow as tf
from tensorflow.keras.models import load_model
import numpy as np

# Load environment variables
load_dotenv(dotenv_path='email.env')

# Initialize Flask app
app = Flask(__name__)
app.secret_key = os.getenv('SECRET_KEY', 'super-secret-key')  # Session key
CORS(app, resources={r"/*": {"origins": "*"}})
limiter = Limiter(get_remote_address, app=app, default_limits=["10/minute"])

# Configuration
app.config['UPLOAD_FOLDER'] = os.getenv('UPLOAD_FOLDER', 'Uploads/')
app.config['ALLOWED_EXTENSIONS'] = {'png', 'jpg', 'jpeg'}
app.config['SQLALCHEMY_DATABASE_URI'] = os.getenv('DATABASE_URI', 'sqlite:///results.db')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['MAX_CONTENT_LENGTH'] = int(os.getenv('MAX_CONTENT_LENGTH', 5 * 1024 * 1024))
app.config['KEEP_IMAGES'] = os.getenv('KEEP_IMAGES', 'false').lower() == 'true'

# Ensure upload folder exists
os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)

# Model configuration
latent_dim = int(os.getenv('LATENT_DIM', 256))
sigma = float(os.getenv('SIGMA', 0.0003))
target_size = tuple(map(int, os.getenv('TARGET_SIZE', '224,224').split(',')))
model_path = os.getenv('MODEL_PATH', 'alcohol3.keras')
authenticity_threshold = float(os.getenv('AUTHENTICITY_THRESHOLD', 0.6))

# Logging setup
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)
handler = RotatingFileHandler('app.log', maxBytes=1000000, backupCount=5)
handler.setFormatter(logging.Formatter('%(asctime)s - %(levelname)s - %(message)s'))
logger.addHandler(handler)

# Load model
def load_model_from_path(path):
    try:
        model = load_model(path, compile=False)
        logger.info(f"Model loaded from {path}")
        return model
    except Exception as e:
        logger.error(f"Error loading model: {e}")
        return None

model = load_model_from_path(model_path)

# Initialize DB
db = SQLAlchemy(app)
class ScanResult(db.Model):
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

with app.app_context():
    db.create_all()

# Utilities
def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in app.config['ALLOWED_EXTENSIONS']

def is_valid_coordinate(lat, lon):
    try:
        lat, lon = float(lat), float(lon)
        return -90 <= lat <= 90 and -180 <= lon <= 180
    except:
        return False

def load_image(path):
    try:
        image = tf.io.read_file(path)
        image = tf.image.decode_jpeg(image, channels=3)
        image = tf.image.adjust_contrast(image, contrast_factor=1.2)
        image = tf.image.resize(image, target_size)
        return image / 255.0
    except Exception as e:
        logger.error(f"Image load error: {e}")
        raise

def run_prediction(image_tensor):
    pseudo_negative = tf.random.normal([1, latent_dim], mean=0.0, stddev=sigma)
    test_probs, _ = model.predict([tf.expand_dims(image_tensor, axis=0), pseudo_negative], verbose=0)
    return float(test_probs[0][0])

def save_to_cloud_storage(file, filename):
    return f"/Uploads/{filename}"

# Routes
@app.route('/')
def home():
    return jsonify({'message': 'Welcome to the Alcohol Detection API'}), 200

@app.route('/health')
def health():
    try:
        db.session.execute('SELECT 1')
        db_status = True
    except Exception as e:
        logger.error(f"DB health check failed: {e}")
        db_status = False
    return jsonify({
        'model_loaded': model is not None,
        'database_connected': db_status
    }), 200 if db_status else 500

@app.route('/predict', methods=['POST'])
@limiter.limit("10/minute")
def predict():
    filepath = None
    try:
        if 'image' not in request.files:
            return jsonify({'error': 'Image file missing'}), 400

        image_file = request.files['image']
        if not allowed_file(image_file.filename):
            return jsonify({'error': 'Invalid file type'}), 400

        brand = request.form.get('brand', 'County')
        latitude = request.form.get('latitude', 'Unknown')
        longitude = request.form.get('longitude', 'Unknown')

        if latitude != 'Unknown' and longitude != 'Unknown' and not is_valid_coordinate(latitude, longitude):
            return jsonify({'error': 'Invalid coordinates'}), 400

        filename = f"{uuid.uuid4().hex}_{secure_filename(image_file.filename)}"
        filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
        image_file.save(filepath)

        image_url = save_to_cloud_storage(image_file, filename)
        image_tensor = load_image(filepath)


        if model is None:

            return jsonify({'error': 'Model not loaded'}), 500


        score = run_prediction(image_tensor)
        today = datetime.now().strftime("%Y-%m-%d")
        batch_no = f"{brand[:3].upper()}-{datetime.now().year}"
        confidence = f"{score:.2%}"
        is_authentic = score >= authenticity_threshold

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

        if not app.config['KEEP_IMAGES'] and filepath and os.path.exists(filepath):
            os.remove(filepath)

        return jsonify({
            'id': scan.id,
            'isAuthentic': is_authentic,
            'brand': brand,
            'batchNo': batch_no,
            'date': today,
            'confidence': confidence,
            'latitude': latitude,
            'longitude': longitude,
            'imageUrl': image_url,
            'message': "Authentic" if is_authentic else "Counterfeit detected"
        }), 200

    except Exception as e:
        db.session.rollback()
        if filepath and os.path.exists(filepath):
            os.remove(filepath)
        logger.error(f"Prediction error: {e}", exc_info=True)
        return jsonify({'error': 'Server error'}), 500

@app.route('/api/locations', methods=['GET'])
def get_locations():
    try:
        page = request.args.get('page', 1, type=int)
        per_page = request.args.get('per_page', 100, type=int)
        scans = ScanResult.query.paginate(page=page, per_page=per_page, error_out=False).items

        locations = []
        for scan in scans:
            try:
                lat = float(scan.latitude) if scan.latitude != 'Unknown' else -1.2284
                lng = float(scan.longitude) if scan.longitude != 'Unknown' else 36.8722
            except:
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
        logger.error(f"Location error: {e}", exc_info=True)
        return jsonify({'error': 'Server error'}), 500

@app.route('/Uploads/<filename>')
def uploaded_file(filename):
    try:
        return send_from_directory(os.path.abspath(app.config['UPLOAD_FOLDER']), filename)
    except Exception as e:
        logger.error(f"File serve error: {e}")
        return jsonify({'error': 'File not found'}), 404


@app.route('/admin/login', methods=['GET', 'POST'])
def admin_login():
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        if username == os.getenv('ADMIN_USERNAME') and password == os.getenv('ADMIN_PASSWORD'):
            session['admin_logged_in'] = True
            return redirect(url_for('admin_map'))
        else:
            return render_template('login.html', error="Invalid credentials")
    return render_template('login.html')

@app.route('/admin/logout')
def admin_logout():
    session.pop('admin_logged_in', None)
    return redirect(url_for('admin_login'))

@app.route('/admin/map')
def admin_map():
    if not session.get('admin_logged_in'):
        return redirect(url_for('admin_login'))
    return send_from_directory('templates', 'admin_dashboard.html')


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.getenv('PORT', 5000)), debug=os.getenv('FLASK_ENV', 'development') == 'development')
