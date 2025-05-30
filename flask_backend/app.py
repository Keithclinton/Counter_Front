from flask import Flask, request, jsonify
from werkzeug.utils import secure_filename
import os

app = Flask(__name__)
app.config['UPLOAD_FOLDER'] = 'uploads/'

# Ensure the upload folder exists
os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)

@app.route('/predict', methods=['POST'])
def predict():
    if 'image' not in request.files:
        return jsonify({'error': 'No image file provided'}), 400
    
    image = request.files['image']
    filename = secure_filename(image.filename)
    filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
    image.save(filepath)
    
    # result = model.predict(filepath)
   
    
    result = {
        'authenticity_score': 0.9,
        'brand': 'Black Eagle',
        'batch_no': 'BEX-2025',
        'date': '30 May 2025',
        'is_authentic': True
    }
    
    return jsonify(result)

if __name__ == '__main__':
    app.run(debug=True)
