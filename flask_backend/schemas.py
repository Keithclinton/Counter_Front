import os
import uuid
import logging
from logging.handlers import RotatingFileHandler
from datetime import datetime, date
from typing import Optional

from fastapi import FastAPI, File, UploadFile, HTTPException, Depends, Query, Form
from fastapi.responses import FileResponse, HTMLResponse
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv

import tensorflow as tf
from tensorflow.keras.models import load_model
import numpy as np

from sqlalchemy import text
from starlette.requests import Request
from starlette.responses import RedirectResponse
from starlette.staticfiles import StaticFiles
from starlette.templating import Jinja2Templates

import uvicorn
from contextlib import asynccontextmanager
from passlib.context import CryptContext

from .database import engine, SessionLocal
from . import schemas, models

# Force TensorFlow to use CPU
os.environ["CUDA_VISIBLE_DEVICES"] = ""

load_dotenv(dotenv_path='.env')

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Application starting up")
    required_env_vars = ['ADMIN_USERNAME', 'ADMIN_PASSWORD_HASH']
    for var in required_env_vars:
        if not os.getenv(var):
            raise ValueError(f"Missing required environment variable: {var}")
    yield
    logger.info("Application shutting down")

app = FastAPI(title="Alcohol Detection API", lifespan=lifespan)

templates = Jinja2Templates(directory="templates")

app.add_middleware(
    CORSMiddleware,
    allow_origins=[os.getenv('ALLOWED_ORIGINS', 'http://localhost:3000')],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

UPLOAD_FOLDER = os.getenv('UPLOAD_FOLDER', 'Uploads/')
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg'}
MAX_CONTENT_LENGTH = int(os.getenv('MAX_CONTENT_LENGTH', 5 * 1024 * 1024))
KEEP_IMAGES = os.getenv('KEEP_IMAGES', 'false').lower() == 'true'
LATENT_DIM = int(os.getenv('LATENT_DIM', 256))
SIGMA = float(os.getenv('SIGMA', 0.0003))
TARGET_SIZE = tuple(map(int, os.getenv('TARGET_SIZE', '224,224').split(',')))
MODEL_PATH = os.getenv('MODEL_PATH', 'alcohol3.keras')
AUTHENTICITY_THRESHOLD = float(os.getenv('AUTHENTICITY_THRESHOLD', 0.4))
ADMIN_USERNAME = os.getenv('ADMIN_USERNAME')
ADMIN_PASSWORD_HASH = os.getenv('ADMIN_PASSWORD_HASH')

os.makedirs(UPLOAD_FOLDER, exist_ok=True)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)
handler = RotatingFileHandler('app.log', maxBytes=1000000, backupCount=5)
handler.setFormatter(logging.Formatter('%(asctime)s - %(levelname)s - %(message)s'))
logger.addHandler(handler)

models.Base.metadata.create_all(bind=engine)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def load_model_from_path(path):
    try:
        model = load_model(path, compile=False)
        logger.info(f"Model loaded from {path}")
        return model
    except Exception as e:
        logger.error(f"Error loading model: {e}")
        raise ValueError(f"Failed to load model: {path}")

model = load_model_from_path(MODEL_PATH)

def allowed_file(filename: str):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

def load_image(path: str):
    try:
        image = tf.io.read_file(path)
        if path.lower().endswith('.png'):
            image = tf.image.decode_png(image, channels=3)
        else:
            image = tf.image.decode_jpeg(image, channels=3)
        image = tf.image.adjust_contrast(image, contrast_factor=1.2)
        image = tf.image.resize(image, TARGET_SIZE)
        return image / 255.0
    except Exception as e:
        logger.error(f"Image load error: {e}")
        raise HTTPException(status_code=400, detail="Invalid image format")

def run_prediction(image_tensor):
    try:
        pseudo_negative = tf.random.normal([1, LATENT_DIM], mean=0.0, stddev=SIGMA)
        test_probs, _ = model.predict([tf.expand_dims(image_tensor, axis=0), pseudo_negative], verbose=0)
        return float(test_probs[0][0])
    except Exception as e:
        logger.error(f"Prediction error: {e}")
        raise HTTPException(status_code=500, detail="Prediction failed")

@app.get("/")
async def home():
    return {"message": "Welcome to the Alcohol Detection API"}

@app.get("/health")
async def health(db: SessionLocal = Depends(get_db)):
    try:
        db.execute(text('SELECT 1'))
        return {
            "status": "healthy",
            "model_loaded": model is not None,
            "database_connected": True
        }
    except Exception as e:
        logger.error(f"DB health check failed: {e}")
        return {
            "status": "unhealthy",
            "model_loaded": model is not None,
            "database_connected": False
        }

@app.get("/predict/health")
async def predict_health():
    if model is not None:
        return {
            "status": "healthy",
            "model_loaded": True,
            "message": "Prediction endpoint is healthy"
        }
    raise HTTPException(status_code=500, detail="Model not loaded")

@app.post("/predict", response_model=schemas.PredictResponse)
async def predict(
    image: UploadFile = File(...),
    data: schemas.PredictRequest = Depends(),
    db: SessionLocal = Depends(get_db)
):
    filepath: Optional[str] = None
    try:
        if not allowed_file(image.filename):
            raise HTTPException(status_code=400, detail="Invalid file type")

        filename: str = f"{uuid.uuid4().hex}_{image.filename.lower()}"
        filepath = os.path.join(UPLOAD_FOLDER, filename)
        content = await image.read()
        if len(content) > MAX_CONTENT_LENGTH:
            raise HTTPException(status_code=400, detail="File too large")
        with open(filepath, mode="wb") as f:
            f.write(content)

        image_tensor = load_image(filepath)
        if model is None:
            raise HTTPException(status_code=500, detail="Model not loaded")

        score = run_prediction(image_tensor)
        today = date.today()
        batch_no = f"{data.brand[:3].upper()}-{datetime.now().year}-{uuid.uuid4().hex[:4]}"
        confidence = float(score)
        is_authentic = score >= AUTHENTICITY_THRESHOLD

        scan = models.ScanResult(
            brand=data.brand,
            batch_no=batch_no,
            date=today,
            confidence=confidence,
            is_authentic=is_authentic,
            latitude=float(data.latitude) if data.latitude != "Unknown" else None,
            longitude=float(data.longitude) if data.longitude != "Unknown" else None,
            image_url=filename
        )
        db.add(scan)
        db.commit()
        db.refresh(scan)

        if not KEEP_IMAGES and filepath and os.path.exists(filepath):
            os.remove(filepath)

        return {
            "id": scan.id,
            "is_authentic": is_authentic,
            "brand": data.brand,
            "batch_no": batch_no,
            "date": f"{today:%Y-%m-%d}",
            "confidence": f"{confidence:.2%}",
            "latitude": data.latitude,
            "longitude": data.longitude,
            "image_url": filename,
            "message": "Authentic" if is_authentic else "Counterfeit detected"
        }

    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        if filepath and os.path.exists(filepath):
            os.remove(filepath)
        logger.error(f"Prediction error: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Server error: {str(e)}")

@app.get("/api/locations")
async def get_locations(
    page: int = Query(1, ge=1),
    per_page: int = Query(100, le=500),
    db: SessionLocal = Depends(get_db)
):
    try:
        scans = (
            db.query(models.ScanResult)
            .offset((page - 1) * per_page)
            .limit(per_page)
            .all()
        )
        locations = [
            {
                "id": scan.id,
                "lat": scan.latitude if scan.latitude is not None else -1.2284,
                "lng": scan.longitude if scan.longitude is not None else 36.8722,
                "is_authentic": scan.is_authentic,
                "brand": scan.brand,
                "batch_no": scan.batch_no,
                "confidence": f"{scan.confidence:.2%}",
                "date": f"{scan.date:%Y-%m-%d}",
                "image_url": scan.image_url
            }
            for scan in scans
        ]
        return {"locations": locations}
    except Exception as e:
        logger.error(f"Location error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/Uploads/{filename}")
async def uploaded_file(filename: str):
    file_path = os.path.join(UPLOAD_FOLDER, filename)
    if not os.path.exists(file_path):
        raise HTTPException(status_code=404, detail="File not found")
    return FileResponse(file_path)

@app.get("/admin/login", response_class=HTMLResponse)
async def admin_login_get(request: Request):
    return templates.TemplateResponse("login.html", {"request": request})

@app.post("/admin/login", response_class=HTMLResponse)
async def admin_login_post(
    request: Request,
    username: str = Form(...),
    password: str = Form(...)
):
    if username == ADMIN_USERNAME and pwd_context.verify(password, ADMIN_PASSWORD_HASH):
        response = RedirectResponse(url="/admin/map", status_code=303)
        response.set_cookie(
            key="admin_authenticated",
            value="true",
            httponly=True,
            secure=True,
            samesite="strict"
        )
        return response
    return templates.TemplateResponse(
        "login.html", {"request": request, "error": "Invalid credentials"}
    )

@app.get("/admin/logout")
async def admin_logout():
    response = RedirectResponse(url="/admin/login", status_code=303)
    response.delete_cookie("admin_authenticated")
    return response

@app.get("/admin/map", response_class=HTMLResponse)
async def admin_map(request: Request):
    if request.cookies.get("admin_authenticated") != "true":
        return RedirectResponse(url="/admin/login", status_code=303)
    return templates.TemplateResponse("admin_dashboard.html", {"request": request})

if __name__ == "__main__":
    uvicorn.run(app, host="192.168.100.15", port=5000)
