from models import AssetHolding, Category, Company, CustodianAccount, Holding

camiguin = Holding(
    name="Camiguin",
    country="Spain",
    shareholders=["Federico Carrone"],
    directors=["Martin Paulucci", "Nicolas Urman"],
    lawyer_studio="Briz",
    subsidiaries=[
        Company(
            name="Foltrek",
            country="Uruguay",
            category=Category.CODE,
            ownership_pct=100,
            directors=["Juan Deal", "Federico Carrone"],
            lawyer_studio="PPV",
            holdings=[
                AssetHolding(
                    asset="Gold",
                    ticker="XAUUSD",
                    custodian=CustodianAccount(
                        bank="Pershing",
                        authorized_persons=["Juan Deal", "Federico Carrone"],
                    ),
                ),
            ],
        ),
        Company(name="Lambda", country="Argentina", category=Category.CODE, ownership_pct=100),
        Company(name="Sur", country="Argentina", category=Category.CODE, ownership_pct=50),
        Company(name="FuzzingLabs", country="Argentina", category=Category.CODE, ownership_pct=100),
        Company(name="Aligned", country="Argentina", category=Category.CODE, ownership_pct=100),
        Company(name="Sovra", country="Argentina", category=Category.CODE, ownership_pct=100),
        Company(name="Restolia", country="Argentina", category=Category.CODE, ownership_pct=100),
        Company(name="3MI Labs", country="Argentina", category=Category.FINANCE, ownership_pct=100),
        Company(name="Ergodic Fund", country="Argentina", category=Category.FINANCE, ownership_pct=100),
        Company(name="Pol Finance", country="Argentina", category=Category.FINANCE, ownership_pct=100),
        Company(name="Levenue", country="Argentina", category=Category.FINANCE, ownership_pct=100),
        Company(name="Cresium", country="Argentina", category=Category.FINANCE, ownership_pct=100),
        Company(name="421", country="Argentina", category=Category.CULTURE, ownership_pct=100),
        Company(name="Bellolandia", country="Argentina", category=Category.CULTURE, ownership_pct=100),
        Company(name="LCB Game Studio", country="Argentina", category=Category.CULTURE, ownership_pct=100),
        Company(name="Lambda Forge", country="Argentina", category=Category.CULTURE, ownership_pct=100),
        Company(name="Arcademy", country="Argentina", category=Category.CULTURE, ownership_pct=100),
        Company(name="Burgschneider", country="Europe/US", category=Category.CRAFT, ownership_pct=100),
        Company(name="Laderas de los Andes", country="Argentina", category=Category.CRAFT, ownership_pct=100),
        Company(name="Fruto Cafe", country="Argentina", category=Category.CRAFT, ownership_pct=100),
        Company(name="High Mobility", country="Argentina", category=Category.CRAFT, ownership_pct=100),
        Company(name="\u014ctoro", country="Argentina", category=Category.CRAFT, ownership_pct=100),
        Company(name="Palermo Wine Club", country="Argentina", category=Category.CRAFT, ownership_pct=100),
        Company(name="Best Eleven", country="Argentina", category=Category.CRAFT, ownership_pct=100),
    ],
)

lambda_sas = Company(
    name="Lambda SAS",
    country="Argentina",
    category=Category.CODE,
    ownership_pct=100,
    shareholders=["Pablo Perello", "Juan Mazzoni", "Martina Cantaro", "Matias Onorato"],
    directors=["Pablo Perello"],
    lawyer_studio="Croz",
)

entities: list[Holding | Company] = [camiguin, lambda_sas]
