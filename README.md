# 💊 MediQuick: A Medicine Delivery Management System

**MediQuick** is a comprehensive database management system project simulating an online pharmacy and medicine delivery platform. It demonstrates key DBMS concepts like transaction management, data integrity (Triggers), business logic (Stored Procedures), security (MySQL Roles), and complex queries, all accessed through a multi-user Flask web interface.

---

## ✨ Features

The project is built around a secure, role-based architecture and a robust MySQL backend.

### 🔹 Database Core (MySQL)

- **Stored Procedures (SP):** Critical backend logic includes:
  - `sp_assign_single_cart_item` — Assigns each medicine to the **nearest well-stocked pharmacy**.
  - `sp_process_cart_to_order_modular` — Performs validation, stock checks, order creation, and sub-order splitting **inside a transaction**.
  - `sp_verify_prescription` — Allows doctors to approve/reject prescriptions.
  - `sp_assign_delivery_agent` — Automatically picks the nearest available agent.

- **Triggers** maintain data correctness:
  - Auto-update `Cart.total_amount` and `requires_prescription` on any `Cart_Item` change.
  - Create **Low Stock Alerts** when pharmacy inventory falls below threshold.

- **Security:** Implements **MySQL Roles** such as:
  - `customer_role`, `doctor_role`, `pharmacy_role`, `delivery_role`
  - Ensures **principle of least privilege**.

- **Reporting Queries:**
  - Total pharmacy sales + order counts (Admin Dashboard).
  - List of medicines **never sold**.

### 🧩 Application Layer (Flask)

- **Role-Based Interfaces:** Customer, Doctor, Pharmacy, Delivery Agent dashboards.
- **CRUD UI:** Medicines & stock management from Admin/Pharmacy panels.
- **Secure Payment Flow:** `sp_update_payment_status` confirms payment before order processing.

---

## 🛠️ Setup and Installation

### ✅ Prerequisites

- Python **3.x**
- **MySQL 8.0+** (required for roles)
- Flask & MySQL connector (`mysql-connector-python`)

---

### 1) Database Setup

```sql
DROP
