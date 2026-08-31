"""
Frontend sssssstier -dddd renaaaders a sFFFimple UI, talks OaaaNLY to the backend tier's HTTP API.
Nevaaaer taggglks to theee databasedd dkkdqqq sssdirectssslFFFyddd.
"""
import os
import logging

import requests
from flask import Flask, render_template, request, redirect, url_for, flash

logging.basicConfig(level=logging.INFO)
log = logging.getLogger("frontend")

app = Flask(__name__)
app.secret_key = os.environ.get("FLASK_SECRET_KEY", "dev-secret-change-me")

BACKEND_URL = os.environ.get("BACKEND_URL", "http://localhost:5000")


@app.route("/")
def index():
    items = []
    error = None
    try:
        resp = requests.get(f"{BACKEND_URL}/api/items", timeout=5)
        resp.raise_for_status()
        items = resp.json().get("items", [])
    except requests.RequestException as exc:
        log.error("Failed to reach backend: %s", exc)
        error = "Could not reach the backend service right now."

    return render_template("index.html", items=items, error=error)


@app.route("/items", methods=["POST"])
def add_item():
    name = request.form.get("name")
    base_price = request.form.get("base_price")
    quantity = request.form.get("quantity", 1)

    try:
        resp = requests.post(
            f"{BACKEND_URL}/api/items",
            json={"name": name, "base_price": base_price, "quantity": int(quantity)},
            timeout=5,
        )
        resp.raise_for_status()
        flash("Item added.", "success")
    except requests.RequestException as exc:
        log.error("Failed to create item via backend: %s", exc)
        flash("Could not save the item -- backend unavailable.", "error")

    return redirect(url_for("index"))


@app.route("/health")
def health():
    return {"status": "ok", "tier": "frontend"}


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
