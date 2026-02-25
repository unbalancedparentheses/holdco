.PHONY: test seed run-dashboard run-api report clean

test:
	pytest tests/ -v

seed:
	python seed.py

run-dashboard:
	streamlit run app.py

run-api:
	uvicorn api:app --reload

report:
	python generate_readme.py

clean:
	rm -f holdco.db
	rm -f REPORT.md
	find . -type d -name __pycache__ -exec rm -rf {} +
