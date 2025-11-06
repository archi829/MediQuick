# **User Accounts and Credentials**

---

## **Customers**

- **User Table**
  - cust1@gmail.com  
  - cust2@gmail.com  
  - cust3@gmail.com

- **MySQL Users**
  - cust1  
  - cust2  
  - cust3

- **Passwords**
  - cust1  
  - cust2  
  - cust3

---

## **Doctors**

- **User Table**
  - doc1@gmail.com  
  - doc2@gmail.com

- **MySQL Users**
  - doc1  
  - doc2

- **Passwords**
  - doc1  
  - doc2

---

## **Pharmacies**

- **User Table**
  - pharm1@gmail.com  
  - pharm2@gmail.com  
  - pharm3@gmail.com

- **MySQL Users**
  - pharm1  
  - pharm2  
  - pharm3

- **Passwords**
  - pharm1  
  - pharm2  
  - pharm3

---

## **Delivery Agents**

- **User Table**
  - agent1@gmail.com  
  - agent2@gmail.com  
  - agent3@gmail.com

- **MySQL Users**
  - agent1  
  - agent2  
  - agent3

- **Passwords**
  - agent1  
  - agent2  
  - agent3
  
---
## MediQuick Project: Personal Revision Notes

### 1. Python Environment: The "Module Not Found" Error

- **Problem:** Tried to run `python app.py` but got `ModuleNotFoundError: No module named 'mysql'`.
- **Fix:** The Python packages (Flask, mysql-connector, etc.) weren't installed in the active virtual environment.
- **Key Takeaway:** Always activate the virtual environment (`.\venv\Scripts\activate`) and install packages using `pip install -r requirements.txt`. The `requirements.txt` file is the map to all necessary libraries.

---

### 2. Front-End Bug: All Medicines "Out of Stock"

- **Problem:** The customer dashboard showed "Out of Stock" for every medicine, even when the database had stock.
- **Reason:** The front-end (`customer_dashboard.html`) expected a `total_stock` value for each medicine, but the API endpoint in `app.py` (`/api/medicines`) was only selecting from the `Medicine` table and not providing any stock information.
- **Fix:** Rewrote the SQL query for the `/api/medicines` endpoint in `app.py`. The new query joins `Medicine` with `Available_Stock`, using `SUM(av.current_stock)` and `GROUP BY` to calculate the *total stock* from all pharmacies.
- **Key Takeaway:** The data your API sends **must** match what your front-end HTML/JS expects. This was a mismatch between the `app.py` API and the `customer_dashboard.html` template.

---

### 3. Back-End Bug: "My Orders" Page Crash (500 Error)

- **Problem:** Loading the "My Orders" page (`/customer_orders`) caused a 500 Internal Server Error. The console showed `TypeError: Type <class 'decimal.Decimal'> not serializable`.
- **Reason:** The database returns money (like `total_amount`) as a precise `Decimal` type. Python's `json` library doesn't know how to convert `Decimal` to text for the API response.
- **Fix:**
  1. Imported `from decimal import Decimal` at the top of `app.py`.
  2. Updated the `json_serializer` helper function in `app.py` to check `isinstance(obj, Decimal)` and convert it to a simple `float(obj)`.
- **Key Takeaway:** This is a common **data type serialization** problem. You must teach your back-end API how to handle special data types (like `Decimal` or `datetime`) before sending them as JSON.

---

### 4. Feature: Admin Assigns Agent

- **Problem:** Agent assignment was a manual SQL process (`CALL sp_assign_delivery_agent`). I wanted a button in the Admin Portal to do this.
- **Fix:** This was a full-stack feature implemented in 3 parts:
  1. **Database:** Wrote a new, safer procedure `sp_admin_assign_agent` that takes `order_id` and `sub_order_id` to assign the *first available* agent.
  2. **Back-End (`app.py`):** Added two new API routes:
     - `GET /api/admin/unassigned_orders`: Fetches all orders with `status = 'Processing'`.
     - `POST /api/admin/assign_agent`: Calls the new `sp_admin_assign_agent` procedure.
  3. **Front-End (`admin_create_user.html`):** Added a new HTML section. Wrote JavaScript to fetch orders from the `GET` route and then call the `POST` route on a button click.
- **Connection:** This is the perfect example of the full stack working together: **HTML Button → JS Fetch → Flask API → SQL Procedure**.

---

### 5. Feature: "Pay" Button Logic

- **Problem:** I wanted the "Checkout" button to be disabled until the user first clicked a "Pay" button.
- **Fix:** This was a **front-end only** change in `customer_dashboard.html`.
  1. Modified `loadCart()` to always render the "Checkout" button with the `disabled` attribute.
  2. Created a new JavaScript function `handlePayment()`.
  3. When the "Pay" button is clicked, `handlePayment()` runs, disables the "Pay" button, and then finds the "Checkout" button by its ID and *removes* the `disabled` attribute.
- **Key Takeaway:** You can create complex UI flows and logic using just HTML and JavaScript (DOM manipulation) without needing to change the back-end at all.

---

### 6. Logic Connection: Agent Assignment Flow

- **Problem:** How does the agent *know* they have an order?
- **Connection:**
  1. A Customer checks out, creating a `Sub_Order` with `status = 'Processing'`.
  2. The Admin clicks "Assign Agent" in their portal.
  3. This calls `sp_admin_assign_agent`, which updates the `Sub_Order`'s `status` to `'Assigned'` and links an `agent_id`.
  4. When the Agent logs in, their dashboard (`agent_dashboard.html`) calls `/api/agent/deliveries`.
  5. This API query in `app.py` specifically selects orders `WHERE so.agent_id = %s AND so.status = 'Assigned'`.
  - **Result:** The order only appears on the agent's dashboard *after* the admin has assigned it.
