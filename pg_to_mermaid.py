import re
import sys

if len(sys.argv) < 2:
    print("Usage: python3 pg_to_mermaid.py schema.sql")
    sys.exit(1)

schema_file = sys.argv[1]

with open(schema_file, "r") as f:
    sql = f.read()

tables = {}
primary_keys = {}
foreign_keys = []

# --------------------------
# 1. Extract Tables
# --------------------------
table_pattern = re.finditer(
    r'CREATE TABLE\s+([\w\."]+)\s*\((.*?)\);\n',
    sql,
    re.S
)

for match in table_pattern:
    full_table_name = match.group(1)
    table_name = full_table_name.split(".")[-1].replace('"', "")
    body = match.group(2)

    columns = []

    for line in body.split("\n"):
        line = line.strip().rstrip(",")

        if (
            not line
            or line.startswith("CONSTRAINT")
            or line.startswith("PRIMARY KEY")
            or line.startswith("FOREIGN KEY")
        ):
            continue

        col_match = re.match(r'"?([\w]+)"?\s+([\w\(\)]+)', line)
        if col_match:
            col_name = col_match.group(1)
            col_type = col_match.group(2)
            columns.append((col_name, col_type))

    tables[table_name] = columns

# --------------------------
# 2. Extract Primary Keys
# --------------------------
pk_pattern = re.finditer(
    r'ALTER TABLE ONLY\s+([\w\."]+).*?PRIMARY KEY \((.*?)\);',
    sql,
    re.S
)

for match in pk_pattern:
    full_table_name = match.group(1)
    table_name = full_table_name.split(".")[-1].replace('"', "")
    pk_cols = [c.strip().replace('"', "") for c in match.group(2).split(",")]
    primary_keys[table_name] = pk_cols

# --------------------------
# 3. Extract Foreign Keys
# --------------------------
fk_pattern = re.finditer(
    r'ALTER TABLE ONLY\s+([\w\."]+).*?FOREIGN KEY \((.*?)\)\s+REFERENCES\s+([\w\."]+)\((.*?)\)',
    sql,
    re.S
)

for match in fk_pattern:
    source_table = match.group(1).split(".")[-1].replace('"', "")
    source_col = match.group(2).replace('"', "").strip()
    target_table = match.group(3).split(".")[-1].replace('"', "")
    target_col = match.group(4).replace('"', "").strip()

    foreign_keys.append((source_table, source_col, target_table, target_col))

# --------------------------
# 4. Print Mermaid ERD
# --------------------------
print("erDiagram\n")

for table, columns in tables.items():
    print(f"    {table} {{")
    for col_name, col_type in columns:
        label = ""
        if table in primary_keys and col_name in primary_keys[table]:
            label = " PK"
        print(f"        {col_type} {col_name}{label}")
    print("    }\n")

for source_table, source_col, target_table, target_col in foreign_keys:
    print(f"    {target_table} ||--o{{ {source_table} : \"{source_col}\"")
