# 💊 MediQuick: A Medicine Delivery Management System

**MediQuick** is a full-stack DBMS project simulating an online pharmacy and medicine delivery workflow.  
It demonstrates **Stored Procedures**, **Triggers**, **MySQL Roles**, **Transactions**, and **Role-based Access** through a Flask-based multi-user web interface.

---

## ✨ Core Highlights

- **MySQL Database Logic**
  - Transaction-based order processing (`sp_process_cart_to_order_modular`)
  - Pharmacy assignment logic based on distance & stock
  - Prescription verification workflow for restricted medicines
  - Delivery agent auto-assignment logic

- **Triggers**
  - Auto-updates cart amount & prescription-flag when cart items change
  - Generates stock alerts when medical stock falls below threshold

- **MySQL Security Roles**
  - `customer_role`, `doctor_role`, `pharmacy_role`, `delivery_role`  
  - Ensures *principle of least privilege*

- **Flask Web Application**
  - 4 dashboards: Customer, Doctor, Pharmacy, Delivery Agent
  - CRUD operations on inventory, orders, and verification flows

---

## 🛠️ Complete Setup & Execution Guide

Follow these steps **in exact order** to set up and run the system.

### ✅ 1. Install Required Software
| Requirement | Notes |
|------------|-------|
| Python **3.x** | Required for Flask application |
| **MySQL Server 8.0+** | Roles will not work on older versions |
| pip | Comes with Python |

---

### 2. Clone / Download Project

```bash
git clone https://github.com/archi829/MediQuick.git
cd mediquick
```
### 3. Database Setup (MySQL)

Open MySQL terminal and create the database:

```sql
DROP DATABASE IF EXISTS mediquick;
CREATE DATABASE mediquick;
USE mediquick;
```

#### 📦 Database Setup

Run the SQL scripts **in the exact order** below:

| Order | File Name               | Purpose                               |
|------:|-------------------------|----------------------------------------|
| 1     | `1_table_creations.sql` | Create tables & constraints            |
| 2     | `2_roles.sql`           | Create roles & admin user              |
| 3     | `3_data_population.sql` | Insert sample data & user accounts     |
| 4     | `4_functions.sql`       | Add helper DB functions                |
| 5     | `5_triggers.sql`        | Add triggers for consistency           |
| 6     | `6_procedures.sql`      | Add stored procedures                  |
| 7 (optional) | `7_tests.sql`    | Validate logic & workflows             |

### Run Using MySQL Workbench **or** Terminal:
```bash
mysql -u root -p mediquick < scriptname.sql
```

### 4. Flask Application Setup
Install Dependencies
`pip install -r requirements.txt`

Update DB Credentials (if needed) in app.py
```sql
db_config = {
    'user': 'admin_user',
    'password': 'adminpass123',
    'host': '127.0.0.1',
    'database': 'mediquick'
}
```

🚀 Run the Application

Start the Flask server: `python app.py`
Open in browser: `http://127.0.0.1:5000/`
