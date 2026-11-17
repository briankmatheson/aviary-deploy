"""Copy a Drone SQLite database into the Postgres schema Drone itself created.
Every table but `migrations`; the target tables are emptied first; booleans
and blobs are converted by the target column's type; sequences are moved past
the copied ids. One transaction: all of it or none."""
import os, sqlite3, sys
import psycopg

src = sqlite3.connect(f"file:{sys.argv[1]}?mode=ro", uri=True)
src.row_factory = sqlite3.Row
dst = psycopg.connect(os.environ["PG_DSN"])
with dst, dst.cursor() as cur:
    cur.execute("select table_name from information_schema.tables where table_schema='public'")
    have = {r[0] for r in cur.fetchall()}
    tables = [r[0] for r in src.execute("select name from sqlite_master where type='table' and name not like 'sqlite_%'")
              if r[0] != "migrations"]
    missing = [t for t in tables if t not in have]
    if missing:
        sys.exit(f"tables not in postgres: {missing}")
    cur.execute("truncate " + ", ".join(tables) + " restart identity cascade")
    left, done = list(tables), {}
    while left:
        progressed = False
        for t in list(left):
            cur.execute("select column_name, data_type from information_schema.columns where table_schema='public' and table_name=%s", (t,))
            types = dict(cur.fetchall())
            cols = [c[1] for c in src.execute(f"pragma table_info({t})")]
            extra = [c for c in cols if c not in types]
            if extra:
                sys.exit(f"{t}: columns not in postgres: {extra}")
            def conv(col, v):
                ty = types[col]
                if v is None:
                    return None
                if ty == "boolean":
                    return bool(v)
                if ty == "bytea":
                    return v if isinstance(v, bytes) else str(v).encode()
                if isinstance(v, bytes):
                    return v.decode("utf-8", "replace")
                if isinstance(v, str):
                    return v.replace("\x00", "")
                return v
            rows = [tuple(conv(c, r[c]) for c in cols) for r in src.execute(f"select * from {t}")]
            try:
                with dst.transaction():
                    if rows:
                        cur.executemany(f"insert into {t} ({', '.join(cols)}) values ({', '.join(['%s'] * len(cols))})", rows)
            except psycopg.errors.ForeignKeyViolation:
                continue   # its parent table has not been copied yet
            done[t] = len(rows); left.remove(t); progressed = True
        if not progressed:
            sys.exit(f"could not order: {left}")
    # sequences past the copied ids
    cur.execute("""select c.table_name, c.column_name, pg_get_serial_sequence(c.table_name, c.column_name)
                   from information_schema.columns c where c.table_schema='public' and c.column_default like 'nextval%%'""")
    for t, col, seq in cur.fetchall():
        if seq and t in done:
            cur.execute(f"select setval(%s, greatest((select coalesce(max({col}), 0) from {t}), 1), (select count(*) > 0 from {t}))", (seq,))
    for t in sorted(done):
        cur.execute(f"select count(*) from {t}")
        n = cur.fetchone()[0]
        print(f"  {t}: {done[t]} -> {n}" + ("" if n == done[t] else "  MISMATCH"))
        if n != done[t]:
            sys.exit("row counts differ")
print("committed")
