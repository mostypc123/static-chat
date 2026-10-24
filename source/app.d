import vibe.vibe;
import utils;
import config;
import database;
import themes;

void main() {
  auto config = new Config;
  auto router = new URLRouter;
  auto db = new Database(config);
  utils.db = db;

  auto settings = new HTTPServerSettings;
  settings.port = 8080;
  settings.bindAddresses = ["127.0.0.1"];
  settings.sessionStore = new MemorySessionStore;
  if (config["devmode"] != "true") {
    settings.sessionOptions = SessionOption.httpOnly | SessionOption.secure;
  } else {
    logWarn("Dev mode is enabled.");
  }

  router.get("/", (req, res) @trusted {
    res.writeHtmlBody(
      html(`
        <h1>Welcome to Static Chat!</h1>
        <p>Static Chat is a chat app that works with ZERO javascript. Isnt that kinda cool?</p>

        <form action="/register" method="POST">
          <input name="user" placeholder="username" required>
          <input name="password" type="password" placeholder="password" required>
          <button type="submit">Continue</button>
        </form>

        <hr>
        <small>Cookies: We simply use a session cookie, otherwise theres not any other one.</small>
      `, req.session ? req.session.get!string("user") : null)
    );
  });

  router.post("/register", (req, res) @trusted {
    string username;
    string password;
    try {
      username = req.form["user"];
      password = req.form["password"]; // will be hashed by addUser
    } catch (Exception e) {
      res.writeHtmlBody(
        html(`
          <p>did not provide data to form.</p>
        `, req.session ? req.session.get!string("user") : null)
      );
      return;
    }

    bool ok = db.addUser(username, password);
    if (ok) {
      auto session = res.startSession();
      session.set("user", username);
      res.redirect("/welcome");
    } else {
      res.writeHtmlBody(
        html(`
          <p>Failed to register / login. <a href="/">Try again</a>.</p>
        `, req.session ? req.session.get!string("user") : null)
      );
    }
  });

  router.get("/welcome", (req, res) @trusted {
    if (!req.session) {
      res.redirect("/");
      return;
    }

    auto user = req.session.get!string("user");

    res.writeHtmlBody(
      html(`
        <h1>Welcome to Static Chat, <small>` ~ htmlEscape(user) ~ `</small>!</h1>
        <details>
          <summary>Settings</summary>
          <details>
            <summary>Appearance</summary>
            <details>
              <summary>Theme</summary>
              <form action="/settings/theme" method="POST">
                <input placeholder="theme url" name="theme_url" value="` ~
                  htmlEscape(db.getUsersTheme(user))
                 ~ `">
                <button type="submit">Use</button>
              </form>
            </details>
          </details>
          <details>
            <summary>Authentication</summary>
            <details>
              <summary>Password</summary>
              Forgot your password? Contact the admin:<br>
              ` ~ config["contact"] ~ `
            </details>
            <details>
              <summary>Auth token</summary>
              <blockquote>
                <b>IMPORTANT:</b> do not share your token to anyone unless you know what youre doing!<br>
                Tokens are mainly used to create bots, as a normal user you probably wont need them.
              </blockquote>
              <form action="/settings/api/token/create" method="POST">
                <button type="submit">Create a token</button>
              </form>
              <br>
              <form action="/settings/api/token/delete" method="POST">
                <input name="token" type="password" placeholder="token">
                <button type="submit">Delete token</button>
              </form>
            </details>
          </details>
        </details>
        <form class="bottom" action="/chat/view" method="POST">
          # <input autofocus name="grp" placeholder="group name">
          <button type="submit">Continue</button>
        </form>
      `, req.session ? req.session.get!string("user") : null)
    );
  });

  router.post("/chat/view", (req, res) @trusted {
    import std.conv : to;

    if (!req.session) {
      res.redirect("/");
      return;
    }

    // keep the raw name for the DB, escape only when rendering
    auto group = req.form["grp"];
    if (group.length == 0) {
      res.redirect("/welcome");
      return;
    }

    auto show = (db.groupExists(group) ? "" : htmlEscape("<NEW GROUP>")) ~ "# <b>" ~ htmlEscape(group) ~ "</b>";

    // create if doesnt exist
    db.addGroup(group);

    auto messages = db.getGroupMessages(group, 25);
    string msg_list;
    foreach (msg; messages) {
      msg_list ~= to!string(msg.sentAt) ~ " <b>" ~ htmlEscape(msg.username) ~ "</b> " ~ htmlEscape(msg.body) ~ "<br>";
    }

    res.writeHtmlBody(
      html(`
        <nav>` ~ show ~ ` | <a href="/welcome">home</a></nav>
        <hr>
        ` ~ msg_list ~ `
        <hr>
        <form class="bottom" action="/chat/send" method="POST">
          <input autofocus name="body" placeholder="message #` ~ htmlEscape(group) ~ `">
          <input type="hidden" name="grp" value="` ~ htmlEscape(group) ~ `">
          <button type="submit">Send</button>
        </form>
      `, req.session ? req.session.get!string("user") : null)
    );
  });

  router.post("/chat/send", (req, res) @trusted {
    if (!req.session) {
      res.redirect("/");
      return;
    }
    db.sendMessage(req.form["grp"], req.session.get!string("user"), req.form["body"]);
    res.redirect("/chat/view", HTTPStatus.temporaryRedirect);
  });

  router.post("/api/chat/send", (req, res) @trusted {
    auto json = req.json;

    string apikey;
    string body;
    string grp;

    try {
      apikey = json["token"].get!string;
      body = json["body"].get!string;
      grp = json["grp"].get!string;
    } catch (Exception e) {
      res.writeJsonBody([
        "ok": "false",
        "message": "no token / body / grp"
      ]);
      return;
    }

    auto user = db.getTokenOwner(apikey);

    if (user == "") {
      res.writeJsonBody([
        "ok": "false",
        "message": "invalid token"
      ]);
      return;
    }

    if (!db.groupExists(grp)) {
      res.writeJsonBody([
        "ok": "false",
        "message": "no such grp"
      ]);
      return;
    }

    if (!db.sendMessage(grp, user, body)) {
      res.writeJsonBody([
        "ok": "false",
        "message": "insert msg fail"
      ]);
      return;
    }

    res.writeJsonBody(["ok": "true"]);
  });

  router.post("/settings/theme", (req, res) @trusted {
    if (!req.session) {
      res.redirect("/");
      return;
    }
    db.setUsersTheme(req.session.get!string("user"), req.form["theme_url"]);
    res.writeHtmlBody(
      html(`
        <p>Your theme has been set. <a href="/welcome">Return home.</a></p>
      `, req.session ? req.session.get!string("user") : null)
    );
  });

  router.post("/settings/api/token/create", (req, res) @trusted {
    if (!req.session) {
      res.redirect("/");
      return;
    }
    auto user = req.session.get!string("user");
    string token = db.addToken(user);

    if (token != "") {
      res.writeHtmlBody(
        html(`
          <p>Your token has been created: <code>` ~ token ~ `</code>. <a href="/welcome">Return home.</a></p>
        `, req.session ? req.session.get!string("user") : null)
      );
    } else {
      res.writeHtmlBody(
        html(`
          <p>Your token has not been created successfully. <a href="/welcome">Return home.</a></p>
        `, req.session ? req.session.get!string("user") : null)
      );
    }
  });

  router.post("/settings/api/token/delete", (req, res) @trusted {
    if (!req.session) {
      res.redirect("/");
      return;
    }
    auto user = req.session.get!string("user");
    auto token = req.form["token"];

    if (db.getTokenOwner(token) != user) {
      res.writeHtmlBody(
        html(`
          <p>Your token has not been deleted successfully because you dont own it.
            <a href="/welcome">Return home.</a></p>
        `, req.session ? req.session.get!string("user") : null)
      );
      return;
    }

    if (db.removeToken(token)) {
      res.writeHtmlBody(
        html(`
          <p>Your token has been deleted: <code>` ~ token ~ `</code>. <a href="/welcome">Return home.</a></p>
        `, req.session ? req.session.get!string("user") : null)
      );
    } else {
      res.writeHtmlBody(
        html(`
          <p>Your token has not been deleted successfully. <a href="/welcome">Return home.</a></p>
        `, req.session ? req.session.get!string("user") : null)
      );
    }
  });

  router.get("/themes/default.css", &themes.defTheme);
  router.get("/themes/light.css", &themes.lightTheme);

  auto listener = listenHTTP(settings, router);
  scope (exit) listener.stopListening();

  runApplication();
}
