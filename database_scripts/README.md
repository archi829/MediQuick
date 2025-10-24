# Database Scripts

This folder contains all the SQL scripts needed to build, populate, and test the project database.

## Execution Order

To create the database from scratch, run the files in the following order:

1.  `1_table_creations.sql` - (Creates all table structures, keys, and constraints)
2.  `2_data_population.sql` - (Inserts all seed data into the tables)
3.  `3_triggers.sql` - (Adds the triggers to the tables)
4.  `4_functions.sql` - (Creates all stored functions)
5.  `5_procedures.sql` - (Creates all stored procedures)

---

## Testing

After running all the setup scripts (1-5), you can run `6_final_tests.sql` to verify that the triggers, functions, and procedures are working as expected.