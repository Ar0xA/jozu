// What the game calls from the browser: make one new board of a wanted difficulty.
using System.Runtime.InteropServices.JavaScript;

public static partial class Web
{
    // See Maker.Make (tools/gen/Program.cs), which the desktop game reaches through gen.exe.
    [JSExport]
    public static string Make(int seed, double lo, double hi, int budgetMs, int bracket, int order)
    {
        return Maker.Make(seed, lo, hi, budgetMs, bracket, order);
    }
}
