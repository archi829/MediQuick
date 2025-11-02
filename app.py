from flask import Flask, jsonify, render_template,request
from flasgger import Swagger
import mysql.connector

app = Flask(__name__)
swagger = Swagger(app)

db_config = {
    'user': 'root',
    'password': 'dbms29',
    'host': '127.0.0.1',
    'database': 'mediquick'
}

def get_db_connection():
    try:
        conn = mysql.connector.connect(**db_config)
        return conn
    except mysql.connector.Error as err:
        print(f"Error connecting to database: {err}")
        return None
    
@app.route('/')
def index():
    conn = get_db_connection()
    if not conn:
        return "DB connection failed", 500
    
    cursor = conn.cursor(dictionary = True) # dictionary=True gives you results as dicts
    cursor.execute("SELECT * FROM Medicine LIMIT 5;")
    meds = cursor.fetchall()

    cursor.close()
    conn.close()

    return render_template('index.html',medicines = meds)

if __name__ == '__main__':
    app.run(debug=True)