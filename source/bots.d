class Bot {
  public {
    string name;
    string absolutepath_file;

    this(string script, string absolutepath) {
      import std.string : splitLines, strip;
      import std.algorithm : startsWith, endsWith;

      absolutepath_file = absolutepath;

      enum prefix = "## - name(";
      enum suffix = ") ##";

      foreach (line; script.splitLines()) {
        auto l = line.strip();
        if (l.length >= prefix.length + suffix.length
            && l.startsWith(prefix) && l.endsWith(suffix)) {
          name = l[prefix.length .. $ - suffix.length].strip();
          break;
        }
      }
    }

    string call(string arg) {
      import std.process : execute, Config;
      import std.string : strip;

      auto result = execute([absolutepath_file], ["ARG": arg], Config.none, 4096);
      auto output = result.output.strip();
      return output.length ? ("bot call: " ~ name ~ " - " ~ arg ~ " | " ~ output) : "(no output)";
    }
  }
}

class Bots {
  public {
    this(string dir) {
      this.dir = dir;
      populate();
    }

    Bot opIndex(string name) {
      foreach (bot; bots) {
        if (bot.name == name) {
          return bot;
        }
      }

      throw new Exception("no bot named " ~ name);
    }
  }

  private {
    string dir;
    void populate() {
      import std.file : dirEntries, SpanMode, readText, exists, isDir;
      import std.path : absolutePath;

      if (!exists(dir) || !isDir(dir)) return;

      foreach (entry; dirEntries(dir, SpanMode.depth)) {
        if (!entry.isFile) continue;
        try {
          auto bot = new Bot(readText(entry.name), absolutePath(entry.name));
          if (bot.name.length) bots ~= bot;
        } catch (Exception e) {
          continue; // unreadable / not text
        }
      }
    }

    Bot[] bots;
  }
}
