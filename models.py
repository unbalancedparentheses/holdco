from pydantic import BaseModel, field_validator


class CustodianAccount(BaseModel):
    bank: str
    account_number: str | None = None
    account_type: str | None = None
    authorized_persons: list[str] = []


class AssetHolding(BaseModel):
    asset: str
    ticker: str | None = None
    quantity: float | None = None
    unit: str | None = None
    custodian: CustodianAccount | None = None


class Company(BaseModel):
    name: str
    legal_name: str | None = None
    country: str
    category: str
    ownership_pct: int | None = None
    tax_id: str | None = None
    shareholders: list[str] = []
    directors: list[str] = []
    lawyer_studio: str | None = None
    holdings: list[AssetHolding] = []

    @field_validator("ownership_pct")
    @classmethod
    def validate_ownership(cls, v: int | None) -> int | None:
        if v is not None and not (0 <= v <= 100):
            raise ValueError("ownership_pct must be between 0 and 100")
        return v


class Holding(Company):
    category: str = "Holding"
    subsidiaries: list[Company] = []
