module database;

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
          theme TEXT NOT NULL,
          pwd_hash TEXT NOT NULL
        )`
      );

      db.run("PRAGMA foreign_keys = ON;");

      db.run(
        `CREATE TABLE IF NOT EXISTS groups (
          name TEXT NOT NULL UNIQUE,
          id   INTEGER PRIMARY KEY
        )`
      );

      db.run(`
        CREATE TABLE IF NOT EXISTS tokens (
          token_uuid TEXT NOT NULL UNIQUE,
          name TEXT NOT NULL
        )
      `);

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
        "INSERT INTO users (username, pwd_hash, theme) VALUES (?, ?, ?)",
        username, hash, "/themes/default.css"
      );

      return true;
    }

    string getUsersTheme(string username) {
      auto rows = db.execute("SELECT theme FROM users WHERE username = ?", username);
      if (rows.empty) return "/themes/default.css";

      string stored = rows.front["theme"].as!string;
      return stored;
    }

    bool setUsersTheme(string username, string theme) {
      db.execute("UPDATE users SET theme = ? WHERE username = ?", theme, username);
      return db.changes > 0;
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

    string addToken(string user) {
      import std.uuid;
      auto id = randomUUID();
      try {
        db.execute("INSERT INTO tokens (name, token_uuid) VALUES (?, ?)", user, id.toString());
        return id.toString();
      } catch (sql.SqliteException e) {
        return "";
      }
    }

    string getTokenOwner(string token) {
      try {
        auto rows = db.execute("SELECT name FROM tokens WHERE token_uuid = ?", token);
        if (rows.empty) return "";
        return rows.front["name"].as!string;
      } catch (sql.SqliteException e) {
        return "";
      }
    }

    bool removeToken(string token) {
      try {
        db.execute("DELETE FROM tokens WHERE token_uuid = ?", token);
        return db.changes() > 0;
      } catch (sql.SqliteException e) {
        return false;
      }
    }

    int removeUserTokens(string user) {
      try {
        db.execute("DELETE FROM tokens WHERE name = ?", user);
        return db.changes();
      } catch (sql.SqliteException e) {
        return 0;
      }
    }
  }

  private {
    sql.Database db;
  }
}
