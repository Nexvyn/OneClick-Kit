// OneClick Kit launcher.
// Starts oneclick.bat, which sits in the same folder as this exe, with the
// "menu" and "elevated" arguments, in this same console. The exe itself is
// elevated through app.manifest (requireAdministrator).
// Exit code: the exit code of oneclick.bat, 1 if oneclick.bat is missing or
// could not start, 0 for --help.

using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;

[assembly: AssemblyTitle("OneClick Kit")]
[assembly: AssemblyProduct("OneClick Kit")]
[assembly: AssemblyDescription("Opens the OneClick Kit menu")]
[assembly: AssemblyVersion("1.0.0.0")]
[assembly: AssemblyFileVersion("1.0.0.0")]

internal static class Program
{
    private const string ScriptName = "oneclick.bat";

    private static int Main(string[] args)
    {
        foreach (string arg in args)
        {
            string a = arg.ToLowerInvariant();
            if (a == "--help" || a == "/?")
            {
                PrintHelp();
                return 0;
            }
        }

        string scriptPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, ScriptName);
        if (!File.Exists(scriptPath))
        {
            Console.WriteLine("Keep OneClickKit.exe inside the OneClick-Kit windows folder, next to oneclick.bat.");
            WaitForKey();
            return 1;
        }

        try
        {
            // The doubled quotes keep paths with spaces working through cmd.exe /c.
            string arguments = "/c \"\"" + scriptPath + "\" menu elevated\"";

            // No new window: the script shares this console.
            ProcessStartInfo info = new ProcessStartInfo("cmd.exe", arguments);
            info.UseShellExecute = false;
            info.WorkingDirectory = Path.GetDirectoryName(scriptPath);

            using (Process process = Process.Start(info))
            {
                if (process == null)
                {
                    Console.WriteLine("Could not start cmd.exe.");
                    return 1;
                }
                process.WaitForExit();
                return process.ExitCode;
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine("Could not start oneclick.bat: " + ex.Message);
            return 1;
        }
    }

    private static void PrintHelp()
    {
        Console.WriteLine("OneClick Kit - opens the OneClick Kit menu (install, update, cleanup and debloat).");
        Console.WriteLine();
        Console.WriteLine("Usage: OneClickKit.exe [--help]");
        Console.WriteLine();
        Console.WriteLine("  Runs oneclick.bat menu from the same folder. It must stay inside the");
        Console.WriteLine("  OneClick-Kit windows folder, next to oneclick.bat.");
        Console.WriteLine("  --help   Show this help (also /?).");
    }

    private static void WaitForKey()
    {
        if (Console.IsInputRedirected)
        {
            return;
        }
        Console.WriteLine("Press any key to close...");
        Console.ReadKey(true);
    }
}
