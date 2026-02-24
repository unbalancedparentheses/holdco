from enum import Enum

from pydantic import BaseModel, field_validator


class Category(str, Enum):
    CODE = "Code"
    FINANCE = "Finance"
    CULTURE = "Culture"
    CRAFT = "Craft"
    HOLDING = "Holding"


class Company(BaseModel):
    name: str
    legal_name: str | None = None
    country: str
    category: Category
    ownership_pct: int | None = None
    tax_id: str | None = None
    shareholders: list[str] = []
    directors: list[str] = []
    lawyer_studio: str | None = None

    @field_validator("ownership_pct")
    @classmethod
    def validate_ownership(cls, v: int | None) -> int | None:
        if v is not None and not (0 <= v <= 100):
            raise ValueError("ownership_pct must be between 0 and 100")
        return v


class Holding(Company):
    category: Category = Category.HOLDING
    subsidiaries: list[Company] = []
