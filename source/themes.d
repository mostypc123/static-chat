module themes;
import vibe.vibe;

immutable string defaultTheme = import("default.css");
immutable string lightThemeText = import("light.css");

void defTheme(HTTPServerRequest req, HTTPServerResponse res) @trusted {
  res.statusCode = 200;
  res.headers["Content-Type"] = "text/css; charset=utf-8";

  res.writeBody(
    defaultTheme, "text/css; charset=utf-8"
  );
}

void lightTheme(HTTPServerRequest req, HTTPServerResponse res) @trusted {
  res.statusCode = 200;
  res.headers["Content-Type"] = "text/css; charset=utf-8";

  res.writeBody(
    lightThemeText, "text/css; charset=utf-8"
  );
}
