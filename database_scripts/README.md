# Database Scripts

This folder contains all the SQL scripts needed to build, populate, and test the project database.

## Execution Order

To create the database from scratch, run the files in the following order:

1.  `1_table_creations.sql` - (Creates all table structures, keys, and constraints)
2.  `2_roles.sql` - (Creates MySQL roles and permissions - MUST run before data population)
3.  `3_data_population.sql` - (Inserts all seed data including User accounts and MySQL users with roles)
4.  `4_functions.sql` - (Creates all stored functions)
5.  `5_triggers.sql` - (Adds the triggers to the tables)
6.  `6_procedures.sql` - (Creates all stored procedures)

---

## Testing

After running all the setup scripts (1-6), you can run `7_tests.sql` to verify that the triggers, functions, and procedures are working as expected.

---

## Complete Database Refresh

If you need to completely reset the database (drops and recreates everything), run this SQL first:

```sql
DROP DATABASE IF EXISTS mediquick;
CREATE DATABASE mediquick;
USE mediquick;
```

Then run scripts 1-6 in order.

---

## User Accounts

The `3_data_population.sql` script creates the following test user accounts:

### Customers:
- `cust1@gmail.com` / `cust1` (Customer ID: 1)
- `cust2@gmail.com` / `cust2` (Customer ID: 2)
- `cust3@gmail.com` / `cust3` (Customer ID: 3)

### Doctors:
- `doc1@gmail.com` / `doc1` (Doctor ID: 1)
- `doc2@gmail.com` / `doc2` (Doctor ID: 2)

### Pharmacies:
- `pharm1@gmail.com` / `pharm1` (Pharmacy ID: 1)
- `pharm2@gmail.com` / `pharm2` (Pharmacy ID: 2)
- `pharm3@gmail.com` / `pharm3` (Pharmacy ID: 3)

### Delivery Agents:
- `agent1@gmail.com` / `agent1` (Agent ID: 1)
- `agent2@gmail.com` / `agent2` (Agent ID: 2)
- `agent3@gmail.com` / `agent3` (Agent ID: 3)

All users have corresponding MySQL user accounts with appropriate roles for database-level security. These accounts can be used to log in through the Flask application.

---

## Important Notes

- **Roles must be created before data population** - Script `2_roles.sql` must be run before `3_data_population.sql` because the data population script creates MySQL users with roles.
- **Admin User** - The Flask app uses `admin_user@localhost` with password `adminpass123` for database connections (created in `2_roles.sql`).
- **MySQL 8.0+ Required** - Roles feature requires MySQL 8.0 or higher. If using an older version, the role creation will fail but the app will continue to work.
