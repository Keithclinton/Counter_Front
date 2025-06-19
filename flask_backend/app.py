import os
import uuid
import logging
from logging.handlers import RotatingFileHandler
from datetime import datetime
from fastapi import FastAPI, File, UploadFile, Form, HTTPException, Depends, Query
from fastapi.responses import FileResponse, HTMLResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from sqlalchemy import create_engine, Column, Integer, String, Boolean, DateTime, text
from sqlalchemy.orm import sessionmaker, Session, declarative_base
from dotenv import load_dotenv
import tensorflow as tf
from tensorflow.keras.models import load_model
import numpy as np
from starlette.requests import Request
from starlette.responses import RedirectResponse
from starlette.staticfiles import StaticFiles
from starlette.templating import Jinja2Templates
import uvicorn
from contextlib import asynccontextmanager

os.environ["CUDA_VISIBLE_DEVICES"] = ""  # Force TensorFlow to use CPU

# Load environment variables
load_dotenv(dotenv_path='.env')

# Initialize FastAPI app with lifespan
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup code
    logger.info("Application starting up")
    yield
    # Shutdown code
    logger.info("Application shutting down")

app = FastAPI(title="Alcohol Detection API", lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configuration
UPLOAD_FOLDER = os.getenv('UPLOAD_FOLDER', 'Uploads/')
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg'}
DATABASE_URI = os.getenv('DATABASE_URI', 'sqlite:///results.db')
MAX_CONTENT_LENGTH = int(os.getenv('MAX_CONTENT_LENGTH', 5 * 1024 * 1024))
KEEP_IMAGES = os.getenv('KEEP_IMAGES', 'false').lower() == 'true'
LATENT_DIM = int(os.getenv('LATENT_DIM', 256))
SIGMA = float(os.getenv('SIGMA', 0.0003))
TARGET_SIZE = tuple(map(int, os.getenv('TARGET_SIZE', '224,224').split(',')))
MODEL_PATH = os.getenv('MODEL_PATH', 'alcohol3.keras')
AUTHENTICITY_THRESHOLD = float(os.getenv('AUTHENTICITY_THRESHOLD', 0.4))
ADMIN_USERNAME = os.getenv('ADMIN_USERNAME')
ADMIN_PASSWORD = os.getenv('ADMIN_PASSWORD')

# Ensure upload folder exists
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# Logging setup
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)
handler = RotatingFileHandler('app.log', maxBytes=1000000, backupCount=5)
handler.setFormatter(logging.Formatter('%(asctime)s - %(levelname)s - %(message)s'))
logger.addHandler(handler)

# Database setup
Base = declarative_base()
engine = create_engine(DATABASE_URI, connect_args={"check_same_thread": False} if "sqlite" in DATABASE_URI else {})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

class ScanResult(Base):
    __tablename__ = 'scan_result'
    id = Column(Integer, primary_key=True)
    brand = Column(String(80), nullable=False)
    batch_no = Column(String(80), nullable=False)
    date = Column(String(20), nullable=False)
    confidence = Column(String(20), nullable=False)
    is_authentic = Column(Boolean, nullable=False)
    latitude = Column(String(20))
    longitude = Column(String(20))
    image_url = Column(String(200))
    timestamp = Column(DateTime, default=datetime.utcnow)

Base.metadata.create_all(bind=engine)

# Dependency to get DB session
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# Model loading
def load_model_from_path(path):
    try:
        model = load_model(path, compile=False)
        logger.info(f"Model loaded from {path}")
        return model
    except Exception as e:
        logger.error(f"Error loading model: {e}")
        return None

model = load_model_from_path(MODEL_PATH)

# Utilities
def allowed_file(filename: str) -> bool:
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

def is_valid_coordinate(lat: str, lon: str) -> bool:
    try:
        lat, lon = float(lat), float(lon)
        return -90 <= lat <= 90 and -180 <= lon <= 180
    except:
        return False

def load_image(path: str):
    try:
        image = tf.io.read_file(path)
        image = tf.image.decode_jpeg(image, channels=3)
        image = tf.image.adjust_contrast(image, contrast_factor=1.2)
        image = tf.image.resize(image, TARGET_SIZE)
        return image / 255.0
    except Exception as e:
        logger.error(f"Image load error: {e}")
        raise

def run_prediction(image_tensor):
    pseudo_negative = tf.random.normal([1, LATENT_DIM], mean=0.0, stddev=SIGMA)
    test_probs, _ = model.predict([tf.expand_dims(image_tensor, axis=0), pseudo_negative], verbose=0)
    return float(test_probs[0][0])

def save_to_cloud_storage(file, filename: str) -> str:
    return f"/Uploads/{filename}"

# Pydantic models for request/response validation
class AdminLogin(BaseModel):
    username: str
    password: str

# Mount static files and templates
app.mount("/Uploads", StaticFiles(directory=UPLOAD_FOLDER), name="uploads")
templates = Jinja2Templates(directory="templates")

# Routes
@app.get("/")
async def home():
    return {"message": "Welcome to the Alcohol Detection API"}

@app.get("/health")
async def health(db: Session = Depends(get_db)):
    try:
        db.execute(text('SELECT 1'))
        db_status = True
    except Exception as e:
        logger.error(f"DB health check failed: {e}")
        db_status = False
    return {
        "model_loaded": model is not None,
        "database_connected": db_status
    }

@app.get("/predict/health")
async def predict_health():
    try:
        model_status = model is not None
        return {
            "model_loaded": model_status,
            "message": "Prediction endpoint is healthy" if model_status else "Model not loaded"
        }
    except Exception as e:
        logger.error(f"Predict health check failed: {e}")
        raise HTTPException(status_code=500, detail="Server error")

@app.post("/predict")
async def predict(
    image: UploadFile = File(...),
    brand: str = Form(default="County"),
    latitude: str = Form(default="Unknown"),
    longitude: str = Form(default="Unknown"),
    db: Session = Depends(get_db)
):
    filepath = None
    try:
        if not allowed_file(image.filename):
            raise HTTPException(status_code=400, detail="Invalid file type")

        if latitude != "Unknown" and longitude != "Unknown" and not is_valid_coordinate(latitude, longitude):
            raise HTTPException(status_code=400, detail="Invalid coordinates")

        filename = f"{uuid.uuid4().hex}_{image.filename}"
        filepath = os.path.join(UPLOAD_FOLDER, filename)
        with open(filepath, "wb") as f:
            content = await image.read()
            if len(content) > MAX_CONTENT_LENGTH:
                raise HTTPException(status_code=400, detail="File too large")
            f.write(content)

        image_url = save_to_cloud_storage(image, filename)
        image_tensor = load_image(filepath)

        if model is None:
            raise HTTPException(status_code=500, detail="Model not loaded")

        score = run_prediction(image_tensor)
        today = datetime.now().strftime("%Y-%m-%d")
        batch_no = f"{brand[:3].upper()}-{datetime.now().year}"
        confidence = f"{score:.2%}"
        is_authentic = score >= AUTHENTICITY_THRESHOLD

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
        db.add(scan)
        db.commit()
        db.refresh(scan)

        if not KEEP_IMAGES and filepath and os.path.exists(filepath):
            os.remove(filepath)

        return {
            "id": scan.id,
            "is_authentic": is_authentic,
            "brand": brand,
            "batch_no": batch_no,
            "date": today,
            "confidence": confidence,
            "latitude": latitude,
            "longitude": longitude,
            "image_url": image_url,
            "message": "Authentic" if is_authentic else "Counterfeit detected"
        }

    except Exception as e:
        db.rollback()
        if filepath and os.path.exists(filepath):
            os.remove(filepath)
        logger.error(f"Prediction error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/locations")
async def get_locations(page: int = Query(1), per_page: int = Query(100), db: Session = Depends(get_db)):
    try:
        scans = db.query(ScanResult).offset((page - 1) * per_page).limit(per_page).all()
        locations = []
        for scan in scans:
            try:
                lat = float(scan.latitude) if scan.latitude != 'Unknown' else -1.2284
                lng = float(scan.longitude) if scan.longitude != 'Unknown' else 36.8722
            except:
                lat, lng = -1.2284, 36.8722
            locations.append({
                "lat": lat,
                "lng": lng,
                "is_authentic": scan.is_authentic,
                "brand": scan.brand,
                "batch_no": scan.batch_no,
                "confidence": scan.confidence,
                "date": scan.date,
                "image_url": scan.image_url
            })
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
async def admin_login_post(request: Request, username: str = Form(...), password: str = Form(...)):
    if username == ADMIN_USERNAME and password == ADMIN_PASSWORD:
        response = RedirectResponse(url="/admin/map", status_code=303)
        response.set_cookie(key="admin_authenticated", value="true")
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
