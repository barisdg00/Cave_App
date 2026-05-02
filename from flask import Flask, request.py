from flask import Flask, request, jsonify
from flask_cors import CORS
import pyodbc
from waitress import serve

app = Flask(__name__)
CORS(app)

conn_str = (
    "Driver={SQL Server};"
    "Server=(local);"
    "Database=ArduinoDB;"
    "Trusted_Connection=yes;"
)

def save_to_db(s, n, i):
    try:
        conn = pyodbc.connect(conn_str)
        cursor = conn.cursor()
        cursor.execute(
            "INSERT INTO Girdiler (SensorID, Sicaklik, Nem, IsikLux) VALUES (?, ?, ?, ?)",
            (1, s, n, i)
        )
        conn.commit()
        conn.close()
        return True
    except Exception as e:
        print(f"Veritabanı hatası: {e}")
        return False

@app.route('/veri_al', methods=['GET'])
def veri_al():
    sicaklik = request.args.get('sicaklik')
    nem = request.args.get('nem')
    isik = request.args.get('isik')
    if sicaklik and nem:
        if save_to_db(sicaklik, nem, isik):
            return "Veri Basariyla Kaydedildi", 200
        else:
            return "Veritabanı Hatasi", 500
    return "Eksik Veri", 400

# DİKKAT: BU KISIM KESİNLİKLE OLMALI
@app.route('/verileri_getir', methods=['GET'])
def verileri_getir():
    try:
        conn = pyodbc.connect(conn_str)
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM Girdiler")
        
        columns = [column[0] for column in cursor.description]
        results = []
        for row in cursor.fetchall():
            results.append(dict(zip(columns, row)))
            
        conn.close()
        return jsonify(results), 200
    except Exception as e:
        print(f"Veritabanı okuma hatası: {e}")
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    print("Sunucu 5000 portunda baslatildi...")
    serve(app, host='0.0.0.0', port=5000)