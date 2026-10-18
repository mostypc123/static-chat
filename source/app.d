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
    auto username = req.form["user"];
    auto password = req.form["password"]; // will be hashed by addUser

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
        <form action="/chat/view" method="POST">
          # <input autofocus name="grp" placeholder="group name">
          <button type="submit">Continue</button>
        </form>
      `, req.session ? req.session.get!string("user") : null)
    );
  });

  router.post("/chat/view", (req, res) @trusted {
    import std.conv : to;

    auto group = htmlEscape(req.form["grp"]);

    auto show = (db.groupExists(group) ? "" : htmlEscape("<NEW GROUP>")) ~ "# <b>" ~ group ~ "</b>";
    auto user = req.session.get!string("user");

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
        <form action="/chat/send" method="POST">
          <input autofocus name="body" placeholder="message #` ~ group ~ `">
          <input type="hidden" name="grp" value="` ~ htmlEscape(group) ~ `">
          <button type="submit">Send</button>
        </form>
      `, req.session ? req.session.get!string("user") : null)
    );
  });

  router.post("/chat/send", (req, res) @trusted {
    db.sendMessage(req.form["grp"], req.session.get!string("user"), req.form["body"]);
    res.redirect("/chat/view", HTTPStatus.temporaryRedirect);
  });

  router.get("/themes/default.css", &themes.defTheme);

  auto listener = listenHTTP(settings, router);
  scope (exit) listener.stopListening();

  runApplication();
}
