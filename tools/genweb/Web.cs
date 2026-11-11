// What the game calls from the browser: make one new board of a wanted difficulty.
using System;
using System.Diagnostics;
using System.Linq;
using System.Runtime.InteropServices.JavaScript;
using System.Text;

public static partial class Web
{
    // The same measure tools/build_levels.py uses to order a chapter's ladder.
    static double Difficulty(LevelOut g)
    {
        int ny = g.rows.Sum(l => l.Count(c => Sim.DEF.ContainsKey(c)));
        return g.par * 10 + Math.Log2(g.states + 1) * 1.2 - Math.Log2(g.ways + 1) * 1.5 + ny * 0.5;
    }

    // Tries boards until one lands between lo and hi, or the time runs out; then a near miss, if there is one.
    // Returns "rows|waza|rules|ink|par|answer|difficulty|tries|ms|exact", or "" if nothing was found.
    [JSExport]
    public static string Make(int seed, double lo, double hi, int budgetMs, int bracket)
    {
        var segs = Gen.Segs().Where(g => !g.rules.Contains("shiki") && !g.rules.Contains("koan") && !g.rules.Contains("garden")
            // look where boards of the wanted weight are likely: short chapters for gentle, long ones for master
            && (bracket == 0 ? g.parHi <= 5 : bracket == 1 ? g.parLo <= 5 && g.parHi <= 7 : bracket == 2 ? g.parHi >= 5 : g.parHi >= 6)).ToList();
        var clock = Stopwatch.StartNew();
        var r = new Random(seed);
        LevelOut best = null; double bestMiss = 1e9; int tries = 0;
        while (clock.ElapsedMilliseconds < budgetMs)
        {
            var g = segs[r.Next(segs.Count)];
            tries++;
            var lv = Gen.TryOne(g, r.Next(), bracket <= 1 ? 1.0 : 2.0);
            if (lv == null) continue;
            double d = Difficulty(lv);
            double miss = d < lo ? lo - d : d >= hi ? d - hi : 0;
            if (miss < bestMiss) { best = lv; bestMiss = miss; }
            if (miss == 0) break;
        }
        if (best == null || bestMiss > 3.0) return "";   // a near miss will do; a board of the wrong weight will not
        var sb = new StringBuilder();
        sb.Append(string.Join("", best.rows)).Append('|').Append(string.Join(",", best.waza)).Append('|').Append(string.Join(",", best.rules))
          .Append('|').Append(best.ink).Append('|').Append(best.par).Append('|').Append(best.trace)
          .Append('|').Append(Difficulty(best).ToString("0.0", System.Globalization.CultureInfo.InvariantCulture))
          .Append('|').Append(tries).Append('|').Append(clock.ElapsedMilliseconds).Append('|').Append(bestMiss == 0 ? 1 : 0);
        return sb.ToString();
    }
}
