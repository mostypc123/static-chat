module utils;
import vibe.vibe;
import database;

void writeHtmlBody(HTTPServerResponse res, string html, int code = 200) {
  res.statusCode = code;
  res.headers["Content-Type"] = "text/html; charset=utf-8";

  res.writeBody(
    html, "text/html; charset=utf-8"
  );
}

Database db;
string html(string body, string user, string title = "Static Chat") {
  return (`
    <!doctype html>
    <html lang="en">
      <head>
        <title>` ~ title ~ `</title>
        <link rel="stylesheet" href="` ~ (user is null ? "/themes/default.css" : db.getUsersTheme(user)) ~ `">
      </head>
      <body>`
        ~ body ~
      `</body>
    </html>
  `);
}
