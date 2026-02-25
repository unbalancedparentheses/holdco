import yfinance as yf

# Map custom tickers to Yahoo Finance tickers
TICKER_MAP: dict[str, str] = {
    "XAUUSD": "GC=F",
    "XAGUSD": "SI=F",
    "BTC": "BTC-USD",
    "ETH": "ETH-USD",
    "SOL": "SOL-USD",
}

# Currency conversion tickers
CURRENCY_TICKERS: dict[str, str] = {
    "EUR": "EURUSD=X",
    "GBP": "GBPUSD=X",
    "ARS": "ARSUSD=X",
    "UYU": "UYUUSD=X",
    "BRL": "BRLUSD=X",
}


def resolve_ticker(ticker: str) -> str:
    return TICKER_MAP.get(ticker, ticker)


def get_price(ticker: str, record: bool = False) -> float | None:
    yf_ticker = resolve_ticker(ticker)
    try:
        data = yf.Ticker(yf_ticker)
        price = data.fast_info.get("lastPrice")
        if price is not None:
            price = float(price)
        else:
            hist = data.history(period="1d")
            if not hist.empty:
                price = float(hist["Close"].iloc[-1])

        if price is not None and record:
            import db
            db.record_price(ticker, price)

        return price
    except Exception:
        return None


def get_prices(tickers: list[str], record: bool = False) -> dict[str, float | None]:
    return {t: get_price(t, record=record) for t in tickers}


def get_fx_rate(currency: str) -> float | None:
    """Get USD exchange rate for a currency. Returns how many USD per 1 unit of currency."""
    if currency == "USD":
        return 1.0
    ticker = CURRENCY_TICKERS.get(currency)
    if not ticker:
        return None
    return get_price(ticker)
