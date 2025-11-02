import json
from flask import Flask, jsonify, render_template, request, abort
from flasgger import Swagger
import mysql.connector
from mysql.connector import errorcode
import random # For dummy coordinates
from datetime import date, datetime

app = Flask(__name__)
swagger = Swagger(app)

# --- DATABASE CONNECTION ---
db_config = {
    'user': 'admin_user',       # Using the 'admin_user' we created
    'password': 'adminpass123', # The password for 'admin_user'
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

def create_mysql_user_with_role(username, password, role_type, cursor):
    """
    Creates a MySQL user and assigns appropriate role.
    This is called when a new user is created in the User table.
    """
    try:
        # Map role types to MySQL role names
        role_mapping = {
            'Customer': 'customer_role',
            'Doctor': 'doctor_role',
            'Pharmacy': 'pharmacy_role',
            'Agent': 'agent_role'
        }
        
        mysql_role = role_mapping.get(role_type)
        if not mysql_role:
            print(f"Warning: No role mapping for {role_type}, skipping MySQL user creation")
            return True  # Don't fail the transaction
        
        # Sanitize username for MySQL user creation
        # MySQL username limit is 32 characters
        # Extract the part before @ from email (e.g., 'doc1@gmail.com' -> 'doc1')
        # If username doesn't contain @, use it as-is (truncated to 32 chars)
        if '@' in username:
            mysql_username = username.split('@')[0][:32]  # Get part before @, max 32 chars
        else:
            mysql_username = username[:32]  # Use as-is, max 32 chars
        
        # Create MySQL user
        create_user_query = f"CREATE USER IF NOT EXISTS '{mysql_username}'@'localhost' IDENTIFIED BY '{password}'"
        cursor.execute(create_user_query)
        
        # Grant role to user
        grant_role_query = f"GRANT '{mysql_role}'@'localhost' TO '{mysql_username}'@'localhost'"
        cursor.execute(grant_role_query)
        
        # Set default role
        set_role_query = f"SET DEFAULT ROLE '{mysql_role}'@'localhost' TO '{mysql_username}'@'localhost'"
        cursor.execute(set_role_query)
        
        # Flush privileges to apply changes
        cursor.execute("FLUSH PRIVILEGES")
        
        print(f"Created MySQL user '{mysql_username}' with role '{mysql_role}'")
        return True
        
    except mysql.connector.Error as err:
        print(f"Warning: Failed to create MySQL user: {err}")
        # Don't raise - allow the transaction to continue even if MySQL user creation fails
        # This allows the app to work even if roles aren't set up
        return False

# --- Helper Function to serialize complex types (like dates) ---
def json_serializer(obj):
    """Custom JSON serializer for objects not serializable by default json code"""
    if isinstance(obj, (datetime, date)):
        return obj.isoformat()
    raise TypeError ("Type %s not serializable" % type(obj))

def run_query(query, params=None, fetch_one=False, dictionary=True):
    """Helper function to run queries and handle connection."""
    conn = get_db_connection()
    if not conn:
        return None, "DB connection failed"
    
    cursor = conn.cursor(dictionary=dictionary)
    try:
        cursor.execute(query, params or ())
        
        if query.strip().upper().startswith('SELECT'):
            if fetch_one:
                results = cursor.fetchone()
            else:
                results = cursor.fetchall()
        else:
            conn.commit()
            results = {"message": "Success", "lastrowid": cursor.lastrowid}
            
        return results, None
    
    except mysql.connector.Error as err:
        conn.rollback()
        return None, err
    finally:
        cursor.close()
        conn.close()

# --- Helper for Dummy Coordinates ---
def get_dummy_coords(city, state):
    """
    Generates realistic-looking dummy coordinates based on city and state.
    This is a "dummy" function for your project demo.
    """
    city_lower = city.lower().strip() if city else ''
    state_lower = state.lower().strip() if state else ''
    
    # Default coordinates (Bengaluru)
    lat, lng = 12.9716, 77.5946
    
    # Major Indian cities with their coordinates
    city_coords = {
        'mumbai': (19.0760, 72.8777),
        'kolkata': (22.5726, 88.3639),
        'delhi': (28.7041, 77.1025),
        'chennai': (13.0827, 80.2707),
        'hyderabad': (17.3850, 78.4867),
        'bangalore': (12.9716, 77.5946),
        'bengaluru': (12.9716, 77.5946),
        'pune': (18.5204, 73.8567),
        'ahmedabad': (23.0225, 72.5714),
        'jaipur': (26.9124, 75.7873),
        'lucknow': (26.8467, 80.9462),
        'kanpur': (26.4499, 80.3319),
        'nagpur': (21.1458, 79.0882),
        'indore': (22.7196, 75.8577),
        'thane': (19.2183, 72.9781),
        'bhopal': (23.2599, 77.4126),
        'visakhapatnam': (17.6868, 83.2185),
        'patna': (25.5941, 85.1376),
        'vadodara': (22.3072, 73.1812),
        'gurgaon': (28.4089, 77.0378),
        'noida': (28.5355, 77.3910),
        'faridabad': (28.4089, 77.3178),
        'surat': (21.1702, 72.8311),
        'rajkot': (22.3039, 70.8022),
        'mysore': (12.2958, 76.6394),
        'coimbatore': (11.0168, 76.9558),
        'vijayawada': (16.5062, 80.6480),
        'jodhpur': (26.2389, 73.0243),
    }
    
    # Check if city matches
    if city_lower in city_coords:
        lat, lng = city_coords[city_lower]
    
    # Add a small random offset to make coordinates unique for each pharmacy
    lat_offset = random.uniform(-0.02, 0.02)  # Reduced from 0.05 for better accuracy
    lng_offset = random.uniform(-0.02, 0.02)
    
    return round(lat + lat_offset, 6), round(lng + lng_offset, 6)
    

# ==========================================================
# 1. HTML PAGE SERVING ROUTES
# ==========================================================

@app.route('/')
def index():
    """Serves the main home page."""
    return render_template('index.html')

@app.route('/register')
def register_page():
    """Serves the customer registration page."""
    return render_template('register.html')

@app.route('/login')
def customer_login_page():
    """Serves the customer login page."""
    return render_template('login.html')

# --- New Role-Based Login Pages ---

@app.route('/doctor/login')
def doctor_login_page():
    """Serves the login page for Doctors."""
    return render_template('role_login.html', role='Doctor')

@app.route('/pharmacy/login')
def pharmacy_login_page():
    """Serves the login page for Pharmacies."""
    return render_template('role_login.html', role='Pharmacy')

@app.route('/agent/login')
def agent_login_page():
    """Serves the login page for Delivery Agents."""
    return render_template('role_login.html', role='Agent')

# --- Admin Page ---

@app.route('/admin/create_user')
def admin_create_user_page():
    """Serves the admin page for creating new users (Doctors, Agents, etc.)."""
    return render_template('admin_create_user.html')

# --- Logged-in Dashboards ---

@app.route('/dashboard')
def customer_dashboard():
    """Serves the main customer dashboard (search/cart)."""
    return render_template('customer_dashboard.html')

@app.route('/customer_dashboard')
def customer_dashboard_alt():
    """Alternative route for customer dashboard (redirects to /dashboard)."""
    return render_template('customer_dashboard.html')

@app.route('/orders')
def customer_orders():
    """Serves the customer's order tracking page."""
    return render_template('customer_orders.html')

@app.route('/doctor/dashboard')
def doctor_dashboard():
    """Serves the doctor's dashboard for verifying prescriptions."""
    return render_template('doctor_dashboard.html')

@app.route('/pharmacy/dashboard')
def pharmacy_dashboard():
    """Serves the pharmacy dashboard for managing stock and orders."""
    return render_template('pharmacy_dashboard.html')

@app.route('/agent/dashboard')
def agent_dashboard():
    """Serves the delivery agent's dashboard for managing deliveries."""
    return render_template('agent_dashboard.html')

@app.route('/reports')
def reports_page():
    """Serves the reports page (for complex queries)."""
    return render_template('reports.html')


# ==========================================================
# 2. API ROUTES (for JavaScript to fetch data)
# ==========================================================

# --- (Req 4a) USER LOGIN API ---
@app.route('/api/login', methods=['POST'])
def login_user():
    """Handles login for ALL roles."""
    data = request.json
    email = data.get('email')
    password = data.get('password')
    expected_role = data.get('role')

    if not all([email, password, expected_role]):
        return jsonify({"error": "Email, password, and role are required"}), 400

    query = "SELECT user_id, password, role, linked_id FROM User WHERE username = %s"
    user, err = run_query(query, (email,), fetch_one=True)

    if err:
        return jsonify({"error": str(err)}), 500
    
    if not user:
        return jsonify({"error": "Invalid username or password"}), 401
    
    # In a real app, you'd check a hashed password. Here we do a simple check.
    if user['password'] != password:
        return jsonify({"error": "Invalid username or password"}), 401
        
    if user['role'] != expected_role:
        return jsonify({"error": f"This login is not for a {expected_role}"}), 403
        
    # Login successful
    return jsonify({
        "message": "Login successful",
        "user_id": user['user_id'],
        "linked_id": user['linked_id'], # This is the cust_id, doc_id, etc.
        "role": user['role']
    }), 200


# --- (Req 4c) USER REGISTRATION API ---
@app.route('/api/register/customer', methods=['POST'])
def register_customer():
    """Handles new customer registration."""
    data = request.json
    
    conn = get_db_connection()
    if not conn: return jsonify({"error": "DB connection failed"}), 500
    cursor = conn.cursor(dictionary=True)
    
    try:
        # --- Get dummy coordinates ---
        lat, lng = get_dummy_coords(data['address_city'], data['address_state'])
        
        # Step 1: Create the Customer
        customer_query = """
            INSERT INTO Customer (first_name, last_name, email, 
                                  address_street, address_city, address_state, address_pincode,
                                  latitude, longitude)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
        """
        cursor.execute(customer_query, (
            data['first_name'], data['last_name'], data['email'],
            data['address_street'], data['address_city'], data['address_state'],
            data['address_pincode'],
            lat, lng
        ))
        new_cust_id = cursor.lastrowid

        # Step 2: Create the linked User
        user_query = """
            INSERT INTO User (username, password, role, linked_id)
            VALUES (%s, %s, 'Customer', %s)
        """
        # Using email as username, password as provided
        cursor.execute(user_query, (data['email'], data['password'], new_cust_id))
        
        # Step 2a: Create MySQL user with customer_role
        create_mysql_user_with_role(data['email'], data['password'], 'Customer', cursor)
        
        # Step 3: Create the customer's phone entry
        phone_query = "INSERT INTO Customer_Phone (cust_id, phone) VALUES (%s, %s)"
        cursor.execute(phone_query, (new_cust_id, data['phone']))

        # Step 4: Create an empty cart for the new customer
        cart_query = "INSERT INTO Cart (cust_id) VALUES (%s)"
        cursor.execute(cart_query, (new_cust_id,))
        
        conn.commit()
        
        return jsonify({
            "message": "Customer registered successfully!",
            "cust_id": new_cust_id,
            "cart_id": cursor.lastrowid
        }), 201

    except mysql.connector.Error as err:
        conn.rollback()
        if err.errno == 1062: # Duplicate entry
            return jsonify({"error": "This email is already registered."}), 409
        return jsonify({"error": str(err)}), 500
    finally:
        cursor.close()
        conn.close()

@app.route('/api/register/user', methods=['POST'])
def register_other_user():
    """Handles admin creation of new Doctors, Agents, Pharmacies."""
    data = request.json
    role = data.get('role')
    
    conn = get_db_connection()
    if not conn: return jsonify({"error": "DB connection failed"}), 500
    cursor = conn.cursor(dictionary=True)
    
    try:
        new_linked_id = None
        # Step 1: Create the role-specific entity
        if role == 'Doctor':
            query = "INSERT INTO Doctor (doc_name, contact_phone) VALUES (%s, %s)"
            cursor.execute(query, (data['name'], data['phone']))
            new_linked_id = cursor.lastrowid
            
        elif role == 'Agent':
            query = "INSERT INTO Delivery_Agent (agent_name, phone, status) VALUES (%s, %s, 'Offline')"
            cursor.execute(query, (data['name'], data['phone']))
            new_linked_id = cursor.lastrowid

        elif role == 'Pharmacy':
            # Simplified for this form
            query = """
                INSERT INTO Pharmacy (license_no, pharm_name, contact_phone, address_city)
                VALUES (%s, %s, %s, %s)
            """
            cursor.execute(query, (data['license'], data['name'], data['phone'], data['city']))
            new_linked_id = cursor.lastrowid
        else:
            return jsonify({"error": "Invalid role"}), 400

        # Step 2: Create the linked User
        user_query = """
            INSERT INTO User (username, password, role, linked_id)
            VALUES (%s, %s, %s, %s)
        """
        cursor.execute(user_query, (data['email'], data['password'], role, new_linked_id))
        
        # Step 2a: Create MySQL user with appropriate role
        create_mysql_user_with_role(data['email'], data['password'], role, cursor)
        
        conn.commit()
        return jsonify({"message": f"{role} created successfully", "linked_id": new_linked_id}), 201

    except mysql.connector.Error as err:
        conn.rollback()
        if err.errno == 1062: # Duplicate entry
            return jsonify({"error": "Email, license, or phone may already be in use."}), 409
        return jsonify({"error": str(err)}), 500
    finally:
        cursor.close()
        conn.close()

# --- ADMIN: CREATE DOCTOR ---
@app.route('/api/admin/create_doctor', methods=['POST'])
def create_doctor():
    """Creates a new Doctor and associated User account."""
    data = request.json
    
    conn = get_db_connection()
    if not conn: return jsonify({"error": "DB connection failed"}), 500
    cursor = conn.cursor(dictionary=True)
    
    try:
        # Step 1: Create the Doctor
        doctor_query = "INSERT INTO Doctor (doc_name, contact_phone) VALUES (%s, %s)"
        cursor.execute(doctor_query, (data['name'], data['phone']))
        doc_id = cursor.lastrowid

        # Step 2: Create the linked User
        user_query = """
            INSERT INTO User (username, password, role, linked_id)
            VALUES (%s, %s, 'Doctor', %s)
        """
        cursor.execute(user_query, (data['email'], data['password'], doc_id))
        user_id = cursor.lastrowid
        
        # Step 2a: Create MySQL user with doctor_role
        create_mysql_user_with_role(data['email'], data['password'], 'Doctor', cursor)
        
        conn.commit()
        return jsonify({
            "message": "Doctor created successfully",
            "doc_id": doc_id,
            "user_id": user_id
        }), 201

    except mysql.connector.Error as err:
        conn.rollback()
        if err.errno == 1062:  # Duplicate entry
            return jsonify({"error": "Email or phone may already be in use."}), 409
        return jsonify({"error": str(err)}), 500
    finally:
        cursor.close()
        conn.close()

# --- ADMIN: CREATE PHARMACY ---
@app.route('/api/admin/create_pharmacy', methods=['POST'])
def create_pharmacy():
    """Creates a new Pharmacy and associated User account."""
    data = request.json
    
    conn = get_db_connection()
    if not conn: return jsonify({"error": "DB connection failed"}), 500
    cursor = conn.cursor(dictionary=True)
    
    try:
        # Get dummy coordinates based on city and state
        city = data.get('city', '')
        state = data.get('state', '')
        lat, lng = get_dummy_coords(city, state)
        
        # Step 1: Create the Pharmacy (with all available fields including address_state)
        pharmacy_query = """
            INSERT INTO Pharmacy (license_no, pharm_name, contact_phone, 
                                address_street, address_city, address_state, 
                                latitude, longitude)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        """
        cursor.execute(pharmacy_query, (
            data['license'],
            data['name'],
            data['phone'],
            data.get('street', ''),
            city,
            state,
            lat,
            lng
        ))
        pharm_id = cursor.lastrowid

        # Step 2: Create the linked User
        user_query = """
            INSERT INTO User (username, password, role, linked_id)
            VALUES (%s, %s, 'Pharmacy', %s)
        """
        cursor.execute(user_query, (data['email'], data['password'], pharm_id))
        user_id = cursor.lastrowid
        
        # Step 2a: Create MySQL user with pharmacy_role
        create_mysql_user_with_role(data['email'], data['password'], 'Pharmacy', cursor)
        
        conn.commit()
        return jsonify({
            "message": "Pharmacy created successfully",
            "pharm_id": pharm_id,
            "user_id": user_id
        }), 201

    except mysql.connector.Error as err:
        conn.rollback()
        if err.errno == 1062:  # Duplicate entry
            return jsonify({"error": "Email, license, or phone may already be in use."}), 409
        return jsonify({"error": str(err)}), 500
    finally:
        cursor.close()
        conn.close()

# --- ADMIN: CREATE DELIVERY AGENT ---
@app.route('/api/admin/create_agent', methods=['POST'])
def create_agent():
    """Creates a new Delivery Agent and associated User account."""
    data = request.json
    
    conn = get_db_connection()
    if not conn: return jsonify({"error": "DB connection failed"}), 500
    cursor = conn.cursor(dictionary=True)
    
    try:
        # Step 1: Create the Delivery Agent
        agent_query = """
            INSERT INTO Delivery_Agent (agent_name, phone, status)
            VALUES (%s, %s, 'Offline')
        """
        cursor.execute(agent_query, (data['name'], data['phone']))
        agent_id = cursor.lastrowid

        # Step 2: Create the linked User
        user_query = """
            INSERT INTO User (username, password, role, linked_id)
            VALUES (%s, %s, 'Agent', %s)
        """
        cursor.execute(user_query, (data['email'], data['password'], agent_id))
        user_id = cursor.lastrowid
        
        # Step 2a: Create MySQL user with agent_role
        create_mysql_user_with_role(data['email'], data['password'], 'Agent', cursor)
        
        conn.commit()
        return jsonify({
            "message": "Delivery Agent created successfully",
            "agent_id": agent_id,
            "user_id": user_id
        }), 201

    except mysql.connector.Error as err:
        conn.rollback()
        if err.errno == 1062:  # Duplicate entry
            return jsonify({"error": "Email or phone may already be in use."}), 409
        return jsonify({"error": str(err)}), 500
    finally:
        cursor.close()
        conn.close()


# --- (Req 4c) CRUD: MEDICINES ---
@app.route('/api/medicines', methods=['GET', 'POST', 'PUT', 'DELETE'])
def handle_medicines():
    
    if request.method == 'POST':
        # --- CREATE Operation ---
        data = request.json
        query = """
            INSERT INTO Medicine (med_name, type, description, unit, unit_size, prescription_required)
            VALUES (%s, %s, %s, %s, %s, %s)
        """
        params = (
            data.get('med_name'), data.get('type'), data.get('description'),
            data.get('unit'), data.get('unit_size'), bool(data.get('prescription_required'))
        )
        results, err = run_query(query, params)
        if err:
            return jsonify({"error": str(err)}), 400
        return jsonify(results), 201

    elif request.method == 'PUT':
        # --- UPDATE Operation ---
        data = request.json
        query = """
            UPDATE Medicine 
            SET med_name = %s, type = %s, description = %s, prescription_required = %s
            WHERE med_id = %s
        """
        params = (
            data.get('med_name'), data.get('type'), data.get('description'),
            bool(data.get('prescription_required')), data.get('med_id')
        )
        results, err = run_query(query, params)
        if err:
            return jsonify({"error": str(err)}), 400
        return jsonify(results)

    elif request.method == 'DELETE':
        # --- DELETE Operation ---
        med_id = request.args.get('id')
        if not med_id:
            return jsonify({"error": "med_id is required"}), 400
            
        results, err = run_query("DELETE FROM Medicine WHERE med_id = %s", (med_id,))
        if err:
            return jsonify({"error": str(err)}), 500
        return jsonify(results)

    else:
        # --- READ Operation (with search) ---
        search_query = request.args.get('q', '')
        query = "SELECT med_id, med_name, type, description, prescription_required FROM Medicine WHERE med_name LIKE %s"
        meds, err = run_query(query, (f"%{search_query}%",))
        if err:
            return jsonify({"error": str(err)}), 500
        return jsonify(meds)

# --- CUSTOMER DASHBOARD APIS ---

@app.route('/api/customer/cart', methods=['GET', 'POST'])
def handle_cart():
    cust_id = request.args.get('id')
    if not cust_id:
        return jsonify({"error": "Customer ID is required"}), 400

    if request.method == 'POST':
        # --- (Req 4b) ADD TO CART (Calls Procedure) ---
        data = request.json
        med_id = data.get('med_id')
        qty = data.get('qty', 1)

        # First, get the cart_id for this customer
        cart, err = run_query("SELECT cart_id FROM Cart WHERE cust_id = %s", (cust_id,), fetch_one=True)
        if err or not cart:
            return jsonify({"error": "Could not find cart for customer"}), 404

        cart_id = cart['cart_id']
        
        # Now, call the stored procedure
        conn = get_db_connection()
        if not conn: return jsonify({"error": "DB connection failed"}), 500
        cursor = conn.cursor()
        try:
            cursor.callproc('sp_add_cart_item', (cart_id, med_id, qty))
            conn.commit()
            return jsonify({"message": "Item added to cart"})
        except mysql.connector.Error as err:
            conn.rollback()
            return jsonify({"error": str(err)}), 500
        finally:
            cursor.close()
            conn.close()

    else:
        # --- GET CART DETAILS ---
        query = """
            SELECT
                ci.med_id,
                m.med_name,
                ci.quantity,
                s.price,
                (ci.quantity * s.price) AS item_total,
                p.pharm_name AS assigned_pharmacy
            FROM Cart c
            JOIN Cart_Item ci ON c.cart_id = ci.cart_id
            JOIN Medicine m ON ci.med_id = m.med_id
            JOIN Available_Stock s ON ci.assigned_pharmacy_id = s.pharmacy_id AND ci.med_id = s.med_id
            JOIN Pharmacy p ON s.pharmacy_id = p.pharmacy_id
            WHERE c.cust_id = %s;
        """
        cart_items, err = run_query(query, (cust_id,))
        
        cart_details, err2 = run_query(
            "SELECT total_amount, requires_prescription, prescription_status FROM Cart WHERE cust_id = %s",
            (cust_id,), fetch_one=True
        )
        
        if err or err2:
            return jsonify({"error": str(err or err2)}), 500
            
        return jsonify({
            "items": cart_items,
            "details": cart_details
        })

@app.route('/api/cart/process', methods=['POST'])
def process_cart_order():
    # --- (Req 4b) PROCESS ORDER (Calls Procedure) ---
    cust_id = request.args.get('id')
    cart, err = run_query("SELECT cart_id FROM Cart WHERE cust_id = %s", (cust_id,), fetch_one=True)
    if err or not cart:
        return jsonify({"error": "Could not find cart for customer"}), 404
    
    cart_id = cart['cart_id']

    conn = get_db_connection()
    if not conn: return jsonify({"error": "DB connection failed"}), 500
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.callproc('sp_process_cart_to_order_modular', (cart_id,))
        result = {}
        for res in cursor.stored_results():
            result = res.fetchone()
        conn.commit()
        return jsonify(result)
    except mysql.connector.Error as err:
        conn.rollback()
        if err.errno == 1644: # 1644 is the SQLSTATE '45000'
            return jsonify({"error": err.msg}), 400
        else:
            return jsonify({"error": str(err)}), 500
    finally:
        cursor.close()
        conn.close()

@app.route('/api/customer/orders', methods=['GET'])
def get_customer_orders():
    # --- (Req 4e) JOIN QUERY Example ---
    cust_id = request.args.get('id')
    if not cust_id:
        return jsonify({"error": "Customer ID is required"}), 400
        
    query = """
        SELECT 
            o.order_id, 
            o.order_date, 
            o.final_status, 
            o.total_amount,
            so.sub_order_id,
            so.status AS sub_order_status,
            p.pharm_name
        FROM Orders o
        JOIN Sub_Order so ON o.order_id = so.order_id
        JOIN Pharmacy p ON so.pharmacy_id = p.pharmacy_id
        WHERE o.cust_id = %s
        ORDER BY o.order_date DESC, so.sub_order_id ASC;
    """
    orders, err = run_query(query, (cust_id,))
    if err:
        return jsonify({"error": str(err)}), 500
        
    # Serialize date/time objects
    return json.dumps(orders, default=json_serializer), 200, {'Content-Type':'application/json'}


# --- DOCTOR DASHBOARD APIS ---
@app.route('/api/doctor/prescriptions', methods=['GET'])
def get_prescriptions():
    # --- (Req 4a) Get prescriptions for Doctor ---
    doc_id = request.args.get('id')  # Not used currently but kept for consistency
    query = """
        SELECT pr.presc_id, pr.order_id, pr.cust_id, pr.file_path, pr.status, 
               pr.uploaded_at, c.first_name, c.last_name
        FROM Prescription pr
        JOIN Customer c ON pr.cust_id = c.cust_id
        WHERE pr.status = 'To Be Verified'
        ORDER BY pr.uploaded_at ASC;
    """
    prescriptions, err = run_query(query)
    if err:
        return jsonify({"error": str(err)}), 500
    return json.dumps(prescriptions, default=json_serializer), 200, {'Content-Type':'application/json'}

@app.route('/api/doctor/verify', methods=['POST'])
def verify_prescription():
    # --- (Req 4b, 4a) Call verification procedure ---
    data = request.json
    try:
        presc_id = int(data.get('presc_id'))
        doc_id = int(data.get('doc_id')) # The doc who is logged in
        status = data.get('status')
        if not all([presc_id, doc_id, status]) or status not in ['Verified', 'Rejected']:
            return jsonify({"error": "Invalid input"}), 400
    except (ValueError, TypeError):
        return jsonify({"error": "Invalid data types"}), 400

    conn = get_db_connection()
    if not conn: return jsonify({"error": "DB connection failed"}), 500
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.callproc('sp_verify_prescription', (presc_id, doc_id, status))
        conn.commit()
        result = {}
        for res in cursor.stored_results():
            result = res.fetchone()
        return jsonify({"message": f"Prescription {presc_id} {status}", "rows_updated": result.get('rows_updated')})
    except mysql.connector.Error as err:
        conn.rollback()
        return jsonify({"error": str(err)}), 500
    finally:
        cursor.close()
        conn.close()


# --- PHARMACY DASHBOARD APIS ---
@app.route('/api/pharmacy/stock', methods=['GET'])
def get_pharmacy_stock():
    pharm_id = request.args.get('id')
    query = """
        SELECT s.med_id, m.med_name, s.current_stock, s.price
        FROM Available_Stock s
        JOIN Medicine m ON s.med_id = m.med_id
        WHERE s.pharmacy_id = %s
    """
    stock, err = run_query(query, (pharm_id,))
    if err: return jsonify({"error": str(err)}), 500
    return jsonify(stock)

@app.route('/api/pharmacy/orders', methods=['GET'])
def get_pharmacy_orders():
    pharm_id = request.args.get('id')
    query = """
        SELECT so.order_id, so.sub_order_id, so.status, so.sub_total, 
               c.first_name, c.last_name, c.address_street, c.address_city
        FROM Sub_Order so
        JOIN Orders o ON so.order_id = o.order_id
        JOIN Customer c ON o.cust_id = c.cust_id
        WHERE so.pharmacy_id = %s AND so.status IN ('Processing', 'Assigned')
    """
    orders, err = run_query(query, (pharm_id,))
    if err: return jsonify({"error": str(err)}), 500
    return jsonify(orders)

@app.route('/api/pharmacy/orders/status', methods=['PUT'])
def update_pharmacy_order_status():
    """Update the status of a pharmacy sub-order."""
    data = request.json
    order_id = data.get('order_id')
    sub_order_id = data.get('sub_order_id')
    new_status = data.get('status')
    
    if not all([order_id, sub_order_id, new_status]):
        return jsonify({"error": "order_id, sub_order_id, and status are required"}), 400
    
    if new_status not in ['Processing', 'Assigned', 'Shipped', 'Delivered', 'Cancelled']:
        return jsonify({"error": "Invalid status"}), 400
    
    query = """
        UPDATE Sub_Order 
        SET status = %s 
        WHERE order_id = %s AND sub_order_id = %s
    """
    results, err = run_query(query, (new_status, order_id, sub_order_id))
    if err:
        return jsonify({"error": str(err)}), 500
    return jsonify({"message": f"Order status updated to {new_status}"})

@app.route('/api/pharmacy/stock/update', methods=['PUT'])
def update_pharmacy_stock():
    """Update stock and price for a medicine in a pharmacy."""
    pharm_id = request.args.get('id')
    data = request.json
    med_id = data.get('med_id')
    current_stock = data.get('current_stock')
    price = data.get('price')
    
    if not pharm_id:
        return jsonify({"error": "Pharmacy ID is required"}), 400
    if not all([med_id, current_stock is not None, price is not None]):
        return jsonify({"error": "med_id, current_stock, and price are required"}), 400
    
    # Check if stock record exists, if not create it
    check_query = "SELECT * FROM Available_Stock WHERE pharmacy_id = %s AND med_id = %s"
    existing, err = run_query(check_query, (pharm_id, med_id), fetch_one=True)
    
    if err:
        return jsonify({"error": str(err)}), 500
    
    if existing:
        # Update existing stock
        update_query = """
            UPDATE Available_Stock 
            SET current_stock = %s, price = %s 
            WHERE pharmacy_id = %s AND med_id = %s
        """
        results, err = run_query(update_query, (current_stock, price, pharm_id, med_id))
    else:
        # Create new stock record
        insert_query = """
            INSERT INTO Available_Stock (pharmacy_id, med_id, current_stock, price)
            VALUES (%s, %s, %s, %s)
        """
        results, err = run_query(insert_query, (pharm_id, med_id, current_stock, price))
    
    if err:
        return jsonify({"error": str(err)}), 500
    return jsonify({"message": "Stock updated successfully"})


# --- (Req 4d, 4f) REPORTS API ---
@app.route('/api/reports', methods=['GET'])
def get_reports():
    report_name = request.args.get('name')
    query = ""
    
    if report_name == 'aggregate_query':
        # --- (f) AGGREGATE QUERY ---
        query = """
            SELECT p.pharm_name, COUNT(so.sub_order_id) AS total_orders, SUM(so.sub_total) AS total_sales
            FROM Sub_Order so
            JOIN Pharmacy p ON so.pharmacy_id = p.pharmacy_id
            GROUP BY p.pharm_name
            ORDER BY total_sales DESC;
        """
    elif report_name == 'nested_query':
        # --- (d) NESTED QUERY (Subquery) ---
        query = """
            SELECT med_name, type
            FROM Medicine
            WHERE med_id NOT IN (
                SELECT DISTINCT med_id FROM Order_Medicine
            );
        """
    else:
        return jsonify({"error": "Report not found"}), 404

    results, err = run_query(query)
    if err:
        return jsonify({"error": str(err)}), 500
    return json.dumps(results, default=json_serializer), 200, {'Content-Type':'application/json'}


# --- AGENT DASHBOARD APIS ---
@app.route('/api/agent/deliveries', methods=['GET'])
def get_agent_deliveries():
    agent_id = request.args.get('id')
    query = """
        SELECT 
            so.order_id, so.sub_order_id, so.status,
            p.pharm_name, p.address_street AS pickup_address,
            c.first_name, c.address_street AS dropoff_address
        FROM Sub_Order so
        JOIN Pharmacy p ON so.pharmacy_id = p.pharmacy_id
        JOIN Orders o ON so.order_id = o.order_id
        JOIN Customer c ON o.cust_id = c.cust_id
        WHERE so.agent_id = %s AND so.status = 'Assigned'
    """
    deliveries, err = run_query(query, (agent_id,))
    if err: return jsonify({"error": str(err)}), 500
    return jsonify(deliveries)

@app.route('/api/agent/status', methods=['POST'])
def update_agent_status():
    agent_id = request.args.get('id')
    data = request.json
    new_status = data.get('status')
    
    if new_status not in ['Available', 'Busy', 'Offline']:
        return jsonify({"error": "Invalid status"}), 400
        
    results, err = run_query(
        "UPDATE Delivery_Agent SET status = %s WHERE agent_id = %s",
        (new_status, agent_id)
    )
    if err: return jsonify({"error": str(err)}), 500
    return jsonify(results)

@app.route('/api/agent/deliveries/status', methods=['PUT'])
def update_delivery_status():
    """Update the status of a delivery sub-order."""
    agent_id = request.args.get('id')
    data = request.json
    order_id = data.get('order_id')
    sub_order_id = data.get('sub_order_id')
    new_status = data.get('status')
    
    if not agent_id:
        return jsonify({"error": "Agent ID is required"}), 400
    if not all([order_id, sub_order_id, new_status]):
        return jsonify({"error": "order_id, sub_order_id, and status are required"}), 400
    
    if new_status not in ['Processing', 'Assigned', 'Shipped', 'Delivered', 'Cancelled']:
        return jsonify({"error": "Invalid status"}), 400
    
    # Verify that this delivery belongs to the agent
    verify_query = """
        SELECT agent_id FROM Sub_Order 
        WHERE order_id = %s AND sub_order_id = %s
    """
    sub_order, err = run_query(verify_query, (order_id, sub_order_id), fetch_one=True)
    if err:
        return jsonify({"error": str(err)}), 500
    if not sub_order or str(sub_order['agent_id']) != str(agent_id):
        return jsonify({"error": "This delivery does not belong to you"}), 403
    
    query = """
        UPDATE Sub_Order 
        SET status = %s 
        WHERE order_id = %s AND sub_order_id = %s
    """
    results, err = run_query(query, (new_status, order_id, sub_order_id))
    if err:
        return jsonify({"error": str(err)}), 500
    return jsonify({"message": f"Delivery status updated to {new_status}"})


# --- MAIN RUN ---
if __name__ == '__main__':
    app.run(debug=True, port=5000)

