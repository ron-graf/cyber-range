"""
SmallCo Internal Portal - Intentionally Vulnerable Web Application

WARNING: This application contains deliberate security vulnerabilities
for cyber range training. NEVER deploy on a real network.

Vulnerabilities:
  1. SQL Injection in login and search
  2. Command injection in network diagnostic tool
  3. Hardcoded database credentials
  4. Directory traversal in file download
"""

import os
import sqlite3
import subprocess
from flask import Flask, request, render_template_string, redirect, session, g

app = Flask(__name__)
app.secret_key = "smallco-super-secret-key-2026"

DB_PATH = "/opt/smallco/portal.db"

LAYOUT = """
<!DOCTYPE html>
<html>
<head><title>SmallCo Internal Portal</title>
<style>
  body { font-family: Arial, sans-serif; margin: 0; background: #f4f4f4; }
  .nav { background: #2c3e50; color: white; padding: 12px 24px; display: flex; justify-content: space-between; align-items: center; }
  .nav a { color: #ecf0f1; text-decoration: none; margin-left: 16px; }
  .container { max-width: 800px; margin: 32px auto; background: white; padding: 32px; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); }
  input, button { padding: 8px 12px; margin: 4px 0; }
  input[type=text], input[type=password] { width: 280px; }
  button { background: #2c3e50; color: white; border: none; cursor: pointer; border-radius: 4px; }
  table { border-collapse: collapse; width: 100%; }
  th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
  th { background: #2c3e50; color: white; }
  .error { color: #e74c3c; }
  .success { color: #27ae60; }
  pre { background: #ecf0f1; padding: 12px; border-radius: 4px; overflow-x: auto; }
</style>
</head>
<body>
<div class="nav">
  <b>SmallCo Portal</b>
  <div>
    <a href="/">Home</a>
    <a href="/employees">Employees</a>
    <a href="/diagnostics">Diagnostics</a>
    <a href="/files">Files</a>
    {% if session.get('user') %}<a href="/logout">Logout ({{ session['user'] }})</a>{% else %}<a href="/login">Login</a>{% endif %}
  </div>
</div>
<div class="container">{{ content }}</div>
</body>
</html>
"""


def get_db():
    if "db" not in g:
        g.db = sqlite3.connect(DB_PATH)
        g.db.row_factory = sqlite3.Row
    return g.db


@app.teardown_appcontext
def close_db(exception):
    db = g.pop("db", None)
    if db is not None:
        db.close()


def init_db():
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.executescript("""
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY,
            username TEXT UNIQUE,
            password TEXT,
            role TEXT
        );
        CREATE TABLE IF NOT EXISTS employees (
            id INTEGER PRIMARY KEY,
            name TEXT,
            department TEXT,
            email TEXT,
            notes TEXT
        );

        INSERT OR IGNORE INTO users VALUES (1, 'admin', 'admin123', 'admin');
        INSERT OR IGNORE INTO users VALUES (2, 'jsmith', 'password1', 'user');
        INSERT OR IGNORE INTO users VALUES (3, 'svc_backup', 'Backup2026!', 'service');

        INSERT OR IGNORE INTO employees VALUES (1, 'John Smith', 'IT', 'jsmith@smallco.local',
            'SSH key copied to file-server. Uses same password everywhere.');
        INSERT OR IGNORE INTO employees VALUES (2, 'Jane Doe', 'Finance', 'jdoe@smallco.local',
            'Has access to admin-server for quarterly reports.');
        INSERT OR IGNORE INTO employees VALUES (3, 'Bob Wilson', 'IT', 'bwilson@smallco.local',
            'Manages database backups. Check /opt/backups for scripts.');
        INSERT OR IGNORE INTO employees VALUES (4, 'Alice Chen', 'Engineering', 'achen@smallco.local',
            'Runs internal tools on port 8080.');
        INSERT OR IGNORE INTO employees VALUES (5, 'svc_backup', 'IT', 'svc_backup@smallco.local',
            'Service account for nightly DB backups to file-server (10.0.2.30). Creds in /opt/backups/config.ini');
    """)
    conn.close()


def render(content):
    return render_template_string(LAYOUT, content=content, session=session)


@app.route("/")
def index():
    return render("<h2>Welcome to SmallCo Internal Portal</h2><p>Use the navigation above to access company resources.</p>")


# --- VULN 1: SQL Injection in login ---
@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "GET":
        return render("""
            <h2>Login</h2>
            <form method="POST">
                <div>Username: <input type="text" name="username"></div>
                <div>Password: <input type="password" name="password"></div>
                <div><button type="submit">Login</button></div>
            </form>
        """)

    username = request.form.get("username", "")
    password = request.form.get("password", "")

    # VULNERABLE: SQL injection via string formatting
    db = get_db()
    query = f"SELECT * FROM users WHERE username='{username}' AND password='{password}'"
    try:
        user = db.execute(query).fetchone()
        if user:
            session["user"] = user["username"]
            session["role"] = user["role"]
            return redirect("/")
        return render('<h2>Login</h2><p class="error">Invalid credentials.</p><a href="/login">Try again</a>')
    except Exception as e:
        return render(f'<h2>Login</h2><p class="error">Database error: {e}</p><a href="/login">Try again</a>')


@app.route("/logout")
def logout():
    session.clear()
    return redirect("/")


# --- VULN 2: SQL Injection in employee search ---
@app.route("/employees")
def employees():
    search = request.args.get("q", "")
    db = get_db()

    if search:
        # VULNERABLE: SQL injection in search
        query = f"SELECT * FROM employees WHERE name LIKE '%{search}%' OR department LIKE '%{search}%' OR notes LIKE '%{search}%'"
    else:
        query = "SELECT * FROM employees"

    try:
        rows = db.execute(query).fetchall()
        table_rows = "".join(
            f"<tr><td>{r['name']}</td><td>{r['department']}</td><td>{r['email']}</td><td>{r['notes']}</td></tr>"
            for r in rows
        )
        return render(f"""
            <h2>Employee Directory</h2>
            <form method="GET"><input type="text" name="q" value="{search}" placeholder="Search..."> <button>Search</button></form>
            <table><tr><th>Name</th><th>Department</th><th>Email</th><th>Notes</th></tr>{table_rows}</table>
        """)
    except Exception as e:
        return render(f'<h2>Employee Directory</h2><p class="error">Error: {e}</p>')


# --- VULN 3: Command injection in diagnostics ---
@app.route("/diagnostics", methods=["GET", "POST"])
def diagnostics():
    output = ""
    if request.method == "POST":
        host = request.form.get("host", "")
        # VULNERABLE: command injection via shell=True
        try:
            result = subprocess.run(
                f"ping -c 2 {host}",
                shell=True,
                capture_output=True,
                text=True,
                timeout=10,
            )
            output = f"<pre>{result.stdout}\n{result.stderr}</pre>"
        except subprocess.TimeoutExpired:
            output = '<p class="error">Command timed out.</p>'

    return render(f"""
        <h2>Network Diagnostics</h2>
        <p>Ping a host to check connectivity:</p>
        <form method="POST">
            <input type="text" name="host" placeholder="e.g. 10.0.2.10">
            <button>Ping</button>
        </form>
        {output}
    """)


# --- VULN 4: Directory traversal in file download ---
@app.route("/files")
def files():
    filename = request.args.get("f")
    if filename:
        # VULNERABLE: directory traversal
        filepath = f"/opt/smallco/files/{filename}"
        try:
            with open(filepath) as fh:
                content = fh.read()
            return render(f"<h2>File: {filename}</h2><pre>{content}</pre><a href='/files'>Back</a>")
        except Exception as e:
            return render(f'<p class="error">Cannot read file: {e}</p><a href="/files">Back</a>')

    return render("""
        <h2>Shared Files</h2>
        <ul>
            <li><a href="/files?f=welcome.txt">welcome.txt</a></li>
            <li><a href="/files?f=network_map.txt">network_map.txt</a></li>
            <li><a href="/files?f=it_contacts.txt">it_contacts.txt</a></li>
        </ul>
    """)


if __name__ == "__main__":
    init_db()
    app.run(host="0.0.0.0", port=8080)
