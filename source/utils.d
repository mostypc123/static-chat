module utils;
import vibe.vibe;

void writeHtmlBody(HTTPServerResponse res, string html, int code = 200) {
  res.statusCode = code;
  res.headers["Content-Type"] = "text/html; charset=utf-8";

  res.writeBody(
    html, "text/html; charset=utf-8"
  );
}

string html(string body, string title = "Static Chat") {
  return (`
    <!doctype html>
    <html lang="en">
      <head>
        <title>` ~ title ~ `</title>
      </head>
      <body>`
        ~ body ~
      `</body>
    </html>
  `);
}
