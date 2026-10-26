module config;

class Config {
  import vibe.vibe;

  private string[string] options;

  this(string file = "static-chat.conf") {
    import std.file : readText;
    import std.string : splitLines, indexOf, strip;

    int c = 0;
    foreach (line; readText(file).splitLines()) {
      /* I hate: */ c++; // Superior: d
      line = line.strip();
      if (line.length == 0 || line[0] == '#') continue;

      auto eq = line.indexOf('=');
      if (eq < 0) {
        logWarn("Skipping line %s: no '=' found", c);
        continue;
      }

      auto key = line[0 .. eq].strip();
      auto value = line[eq + 1 .. $].strip();

      if (key.startsWith("env+")) {
        import std.process : environment;
        environment[key[4 .. $]] = value;
      } else {
        options[key] = value;
      }
    }
  }

  string opIndex(string key) {
    return options[key];
  }

  string get(string key) {
    return options.get(key, "");
  }
}
