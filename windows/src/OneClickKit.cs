// OneClick Kit
// Runs four maintenance scripts that are embedded in this exe, in this order:
//   1. clean_browser_cache.bat  - browser cache cleanup
//   2. clean_windows_junk.bat   - Windows junk cleanup
//   3. clean_dev_caches.bat     - developer package cache cleanup
//   4. update_system.bat        - Windows, driver and app updates
// Cleanup runs first so it frees space for the updates, and updates run last so
// the cleanup can never delete freshly downloaded update files.
// Each script is written to a fresh folder and run with /auto (plus /dryrun when
// --dry-run is given). Exit codes: 0 = all steps OK, 1 = a step had warnings or
// could not start, 2 = cancelled at the start.

using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Threading;
using Microsoft.Win32;

[assembly: AssemblyTitle("OneClick Kit")]
[assembly: AssemblyProduct("OneClick Kit")]
[assembly: AssemblyDescription("One-click Windows cleanup and updates")]
[assembly: AssemblyVersion("1.0.0.0")]
[assembly: AssemblyFileVersion("1.0.0.0")]

internal static class Program
{
    private const int StepCount = 4;

    // Embedded resource names (must match the /resource names in build.bat).
    private static readonly string[] ScriptNames =
    {
        "clean_browser_cache.bat",
        "clean_windows_junk.bat",
        "clean_dev_caches.bat",
        "update_system.bat"
    };

    private static readonly string[] StepNames =
    {
        "Browser cache cleanup",
        "Windows junk cleanup",
        "Developer cache cleanup",
        "Windows, driver and app updates"
    };

    private static int Main(string[] args)
    {
        try
        {
            return Run(args);
        }
        catch (Exception ex)
        {
            Console.WriteLine();
            Console.ForegroundColor = ConsoleColor.Red;
            Console.WriteLine("  Error: " + ex.Message);
            Console.ResetColor();
            WaitForKey("  Press any key to close...");
            return 1;
        }
    }

    private static int Run(string[] args)
    {
        bool dryRun = false;
        foreach (string arg in args)
        {
            string a = arg.ToLowerInvariant();
            if (a == "--help" || a == "-h" || a == "/?")
            {
                PrintHelp();
                return 0;
            }
            if (a == "--dry-run" || a == "/dryrun")
            {
                dryRun = true;
            }
        }

        Console.Title = "OneClick Kit";
        PrintBanner(dryRun);

        if (!Countdown())
        {
            return 2;
        }

        // The run folder must NOT be under %TEMP% or C:\Windows\Temp, because
        // clean_windows_junk.bat empties those folders and would delete the running scripts.
        string runFolder = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "OneClickKit",
            "run-" + DateTime.Now.ToString("yyyyMMdd-HHmmss"));

        int[] exitCodes = new int[StepCount];
        string[] errors = new string[StepCount];
        TimeSpan[] times = new TimeSpan[StepCount];

        for (int i = 0; i < StepCount; i++)
        {
            Console.WriteLine();
            Console.WriteLine("  [" + (i + 1) + "/" + StepCount + "] " + StepNames[i]);
            Console.WriteLine("  " + new string('-', 60));
            RunStep(i, runFolder, dryRun, exitCodes, errors, times);
        }

        PrintSummary(exitCodes, errors, times);

        bool allOk = true;
        for (int i = 0; i < StepCount; i++)
        {
            if (errors[i] != null || exitCodes[i] != 0)
            {
                allOk = false;
            }
        }

        if (!dryRun)
        {
            CheckRestart();
        }

        Cleanup(runFolder);
        WaitForKey("  Press any key to close...");
        return allOk ? 0 : 1;
    }

    private static void PrintHelp()
    {
        Console.WriteLine("OneClick Kit - browser cache cleanup, Windows junk cleanup, developer cache cleanup and updates.");
        Console.WriteLine();
        Console.WriteLine("Usage: OneClickKit.exe [--dry-run] [--help]");
        Console.WriteLine();
        Console.WriteLine("  --dry-run   Show what would happen. Nothing is changed.");
        Console.WriteLine("  --help      Show this help (also -h or /?).");
    }

    private static void PrintBanner(bool dryRun)
    {
        Console.WriteLine();
        Console.WriteLine("  OneClick Kit");
        Console.WriteLine("  ============");
        Console.WriteLine("  This will:");
        Console.WriteLine("    1. Close Chrome, Edge, Brave and Firefox and clear their cache");
        Console.WriteLine("       (history, cookies, passwords and logins are kept)");
        Console.WriteLine("    2. Clean Windows temp files, update cache, crash reports and the Recycle Bin");
        Console.WriteLine("    3. Tidy developer caches: prune pnpm and npm, clear yarn, bun and pip");
        Console.WriteLine("    4. Install Windows, driver, Defender, Microsoft Store and app updates");
        Console.WriteLine();
        Console.WriteLine("  Save your work in open browsers first.");
        Console.WriteLine();

        if (dryRun)
        {
            Console.ForegroundColor = ConsoleColor.Cyan;
            Console.WriteLine("  DRY RUN: nothing will be changed.");
            Console.ResetColor();
            Console.WriteLine();
        }
    }

    // Shows a 10 second countdown. Any key starts now, Esc cancels.
    // Returns false if the user cancelled. Skipped when input is redirected.
    private static bool Countdown()
    {
        if (Console.IsInputRedirected)
        {
            return true;
        }

        for (int n = 10; n >= 1; n--)
        {
            Console.Write("\r  Starting in " + n + " s - press any key to start now, Esc to cancel. ");

            // Poll every 100 ms for one second.
            for (int tick = 0; tick < 10; tick++)
            {
                if (Console.KeyAvailable)
                {
                    ConsoleKey key = Console.ReadKey(true).Key;
                    Console.WriteLine();
                    if (key == ConsoleKey.Escape)
                    {
                        Console.WriteLine("  Cancelled.");
                        return false;
                    }
                    return true;
                }
                Thread.Sleep(100);
            }
        }

        Console.WriteLine();
        return true;
    }

    private static void RunStep(int index, string runFolder, bool dryRun, int[] exitCodes, string[] errors, TimeSpan[] times)
    {
        Stopwatch watch = Stopwatch.StartNew();
        try
        {
            string scriptPath = ExtractScript(runFolder, ScriptNames[index]);
            string arguments = "/c \"\"" + scriptPath + "\" /auto" + (dryRun ? " /dryrun" : "") + "\"";

            // No redirection: the child shares this console so its progress is visible.
            ProcessStartInfo info = new ProcessStartInfo("cmd.exe", arguments);
            info.UseShellExecute = false;
            info.WorkingDirectory = runFolder;

            using (Process process = Process.Start(info))
            {
                if (process == null)
                {
                    throw new InvalidOperationException("cmd.exe did not start");
                }
                process.WaitForExit();
                exitCodes[index] = process.ExitCode;
            }
        }
        catch (Exception ex)
        {
            errors[index] = ex.Message;
        }
        watch.Stop();
        times[index] = watch.Elapsed;
    }

    // Writes one embedded script to the run folder, byte for byte (keeps CRLF).
    private static string ExtractScript(string folder, string resourceName)
    {
        Directory.CreateDirectory(folder);
        string path = Path.Combine(folder, resourceName);

        using (Stream source = Assembly.GetExecutingAssembly().GetManifestResourceStream(resourceName))
        {
            if (source == null)
            {
                throw new InvalidOperationException("embedded script missing: " + resourceName);
            }
            using (FileStream target = new FileStream(path, FileMode.Create, FileAccess.Write))
            {
                source.CopyTo(target);
            }
        }
        return path;
    }

    private static void PrintSummary(int[] exitCodes, string[] errors, TimeSpan[] times)
    {
        Console.WriteLine();
        Console.WriteLine(new string('=', 60));
        Console.WriteLine("  Summary");
        Console.WriteLine(new string('=', 60));

        for (int i = 0; i < StepCount; i++)
        {
            string tag;
            ConsoleColor color;
            if (errors[i] != null)
            {
                tag = "[FAILED]";
                color = ConsoleColor.Red;
            }
            else if (exitCodes[i] != 0)
            {
                tag = "[WARNING]";
                color = ConsoleColor.Yellow;
            }
            else
            {
                tag = "[OK]";
                color = ConsoleColor.Green;
            }

            Console.Write("  ");
            Console.ForegroundColor = color;
            Console.Write(tag.PadRight(11));
            Console.ResetColor();
            Console.Write(StepNames[i].PadRight(36) + FormatTime(times[i]));

            if (errors[i] != null)
            {
                Console.WriteLine("   " + errors[i]);
            }
            else if (exitCodes[i] != 0)
            {
                Console.WriteLine("   exit code " + exitCodes[i]);
            }
            else
            {
                Console.WriteLine();
            }
        }
    }

    private static string FormatTime(TimeSpan span)
    {
        int total = (int)span.TotalSeconds;
        return string.Format("{0}m {1:00}s", total / 60, total % 60);
    }

    // Checks the two registry flags Windows sets when a restart is pending.
    private static void CheckRestart()
    {
        bool needed;
        try
        {
            needed = RestartPending();
        }
        catch (Exception ex)
        {
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine("  Could not check for a pending restart: " + ex.Message);
            Console.ResetColor();
            return;
        }

        if (!needed)
        {
            Console.WriteLine("  No restart needed.");
            return;
        }

        Console.ForegroundColor = ConsoleColor.Yellow;
        Console.WriteLine("  A restart is needed to finish installing updates.");
        Console.ResetColor();

        if (Console.IsInputRedirected)
        {
            return;
        }

        Console.Write("  Restart now? [Y/N] ");
        bool yes = false;
        while (true)
        {
            char c = char.ToUpperInvariant(Console.ReadKey(true).KeyChar);
            if (c == 'Y' || c == 'N')
            {
                yes = (c == 'Y');
                Console.WriteLine(c.ToString());
                break;
            }
        }

        if (yes)
        {
            Process.Start("shutdown.exe", "/r /t 15 /c \"OneClick Kit: restarting to finish updates\"");
            Console.WriteLine("  Restarting in 15 seconds. Run 'shutdown /a' to cancel.");
        }
        else
        {
            Console.WriteLine("  No restart now. Restart later to finish the updates.");
        }
    }

    private static bool RestartPending()
    {
        using (RegistryKey hklm = RegistryKey.OpenBaseKey(RegistryHive.LocalMachine, RegistryView.Registry64))
        {
            return SubkeyExists(hklm, @"SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired")
                || SubkeyExists(hklm, @"SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending");
        }
    }

    private static bool SubkeyExists(RegistryKey root, string path)
    {
        using (RegistryKey key = root.OpenSubKey(path))
        {
            return key != null;
        }
    }

    // Deletes the run folder, and the OneClickKit parent only if it is empty.
    private static void Cleanup(string runFolder)
    {
        try
        {
            if (Directory.Exists(runFolder))
            {
                Directory.Delete(runFolder, true);
            }
        }
        catch (Exception)
        {
            // Ignore: a leftover folder is harmless.
        }

        try
        {
            string parent = Path.GetDirectoryName(runFolder);
            if (parent != null && Directory.Exists(parent) && Directory.GetFileSystemEntries(parent).Length == 0)
            {
                Directory.Delete(parent);
            }
        }
        catch (Exception)
        {
            // Ignore: not empty or in use.
        }
    }

    private static void WaitForKey(string message)
    {
        if (Console.IsInputRedirected)
        {
            return;
        }
        Console.WriteLine(message);
        Console.ReadKey(true);
    }
}
