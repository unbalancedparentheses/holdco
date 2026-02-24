import yfinance as yf

# Map custom tickers to Yahoo Finance tickers
TICKER_MAP: dict[str, str] = {
    "XAUUSD": "GC=F",
    "XAGUSD": "SI=F",
    "BTC": "BTC-USD",
    "ETH": "ETH-USD",
    "SOL": "SOL-USD",
}


def resolve_ticker(ticker: str) -> str:
    return TICKER_MAP.get(ticker, ticker)


def get_price(ticker: str) -> float | None:
    yf_ticker = resolve_ticker(ticker)
    try:
        data = yf.Ticker(yf_ticker)
        price = data.fast_info.get("lastPrice")
        if price is not None:
            return float(price)
        hist = data.history(period="1d")
        if not hist.empty:
            return float(hist["Close"].iloc[-1])
    except Exception:
        return None
    return None


def get_prices(tickers: list[str]) -> dict[str, float | None]:
    return {t: get_price(t) for t in tickers}
