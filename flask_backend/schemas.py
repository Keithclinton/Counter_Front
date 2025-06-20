from pydantic import BaseModel, validator
from typing import Optional

class AdminLogin(BaseModel):
    username: str
    password: str

class PredictRequest(BaseModel):
    brand: str = "County"
    latitude: Optional[str] = "Unknown"
    longitude: Optional[str] = "Unknown"

    @validator('latitude', 'longitude')
    def validate_coordinates(cls, v, values, field):
        if v != "Unknown":
            try:
                coord = float(v)
                if field.name == 'latitude' and not -90 <= coord <= 90:
                    raise ValueError(f"Invalid {field.name}")
                if field.name == 'longitude' and not -180 <= coord <= 180:
                    raise ValueError(f"Invalid {field.name}")
            except ValueError:
                raise ValueError(f"Invalid {field.name} format")
        return v

class PredictResponse(BaseModel):
    id: int
    is_authentic: bool
    brand: str
    batch_no: str
    date: str
    confidence: str
    latitude: str
    longitude: str
    image_url: Optional[str]
    message: str
