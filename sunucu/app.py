import logging
import sqlite3
from datetime import datetime
from pathlib import Path

from flask import Flask, g, jsonify, request

BASE_DIR = Path(__file__).resolve().parent
DATABASE = BASE_DIR / "cave_watch_ai.db"
DEFAULT_SCORE = 100.0
TEMPERATURE_TOLERANCE = 2.0
LIGHT_ALERT_THRESHOLD = 400.0

app = Flask(__name__)
app.config["DATABASE"] = str(DATABASE)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s",
)


def get_db():
    if "db" not in g:
        connection = sqlite3.connect(app.config["DATABASE"])
        connection.row_factory = sqlite3.Row
        connection.execute("PRAGMA foreign_keys = ON")
        g.db = connection
    return g.db


@app.teardown_appcontext
def close_db(_exception):
    db = g.pop("db", None)
    if db is not None:
        db.close()


def init_db():
    db = get_db()
    db.executescript(
        """
        CREATE TABLE IF NOT EXISTS partiler (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            urun_adi TEXT NOT NULL,
            baslangic_tarihi TEXT NOT NULL,
            bitis_tarihi TEXT,
            ideal_sicaklik REAL NOT NULL,
            nihai_skor REAL NOT NULL DEFAULT 100,
            durum TEXT NOT NULL CHECK (durum IN ('aktif', 'tamamlandi'))
        );

        CREATE TABLE IF NOT EXISTS veri_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            parti_id INTEGER NOT NULL,
            sicaklik REAL NOT NULL,
            nem REAL NOT NULL,
            isik REAL NOT NULL,
            zaman TEXT NOT NULL,
            FOREIGN KEY (parti_id) REFERENCES partiler(id) ON DELETE CASCADE
        );
        """
    )
    db.commit()


def now_as_text():
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def fetch_active_batch(db):
    return db.execute(
        """
        SELECT *
        FROM partiler
        WHERE durum = 'aktif'
        ORDER BY baslangic_tarihi DESC
        LIMIT 1
        """
    ).fetchone()


def fetch_latest_log(db, parti_id):
    return db.execute(
        """
        SELECT sicaklik, nem, isik, zaman
        FROM veri_log
        WHERE parti_id = ?
        ORDER BY zaman DESC, id DESC
        LIMIT 1
        """,
        (parti_id,),
    ).fetchone()


def calculate_score(current_score, ideal_temperature, actual_temperature, light_level):
    penalty = 0.0
    reasons = []

    temperature_delta = abs(actual_temperature - ideal_temperature)
    if temperature_delta > TEMPERATURE_TOLERANCE:
        temperature_penalty = round(
            4.0 + (temperature_delta - TEMPERATURE_TOLERANCE) * 2.0, 2
        )
        penalty += temperature_penalty
        reasons.append(
            f"Sicaklik ideal degerden {temperature_delta:.2f} derece saptigi icin "
            f"{temperature_penalty:.2f} puan dusuldu."
        )

    if light_level > LIGHT_ALERT_THRESHOLD:
        light_penalty = round(3.0 + ((light_level - LIGHT_ALERT_THRESHOLD) / 100.0), 2)
        penalty += light_penalty
        reasons.append(
            f"Isik seviyesi {LIGHT_ALERT_THRESHOLD:.0f} esigini astigi icin "
            f"{light_penalty:.2f} puan dusuldu."
        )

    updated_score = max(0.0, round(current_score - penalty, 2))
    return updated_score, round(penalty, 2), reasons


def parse_float(value, field_name):
    if value is None or str(value).strip() == "":
        raise ValueError(f"'{field_name}' alani zorunludur.")

    try:
        return float(value)
    except (TypeError, ValueError) as exc:
        raise ValueError(f"'{field_name}' sayisal bir deger olmali.") from exc


def row_to_batch_payload(batch_row, latest_log=None):
    sensor_data = None
    if latest_log is not None:
        sensor_data = {
            "sicaklik": latest_log["sicaklik"],
            "nem": latest_log["nem"],
            "isik": latest_log["isik"],
            "zaman": latest_log["zaman"],
        }

    return {
        "parti_id": batch_row["id"],
        "urun_adi": batch_row["urun_adi"],
        "baslangic_tarihi": batch_row["baslangic_tarihi"],
        "bitis_tarihi": batch_row["bitis_tarihi"],
        "ideal_sicaklik": batch_row["ideal_sicaklik"],
        "ihracat_skoru": batch_row["nihai_skor"],
        "durum": batch_row["durum"],
        "son_veri": sensor_data,
    }


@app.route("/veri_al", methods=["GET"])
def veri_al():
    try:
        sicaklik = parse_float(request.args.get("sicaklik"), "sicaklik")
        nem = parse_float(request.args.get("nem"), "nem")
        isik = parse_float(request.args.get("isik"), "isik")
    except ValueError as exc:
        return jsonify({"hata": str(exc)}), 400

    db = get_db()
    active_batch = fetch_active_batch(db)
    if active_batch is None:
        app.logger.warning(
            "Sensor verisi geldi ancak aktif parti bulunamadi | sicaklik=%.2f nem=%.2f isik=%.2f",
            sicaklik,
            nem,
            isik,
        )
        return (
            jsonify(
                {
                    "hata": "Aktif parti bulunamadi. Once /api/yeni_urun ile yeni urun baslatin."
                }
            ),
            404,
        )

    current_score = active_batch["nihai_skor"] or DEFAULT_SCORE
    new_score, penalty, reasons = calculate_score(
        current_score=current_score,
        ideal_temperature=active_batch["ideal_sicaklik"],
        actual_temperature=sicaklik,
        light_level=isik,
    )
    timestamp = now_as_text()

    try:
        db.execute(
            """
            INSERT INTO veri_log (parti_id, sicaklik, nem, isik, zaman)
            VALUES (?, ?, ?, ?, ?)
            """,
            (active_batch["id"], sicaklik, nem, isik, timestamp),
        )
        db.execute(
            """
            UPDATE partiler
            SET nihai_skor = ?
            WHERE id = ?
            """,
            (new_score, active_batch["id"]),
        )
        db.commit()
    except sqlite3.DatabaseError:
        db.rollback()
        app.logger.exception("Sensor verisi kaydedilirken veritabani hatasi olustu.")
        return jsonify({"hata": "Veritabani kayit hatasi."}), 500

    app.logger.info(
        "Sensor verisi alindi | parti_id=%s urun=%s sicaklik=%.2f nem=%.2f isik=%.2f skor=%.2f->%.2f",
        active_batch["id"],
        active_batch["urun_adi"],
        sicaklik,
        nem,
        isik,
        current_score,
        new_score,
    )
    if reasons:
        app.logger.warning(
            "Skor guncellendi | parti_id=%s toplam_ceza=%.2f detay=%s",
            active_batch["id"],
            penalty,
            " | ".join(reasons),
        )

    return jsonify(
        {
            "mesaj": "Sensor verisi kaydedildi.",
            "parti_id": active_batch["id"],
            "urun_adi": active_batch["urun_adi"],
            "anlik_veri": {
                "sicaklik": sicaklik,
                "nem": nem,
                "isik": isik,
                "zaman": timestamp,
            },
            "ihracat_skoru": new_score,
            "puan_kesintisi": penalty,
            "skor_detaylari": reasons or ["Skor degismedi."],
        }
    )


@app.route("/api/yeni_urun", methods=["POST"])
def yeni_urun():
    payload = request.get_json(silent=True) or request.form

    urun_adi = str(payload.get("urun_adi", "")).strip()
    if not urun_adi:
        return jsonify({"hata": "'urun_adi' alani zorunludur."}), 400

    try:
        ideal_sicaklik = parse_float(payload.get("ideal_sicaklik"), "ideal_sicaklik")
    except ValueError as exc:
        return jsonify({"hata": str(exc)}), 400

    db = get_db()
    active_batch = fetch_active_batch(db)
    timestamp = now_as_text()

    try:
        if active_batch is not None:
            db.execute(
                """
                UPDATE partiler
                SET durum = 'tamamlandi', bitis_tarihi = ?
                WHERE id = ?
                """,
                (timestamp, active_batch["id"]),
            )
            app.logger.info(
                "Aktif parti tamamlandi | parti_id=%s urun=%s nihai_skor=%.2f",
                active_batch["id"],
                active_batch["urun_adi"],
                active_batch["nihai_skor"],
            )

        cursor = db.execute(
            """
            INSERT INTO partiler (
                urun_adi, baslangic_tarihi, bitis_tarihi,
                ideal_sicaklik, nihai_skor, durum
            )
            VALUES (?, ?, ?, ?, ?, 'aktif')
            """,
            (urun_adi, timestamp, None, ideal_sicaklik, DEFAULT_SCORE),
        )
        db.commit()
    except sqlite3.DatabaseError:
        db.rollback()
        app.logger.exception("Yeni urun partisi olusturulurken veritabani hatasi olustu.")
        return jsonify({"hata": "Yeni parti olusturulamadi."}), 500

    new_batch = db.execute(
        "SELECT * FROM partiler WHERE id = ?",
        (cursor.lastrowid,),
    ).fetchone()

    app.logger.info(
        "Yeni aktif parti olusturuldu | parti_id=%s urun=%s ideal_sicaklik=%.2f",
        new_batch["id"],
        new_batch["urun_adi"],
        new_batch["ideal_sicaklik"],
    )

    return (
        jsonify(
            {
                "mesaj": "Yeni urun partisi baslatildi.",
                "parti": row_to_batch_payload(new_batch),
            }
        ),
        201,
    )


@app.route("/api/durum", methods=["GET"])
def durum():
    db = get_db()
    active_batch = fetch_active_batch(db)
    if active_batch is None:
        return jsonify({"hata": "Aktif parti bulunamadi."}), 404

    latest_log = fetch_latest_log(db, active_batch["id"])
    return jsonify(row_to_batch_payload(active_batch, latest_log))


with app.app_context():
    init_db()


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)
