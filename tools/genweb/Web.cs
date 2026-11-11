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

    // Where to look for each bracket: (chapter, segment, weight). Measured from the generator's own
    // logs: how many boards of that weight each segment yields per second of work. Rebuilt by hand
    // when chapters are added; a stale table only makes the search slower, never wrong.
    static readonly (int ch, int seg, double w)[][] WHERE =
    {
        new (int, int, double)[] { (12, 0, 2.42), (19, 0, 2.03), (31, 0, 1.27), (25, 0, 1.15), (18, 0, 0.94), (23, 0, 0.94), (17, 0, 0.90), (20, 0, 0.61), (30, 0, 0.61), (15, 0, 0.58) },
        new (int, int, double)[] { (31, 0, 1.80), (19, 0, 1.41), (35, 0, 1.37), (18, 0, 1.27), (17, 0, 1.06), (23, 0, 0.87), (12, 1, 0.85), (25, 0, 0.82), (29, 0, 0.61), (20, 0, 0.54) },
        new (int, int, double)[] { (31, 0, 1.46), (35, 0, 1.12), (17, 0, 0.94), (18, 0, 0.94), (19, 0, 0.94), (23, 0, 0.76), (25, 0, 0.58), (12, 1, 0.56), (29, 0, 0.55), (23, 1, 0.44) },
        new (int, int, double)[] { (35, 0, 1.27), (35, 1, 0.92), (19, 0, 0.61), (31, 1, 0.59), (23, 0, 0.58), (17, 0, 0.56), (31, 0, 0.50), (17, 1, 0.38), (25, 0, 0.35), (23, 1, 0.35) },
    };

    // Tries boards until one lands between lo and hi, or the time runs out; then a near miss, if there is one.
    // Returns "rows|waza|rules|ink|par|answer|difficulty|tries|ms|exact", or "" if nothing was found.
    [JSExport]
    public static string Make(int seed, double lo, double hi, int budgetMs, int bracket)
    {
        var all = Gen.Segs();
        var picks = WHERE[Math.Clamp(bracket, 0, 3)];
        double total = picks.Sum(x => x.w);
        var clock = Stopwatch.StartNew();
        var r = new Random(seed);
        LevelOut best = null; double bestMiss = 1e9; int tries = 0;
        while (clock.ElapsedMilliseconds < budgetMs)
        {
            double roll = r.NextDouble() * total;
            var pick = picks[picks.Length - 1];
            foreach (var x in picks) { if (roll < x.w) { pick = x; break; } roll -= x.w; }
            var g = all.First(x => x.chapter == pick.ch && x.seg == pick.seg);
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
