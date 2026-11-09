using System;
using System.IO;
using System.Threading;

// A GUI-subsystem executable exercises the same waiting/capture path as Godot.
public static class ExportFixture
{
    public static int Main(string[] args)
    {
        string data = Environment.GetEnvironmentVariable("APPDATA");
        string cwd = Environment.CurrentDirectory;
        if (File.Exists(Path.Combine(cwd, "project.godot"))) return 31;
        if (String.IsNullOrEmpty(data) || data != cwd) return 32;
        string saves = Path.Combine(data, "Godot", "app_userdata", "snake");
        Directory.CreateDirectory(saves);
        File.WriteAllText(Path.Combine(saves, "settings.cfg"), "disposable settings");
        File.WriteAllText(Environment.GetEnvironmentVariable("SNAKE_FIXTURE_REPORT"), cwd);
        switch (Environment.GetEnvironmentVariable("SNAKE_FIXTURE_MODE"))
        {
            case "fail": return 23;
            case "error": Console.Error.WriteLine("ERROR: missing package"); break;
            case "hang": Thread.Sleep(20000); break;
        }
        return 0;
    }
}
