struct Message {
  string username;
  string body;
  long sentAt;
}

class Database {
  import sql = d2sqlite3;
  import config;
  import arsd.argon2;

  public {
    this(Config conf) {
      db = sql.Database(conf["db_file"]);

      db.run(
        `CREATE TABLE IF NOT EXISTS users (
          username TEXT NOT NULL UNIQUE,
          pwd_hash TEXT NOT NULL
        )`
      );

      db.run("PRAGMA foreign_keys = ON;");

      db.run(
        `CREATE TABLE IF NOT EXISTS groups (
          id   INTEGER PRIMARY KEY,
          name TEXT NOT NULL UNIQUE
        )`
      );

      db.run(`
        CREATE TABLE IF NOT EXISTS messages (
          id        INTEGER PRIMARY KEY,
          group_id  INTEGER NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
          username  TEXT NOT NULL,
          body      TEXT NOT NULL,
          sent_at   INTEGER NOT NULL DEFAULT (unixepoch())
        )`
      );

      db.run("CREATE INDEX IF NOT EXISTS idx_messages_group ON messages(group_id, id)");
    }

    bool addUser(string username, string unhashed_pwd) {
      if (userExists(username)) {
        return checkLogin(username, unhashed_pwd);
      }

      string hash = encode(unhashed_pwd);

      // I have no clue what im doing
      db.execute(
        "INSERT INTO users (username, pwd_hash) VALUES (?, ?)",
        username, hash
      );

      return true;
    }

    bool checkLogin(string username, string pwd) {
      auto rows = db.execute("SELECT pwd_hash FROM users WHERE username = ?", username);
      if (rows.empty) return false;

      string stored = rows.front["pwd_hash"].as!string;
      return verify(stored, pwd);
    }

    bool userExists(string username) {
      return db.execute(
        "SELECT EXISTS(SELECT 1 FROM users WHERE username = ?)",
        username
      ).oneValue!bool;
    }

    bool groupExists(string name) {
      return db.execute(
        "SELECT EXISTS(SELECT 1 FROM groups WHERE name = ?)",
        name
      ).oneValue!bool;
    }

    bool addGroup(string name) {
      try {
        db.execute("INSERT INTO groups (name) VALUES (?)", name);
        return true;
      } catch (sql.SqliteException e) {
        return false;
      }
    }

    bool sendMessage(string group, string username, string body) {
      db.execute(
        `INSERT INTO messages (group_id, username, body)
         SELECT id, ?, ? FROM groups WHERE name = ?`,
        username, body, group
      );

      return db.changes > 0;
    }

    Message[] getGroupMessages(string group, int count) {
      Message[] result;

      auto rows = db.execute(
        `SELECT username, body, sent_at FROM (
           SELECT m.id, m.username, m.body, m.sent_at
           FROM messages m
           JOIN groups g ON g.id = m.group_id
           WHERE g.name = ?
           ORDER BY m.id DESC
           LIMIT ?
         ) ORDER BY id`,
        group, count
      );

      foreach (row; rows) {
        result ~= Message(
          row["username"].as!string,
          row["body"].as!string,
          row["sent_at"].as!long
        );
      }

      return result;
    }
  }

  private {
    sql.Database db;
  }
}
