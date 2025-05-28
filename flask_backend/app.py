from flask import Flask, request, jsonify
from flask_cors import CORS
import base64

app = Flask(__name__)
CORS(app)

@app.route('/predict', methods=['POST'])
def predict():
    data = request.get_json()
    image_b64 = data.get('image')

    if image_b64:
        # In production, decode and process the image here
        return jsonify({"result": "This looks real ✅"})
    else:
        return jsonify({"error": "No image provided"}), 400

if __name__ == '__main__':
    app.run(debug=True)
