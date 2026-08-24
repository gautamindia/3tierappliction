"""
Backend tier - Flask API + business logic.
Talks to the RDS Postgres database and is the ONLY tier allowed to do so.
"""
import os
import logging
from decimal import Decimal, ROUND_HALF_UP

import psycopg2
import psycopg2.extras
from flask import Flask, jsonify, request

logging.basicConfig(level=logging.INFO)
log = logging.getLogger("backend")

app = Flask(__name__)

DB_HOST = os.environ.get("DB_HOST")
DB_PORT = os.environ.get("DB_PORT", "5432")
DB_NAME = os.environ.get("DB_NAME", "appdb")
DB_USER = os.environ.get("DB_USER", "appuser")
DB_PASSWORD = os.environ.get("DB_PASSWORD")


def get_connection():
    return psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
        connect_timeout=5,
    )


def init_db():
    """Create the items table if it doesn't exist yet."""
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS items (
                    id SERIAL PRIMARY KEY,
                    name TEXT NOT NULL,
                    base_price NUMERIC(10, 2) NOT NULL,
                    quantity INTEGER NOT NULL DEFAULT 1,
                    created_at TIMESTAMP DEFAULT NOW()
                )
                """
            )
        conn.commit()


def apply_bulk_discount(base_price: Decimal, quantity: int) -> Decimal:
    """
    Business logic: tiered bulk-discount pricing.
      - 10+ units: 15% off
      - 5-9 units: 10% off
      - 1-4 units: no discount
    Returns the total price for the given quantity, discount applied.
    """
    if quantity >= 10:
        discount = Decimal("0.15")
    elif quantity >= 5:
        discount = Decimal("0.10")
    else:
        discount = Decimal("0.00")

    unit_price = base_price * (Decimal("1.00") - discount)
    total = (unit_price * quantity).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
    return total


@app.route("/api/health")
def health():
    return jsonify(status="ok", tier="backend")


@app.route("/api/items", methods=["GET"])
def list_items():
    with get_connection() as conn:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(
                "SELECT id, name, base_price, quantity, created_at FROM items ORDER BY id DESC"
            )
            rows = cur.fetchall()

    items = []
    for row in rows:
        total_price = apply_bulk_discount(Decimal(row["base_price"]), row["quantity"])
        items.append(
            {
                "id": row["id"],
                "name": row["name"],
                "base_price": str(row["base_price"]),
                "quantity": row["quantity"],
                "total_price": str(total_price),
                "created_at": row["created_at"].isoformat() if row["created_at"] else None,
            }
        )
    return jsonify(items=items)


@app.route("/api/items", methods=["POST"])
def create_item():
    payload = request.get_json(force=True, silent=True) or {}
    name = payload.get("name")
    base_price = payload.get("base_price")
    quantity = payload.get("quantity", 1)

    if not name or base_price is None:
        return jsonify(error="name and base_price are required"), 400

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO items (name, base_price, quantity) VALUES (%s, %s, %s) RETURNING id",
                (name, base_price, quantity),
            )
            new_id = cur.fetchone()[0]
        conn.commit()

    return jsonify(id=new_id), 201


if __name__ == "__main__":
    try:
        init_db()
    except Exception as exc:  # pragma: no cover
        log.warning("Could not initialize DB at startup: %s", exc)
    app.run(host="0.0.0.0", port=5000)
