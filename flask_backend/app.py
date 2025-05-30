from flask import Flask, request, jsonify
from werkzeug.utils import secure_filename
import os
from tensorflow.keras.models import load_model
import tensorflow as tf
import numpy as np

app = Flask(__name__)
app.config['UPLOAD_FOLDER'] = 'uploads/'
model_path = '/home/jude/alcohol3.keras'

os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)

def load_model_from_path(path):
    try:
        model = load_model(path)
        print("Model loaded successfully.")
        return model
    except Exception as e:
        print(f"Could not load model from {path}: {e}")
        return None

model = load_model_from_path(model_path)

def load_image(path):
    image = tf.io.read_file(path)
    image = tf.image.decode_jpeg(image, channels=3)
    image = tf.image.resize(image, [224, 224])
    image = image / 255.0
    return image

@app.route('/predict', methods=['POST'])
def predict():
    if 'image' not in request.files:
        return jsonify({'error': 'No image file provided'}), 400
    
    image_file = request.files['image']
    filename = secure_filename(image_file.filename)
    filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
    image_file.save(filepath)

    image_tensor = load_image(filepath)
    image_tensor = tf.expand_dims(image_tensor, axis=0)  

    prediction = model.predict(image_tensor)
    score = float(prediction[0][0])  

    result = {
        'authenticity_score': round(score, 2),
        'brand': 'Black Eagle',
        'batch_no': 'BEX-2025',
        'date': '30 May 2025',
        'is_authentic': score > 0.5
    }
    
    return jsonify(result)

if __name__ == '__main__':
    app.run(debug=True)
