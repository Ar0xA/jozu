// Jozu level generator and exact solver.
//
//   dotnet run -c Release --project tools/gen -- solve in.json out.json
//   dotnet run -c Release --project tools/gen -- gen out.json [seed]             the story chapters
//   dotnet run -c Release --project tools/gen -- gen out.json seed pool [chapter]  a pool for the style chapters
//
// The rules here are a line-for-line port of scripts/sim.gd. tools/verify.gd replays every
// solution this program finds inside the real game rules, so the two cannot drift apart unnoticed.
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Numerics;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;

sealed class St
{
    public int hx, hy, ki, ink, inkMax, leap, ward, katsu, mom, mdx, mdy, turn, hits, status, n, nextId, nhand, na;
    public ulong visited, wards, wet, revive, chg, inked;
    public int bell; public bool stun;
    public byte[] path; public int plen;
    public char[] yc; public int[] yx, yy, yhp, yid; public bool[] ydown;
    public char[] hand; public char[] ak; public int[] ax, ay;
    public St parent; public string stroke = "";
    public St Clone()
    {
        var c = (St)MemberwiseClone();
        c.yc = (char[])yc.Clone(); c.yx = (int[])yx.Clone(); c.yy = (int[])yy.Clone();
        c.yhp = (int[])yhp.Clone(); c.yid = (int[])yid.Clone(); c.ydown = (bool[])ydown.Clone();
        c.path = (byte[])path.Clone();
        if (hand != null) { c.hand = (char[])hand.Clone(); c.ak = (char[])ak.Clone(); c.ax = (int[])ax.Clone(); c.ay = (int[])ay.Clone(); }
        return c;
    }
    public void RemoveAt(int i)
    {
        for (int k = i; k < n - 1; k++) { yc[k] = yc[k + 1]; yx[k] = yx[k + 1]; yy[k] = yy[k + 1]; yhp[k] = yhp[k + 1]; yid[k] = yid[k + 1]; ydown[k] = ydown[k + 1]; }
        n--;
    }
}

sealed class Result { public int par = -1; public string trace = ""; public double ways; public int states; public bool capped; }

sealed class Sim
{
    static readonly int[] DX = { 1, -1, 0, 0 }, DY = { 0, 0, 1, -1 };
    static readonly string[] TAG = { "R", "L", "D", "U" };
    public static readonly Dictionary<char, (string kind, int hp)> DEF = new()
    {
        ['c'] = ("chochin", 1), ['o'] = ("oni", 2), ['O'] = ("oni", 3), ['S'] = ("oni", 5),
        ['t'] = ("tengu", 1), ['T'] = ("tengu", 2), ['k'] = ("kitsune", 1), ['y'] = ("yurei", 1), ['Q'] = ("tamamo", 5),
        ['u'] = ("kasa", 1), ['p'] = ("kappa", 2), ['P'] = ("kappa", 4), ['n'] = ("nurikabe", 3),
        ['W'] = ("yukionna", 3), ['G'] = ("gasha", 7),
        ['d'] = ("daruma", 2), ['a'] = ("tanuki", 1), ['A'] = ("tanuki", 1), ['e'] = ("hitodama", 1),
        ['X'] = ("shinigami", 3), ['K'] = ("kamaitachi", 1),
    };
    const int HandMax = 3, AllyMax = 12;
    readonly char[][] rows; readonly int w, h;
    readonly bool rKoan, rWet, rEnso, rGarden, rGate, rNocut, rStone, rShiki, rRain;
    readonly int windX, windY;
    readonly bool rOrder, rWrite, hasChg, slowKama;
    readonly int marks;
    readonly List<(int x, int y)> offers = new();
    readonly int open;
    public St start;

    public Sim(string[] src, int ink, int ki, bool leap, bool ward, bool katsu, string[] rules = null, bool bell = false, bool slowKama = false)
    {
        rules ??= Array.Empty<string>();
        rKoan = rules.Contains("koan"); rWet = rules.Contains("wet"); rEnso = rules.Contains("enso");
        rGarden = rules.Contains("garden"); rGate = rules.Contains("gate"); rNocut = rules.Contains("nocut"); rStone = rules.Contains("stone");
        rShiki = rules.Contains("shiki"); rRain = rules.Contains("rain");
        rOrder = rules.Contains("order"); rWrite = rules.Contains("write");
        this.slowKama = slowKama;
        bool snow = rules.Contains("snow");
        foreach (var r in rules)
            if (r.StartsWith("wind:")) { int d = Array.IndexOf(TAG, r.Substring(5)); windX = DX[d]; windY = DY[d]; }
        h = src.Length; w = src[0].Length;
        rows = new char[h][];
        var s = new St { ki = ki, ink = ink, inkMax = ink, leap = leap ? 1 : 0, ward = ward ? 1 : 0, katsu = katsu ? 1 : 0, bell = bell ? 1 : 0 };
        var yc = new List<char>(); var yx = new List<int>(); var yy = new List<int>(); var yh = new List<int>();
        for (int y = 0; y < h; y++)
        {
            rows[y] = new char[w];
            for (int x = 0; x < w; x++)
            {
                char ch = src[y][x];
                if (ch == 'H') { s.hx = x; s.hy = y; rows[y][x] = '.'; }
                else if (DEF.ContainsKey(ch)) { yc.Add(ch); yx.Add(x); yy.Add(y); yh.Add(DEF[ch].hp); rows[y][x] = DEF[ch].kind == "kappa" ? '~' : '.'; }
                else rows[y][x] = ch;
                if (snow && rows[y][x] == '~') rows[y][x] = 'i';
            }
        }
        s.n = yc.Count; s.yc = yc.ToArray(); s.yx = yx.ToArray(); s.yy = yy.ToArray(); s.yhp = yh.ToArray();
        s.yid = Enumerable.Range(0, s.n).ToArray(); s.ydown = new bool[s.n]; s.nextId = s.n;
        s.visited = Bit(s.hx, s.hy);
        s.path = new byte[64]; s.path[0] = (byte)(s.hy * w + s.hx); s.plen = 1;
        if (rShiki) { s.hand = new char[HandMax]; s.ak = new char[AllyMax]; s.ax = new int[AllyMax]; s.ay = new int[AllyMax]; }
        foreach (var row in rows) foreach (char ch in row) if (ch == '.' || ch == 'i') open++;
        for (int y = 0; y < h; y++)
            for (int x = 0; x < w; x++)
            {
                if (rows[y][x] == 'm') { offers.Add((x, y)); hasChg = true; }
                if (rows[y][x] == 'b') hasChg = true;
                if (rows[y][x] == 'x') marks++;
            }
        start = s;
    }

    ulong Bit(int x, int y) => 1UL << (y * w + x);
    bool Inb(int x, int y) => x >= 0 && y >= 0 && x < w && y < h;
    // ground changes as the stage is played: an offering eaten is floor, a plank fallen is water
    char T(St s, int x, int y) { char c = rows[y][x]; if ((s.chg & Bit(x, y)) != 0) return c == 'b' ? '~' : '.'; return c; }
    bool WalkAt(St s, int x, int y) { char c = T(s, x, y); return c == '.' || c == 'i' || c == 'f' || c == 'g' || c == 'm' || c == 'b' || c == 'w' || c == 'x'; }
    bool Sealed(int yi) => rOrder && yi > 0;
    bool Eating(St s, int i) => T(s, s.yx[i], s.yy[i]) == 'm' && !Ghost(Kind(s.yc[i]));
    static string Kind(char c) => DEF[c].kind;
    static bool Ghost(string k) => k == "yurei" || k == "yukionna" || k == "shinigami";
    static bool Harmless(string k) => k == "kitsune" || k == "nurikabe" || k == "tanuki" || k == "hitodama";
    static bool Light(string k) => k == "chochin" || k == "kasa" || k == "yurei" || k == "hitodama";
    static bool Mover(string k) => k == "kamaitachi" || k == "oni" || k == "yurei" || k == "yukionna" || k == "kasa" || k == "kappa" || k == "gasha" || k == "shinigami";
    int YokaiAt(St s, int x, int y) { for (int i = 0; i < s.n; i++) if (s.yx[i] == x && s.yy[i] == y) return i; return -1; }
    int AllyAt(St s, int x, int y) { for (int i = 0; i < s.na; i++) if (s.ax[i] == x && s.ay[i] == y) return i; return -1; }
    static bool Hidden(St s, int i) => s.yc[i] == 'a';

    bool CanStand(St s, string kind, int x, int y)
    {
        if (!Inb(x, y)) return false;
        if (kind == "kappa") { if (T(s, x, y) != '~' && !(rRain && WalkAt(s, x, y))) return false; }
        else if (!Ghost(kind) && !WalkAt(s, x, y)) return false;
        if ((x == s.hx && y == s.hy) || ((s.wards | s.wet) & Bit(x, y)) != 0) return false;
        return YokaiAt(s, x, y) < 0 && AllyAt(s, x, y) < 0;
    }

    int CutPower(St s, int dx, int dy) => (dx == s.mdx && dy == s.mdy) ? Math.Min(3, 1 + s.mom) : 1;

    bool Los(St s, int qx, int qy, int px, int py)
    {
        if ((px == qx && py == qy) || (px != qx && py != qy)) return false;
        int dx = Math.Sign(px - qx), dy = Math.Sign(py - qy), tx = qx + dx, ty = qy + dy;
        while (tx != px || ty != py)
        {
            if (T(s, tx, ty) == '#' || ((s.wards | s.wet) & Bit(tx, ty)) != 0 || YokaiAt(s, tx, ty) >= 0 || AllyAt(s, tx, ty) >= 0) return false;
            tx += dx; ty += dy;
        }
        return true;
    }

    // reach class: 't' a straight clear line, 'G' all eight neighbours, anything else the four beside it
    bool Reaches(St s, char cls, int qx, int qy, int px, int py)
    {
        if (cls == 't') return Los(s, qx, qy, px, py);
        if (cls == 'G') return !(px == qx && py == qy) && Math.Abs(px - qx) <= 1 && Math.Abs(py - qy) <= 1;
        return Math.Abs(px - qx) + Math.Abs(py - qy) == 1;
    }
    static char Cls(string kind) => kind == "tengu" ? 't' : kind == "gasha" ? 'G' : 'o';

    public bool Threatens(St s, int i, int px, int py)
    {
        string k = Kind(s.yc[i]);
        if (Harmless(k) || s.stun || Eating(s, i)) return false;
        if (k == "daruma" && s.ydown[i]) return false;
        if (k == "chochin" && rRain) return false;
        return Reaches(s, Cls(k), s.yx[i], s.yy[i], px, py);
    }

    public bool Danger(St s, int x, int y)
    {
        if (T(s, x, y) == 'f' && !rRain) return true;
        for (int i = 0; i < s.n; i++) if (Threatens(s, i, x, y)) return true;
        return false;
    }

    void CheckWin(St s)
    {
        if (rGate || rWrite) return;   // won by arriving, or by the last tile of the character: both in Enter
        if (rGarden) { if (s.status == 0 && BitOperations.PopCount(s.visited) >= open) { s.status = 1; s.turn++; } return; }
        if (s.n == 0 && s.status == 0) { s.status = 1; s.turn++; }
    }

    void Enter(St s, int tx, int ty, int dx, int dy)
    {
        s.hx = tx; s.hy = ty; s.visited |= Bit(tx, ty);
        s.path[s.plen++] = (byte)(ty * w + tx);
        if (dx == s.mdx && dy == s.mdy) s.mom += 1; else { s.mdx = dx; s.mdy = dy; s.mom = 1; }
        for (int i = 0; i < s.n; i++)
        {
            string k = Kind(s.yc[i]);
            if (k == "kitsune" || k == "tamamo")
            {
                int mx = s.yx[i] + dx, my = s.yy[i] + dy;
                if (CanStand(s, k, mx, my)) { s.yx[i] = mx; s.yy[i] = my; }
            }
        }
        if (rGate && T(s, tx, ty) == 'g' && s.status == 0) { s.status = 1; s.turn++; }
        if (T(s, tx, ty) == 'w') s.ink = 0;   // caught in the web
        if (rWrite && T(s, tx, ty) == 'x')
        {
            s.inked |= Bit(tx, ty);
            if (BitOperations.PopCount(s.inked) >= marks && s.status == 0) { s.status = 1; s.turn++; }
        }
    }

    // a yokai is about to leave the board, by whatever means
    void Gone(St s, int i) { if (Kind(s.yc[i]) == "hitodama") s.revive |= Bit(s.yx[i], s.yy[i]); }

    // true if the yokai is gone; a daruma only ever topples, once per stroke
    bool Hurt(St s, int yi, int dmg)
    {
        if (Sealed(yi)) return false;
        bool daruma = Kind(s.yc[yi]) == "daruma";
        if (daruma) { if (s.ydown[yi]) return false; dmg = 1; }
        s.yhp[yi] -= dmg;
        if (s.yhp[yi] <= 0) { Gone(s, yi); s.RemoveAt(yi); return true; }
        if (daruma) s.ydown[yi] = true;
        return false;
    }

    bool Cut(St s, int yi, int tx, int ty, int dx, int dy)
    {
        if (Hurt(s, yi, CutPower(s, dx, dy)))
            if (WalkAt(s, tx, ty) && (s.visited & Bit(tx, ty)) == 0) { Enter(s, tx, ty, dx, dy); return true; }
        s.mom = 0;
        return false;
    }

    void Slide(St s, int dx, int dy)
    {
        while (s.status == 0 && T(s, s.hx, s.hy) == 'i')
        {
            int tx = s.hx + dx, ty = s.hy + dy;
            if (!Inb(tx, ty) || AllyAt(s, tx, ty) >= 0) return;
            int yi = YokaiAt(s, tx, ty);
            if (yi >= 0) { if (rNocut || Hidden(s, yi) || Sealed(yi) || !Cut(s, yi, tx, ty, dx, dy)) return; continue; }
            if (!WalkAt(s, tx, ty) || (s.visited & Bit(tx, ty)) != 0) return;
            Enter(s, tx, ty, dx, dy);
        }
    }

    bool ActMove(St s, int dx, int dy)
    {
        if (s.status != 0 || s.ink <= 0) return false;
        int tx = s.hx + dx, ty = s.hy + dy;
        if (!Inb(tx, ty) || AllyAt(s, tx, ty) >= 0) return false;
        int yi = YokaiAt(s, tx, ty);
        if (yi >= 0)
        {
            if (rNocut || Hidden(s, yi) || Sealed(yi)) return false;
            s.ink--;
            if (Cut(s, yi, tx, ty, dx, dy)) Slide(s, dx, dy);
            CheckWin(s);
            return true;
        }
        if (!WalkAt(s, tx, ty) || (s.visited & Bit(tx, ty)) != 0) return false;
        s.ink--;
        Enter(s, tx, ty, dx, dy);
        Slide(s, dx, dy);
        CheckWin(s);
        return true;
    }

    bool ActLeap(St s, int dx, int dy)
    {
        if (s.status != 0 || s.ink <= 0 || s.leap <= 0) return false;
        int tx = s.hx + dx * 2, ty = s.hy + dy * 2;
        if (!Inb(tx, ty) || !WalkAt(s, tx, ty) || (s.visited & Bit(tx, ty)) != 0 || YokaiAt(s, tx, ty) >= 0 || AllyAt(s, tx, ty) >= 0) return false;
        s.ink--; s.leap--;
        Enter(s, tx, ty, dx, dy);
        Slide(s, dx, dy);
        CheckWin(s);
        return true;
    }

    bool ActWard(St s, int dx, int dy)
    {
        if (s.status != 0 || s.ink <= 0 || s.ward <= 0) return false;
        int tx = s.hx + dx, ty = s.hy + dy;
        if (!Inb(tx, ty) || T(s, tx, ty) != '.' || (s.wards & Bit(tx, ty)) != 0 || YokaiAt(s, tx, ty) >= 0 || AllyAt(s, tx, ty) >= 0) return false;
        s.ink--; s.ward--; s.mom = 0;
        s.wards |= Bit(tx, ty);
        return true;
    }

    bool ActShiki(St s, int dx, int dy)
    {
        if (s.status != 0 || s.ink <= 0 || !rShiki || s.nhand == 0 || s.na >= AllyMax) return false;
        int tx = s.hx + dx, ty = s.hy + dy;
        if (!Inb(tx, ty) || T(s, tx, ty) != '.' || (s.wards & Bit(tx, ty)) != 0 || YokaiAt(s, tx, ty) >= 0 || AllyAt(s, tx, ty) >= 0) return false;
        s.ink--; s.mom = 0;
        s.ak[s.na] = s.hand[0]; s.ax[s.na] = tx; s.ay[s.na] = ty; s.na++;
        for (int k = 0; k < s.nhand - 1; k++) s.hand[k] = s.hand[k + 1];
        s.nhand--;
        return true;
    }

    bool ActKatsu(St s)
    {
        if (s.status != 0 || s.ink <= 0 || s.katsu <= 0) return false;
        bool any = false;
        for (int d = 0; d < 4; d++) { int ax = s.hx + DX[d], ay = s.hy + DY[d]; if (Inb(ax, ay) && YokaiAt(s, ax, ay) >= 0) any = true; }
        if (!any) return false;
        s.ink--; s.katsu--; s.mom = 0;
        for (int d = 0; d < 4; d++)
        {
            int yi = YokaiAt(s, s.hx + DX[d], s.hy + DY[d]);
            if (yi < 0) continue;
            if (Hidden(s, yi)) s.yc[yi] = 'A';
            string k = Kind(s.yc[yi]);
            int tx = s.yx[yi] + DX[d], ty = s.yy[yi] + DY[d];
            bool swims = k == "kappa" || Ghost(k);
            if (k == "nurikabe") { }
            else if (Inb(tx, ty) && T(s, tx, ty) == '~' && !swims && YokaiAt(s, tx, ty) < 0 && !Sealed(yi)) { Gone(s, yi); s.RemoveAt(yi); continue; }
            else if (CanStand(s, k, tx, ty)) { s.yx[yi] = tx; s.yy[yi] = ty; continue; }
            Hurt(s, yi, 1);
        }
        CheckWin(s);
        return true;
    }

    bool ActBell(St s)
    {
        if (s.status != 0 || s.ink <= 0 || s.bell <= 0 || s.stun) return false;
        s.ink--; s.bell--; s.mom = 0; s.stun = true;
        return true;
    }

    void Chase(St s, int i)
    {
        string k = Kind(s.yc[i]);
        if (Eating(s, i)) { s.chg |= Bit(s.yx[i], s.yy[i]); return; }   // it eats, and that is its whole turn
        int gx = s.hx, gy = s.hy;
        if (!Ghost(k))
        {
            int far = 999;
            foreach (var (ox, oy) in offers)
            {
                if ((s.chg & Bit(ox, oy)) != 0) continue;
                int dist = Math.Abs(ox - s.yx[i]) + Math.Abs(oy - s.yy[i]);
                if (dist < far) { far = dist; gx = ox; gy = oy; }
            }
        }
        int steps = k == "kamaitachi" && !slowKama ? 3 : 1;
        for (int st = 0; st < steps; st++)
        {
            if (st > 0 && (Math.Abs(s.hx - s.yx[i]) + Math.Abs(s.hy - s.yy[i]) == 1 || Eating(s, i))) return;
            Step(s, i, k, gx, gy);
        }
    }

    void Step(St s, int i, string k, int gx, int gy)
    {
        int dx = gx - s.yx[i], dy = gy - s.yy[i];
        int ax = Math.Sign(dx), by = Math.Sign(dy);
        (int x, int y)[] order = Math.Abs(dy) > Math.Abs(dx) ? new[] { (0, by), (ax, 0) } : new[] { (ax, 0), (0, by) };
        if (k == "kasa")
            foreach (var d in order)
                if ((d.x != 0 || d.y != 0) && CanStand(s, k, s.yx[i] + d.x * 2, s.yy[i] + d.y * 2)) { s.yx[i] += d.x * 2; s.yy[i] += d.y * 2; return; }
        foreach (var d in order)
        {
            if (d.x == 0 && d.y == 0) continue;
            if (CanStand(s, k, s.yx[i] + d.x, s.yy[i] + d.y)) { s.yx[i] += d.x; s.yy[i] += d.y; return; }
        }
    }

    bool Inside(St s, int qx, int qy)
    {
        bool inside = false;
        for (int i = 0; i < s.plen; i++)
        {
            int a = s.path[i], b = s.path[(i + 1) % s.plen];
            int ax = a % w, ay = a / w, bx = b % w, by = b / w;
            if ((ay > qy) != (by > qy))
            {
                double xc = ax + (double)(bx - ax) * (qy - ay) / (by - ay);
                if (qx < xc) inside = !inside;
            }
        }
        return inside;
    }

    void Won(St s) { s.wet = 0; s.status = 1; s.turn++; }

    void EndStroke(St s)
    {
        if (s.status != 0) return;
        if (rKoan || rGarden) { s.turn++; s.status = 2; return; }
        if (rEnso && s.plen >= 4)
        {
            int ax = s.path[0] % w, ay = s.path[0] / w, bx = s.path[s.plen - 1] % w, by = s.path[s.plen - 1] / w;
            if (Math.Abs(ax - bx) + Math.Abs(ay - by) == 1)
                for (int i = s.n - 1; i >= 0; i--)
                    if (!Sealed(i) && Inside(s, s.yx[i], s.yy[i]))
                    {
                        Gone(s, i);
                        if (rShiki && s.nhand < HandMax) s.hand[s.nhand++] = Cls(Kind(s.yc[i]));
                        s.RemoveAt(i);
                    }
        }
        if (s.revive != 0)
        {
            bool alive = false;
            for (int i = 0; i < s.n; i++) if (Kind(s.yc[i]) == "hitodama") alive = true;
            for (int t = 0; t < w * h; t++)
            {
                if ((s.revive & (1UL << t)) == 0) continue;
                int x = t % w, y = t / w;
                if (alive && !(x == s.hx && y == s.hy) && YokaiAt(s, x, y) < 0 && AllyAt(s, x, y) < 0)
                {
                    s.yc[s.n] = 'e'; s.yx[s.n] = x; s.yy[s.n] = y; s.yhp[s.n] = 1; s.yid[s.n] = s.nextId++; s.ydown[s.n] = false; s.n++;
                }
            }
            s.revive = 0;
        }
        if (s.n == 0 && !rWrite && !rGate) { Won(s); return; }
        if (rWet) s.wet = s.visited & ~Bit(s.hx, s.hy);
        for (int i = 0; i < s.n; i++)
            if (Hidden(s, i) && Math.Abs(s.yx[i] - s.hx) + Math.Abs(s.yy[i] - s.hy) == 1) s.yc[i] = 'A';
        for (int a = 0; a < s.na; a++)
            for (int i = s.n - 1; i >= 0; i--)
                if (Reaches(s, s.ak[a], s.ax[a], s.ay[a], s.yx[i], s.yy[i])) Hurt(s, i, 1);
        if (s.n == 0 && !rWrite && !rGate) { Won(s); return; }
        ulong struck = 0;
        for (int i = 0; i < s.n; i++)
            if (Threatens(s, i, s.hx, s.hy))
            {
                if (Kind(s.yc[i]) == "shinigami") s.ki = 0; else s.ki--;
                s.hits++; struck |= 1UL << i;
            }
        if (T(s, s.hx, s.hy) == 'f' && !rRain) { s.ki--; s.hits++; }
        for (int i = 0; i < s.n; i++) s.ydown[i] = false;
        for (int i = 0; i < s.n; i++)
            if (!s.stun && Mover(Kind(s.yc[i])) && (struck & (1UL << i)) == 0) Chase(s, i);
        if (windX != 0 || windY != 0)
            for (int i = 0; i < s.n; i++)
            {
                string k = Kind(s.yc[i]);
                if (Light(k) && CanStand(s, k, s.yx[i] + windX, s.yy[i] + windY)) { s.yx[i] += windX; s.yy[i] += windY; }
            }
        s.wet = 0; s.stun = false;
        if (hasChg)
        {
            // the planks crossed this stroke give way, and take whatever stands on them
            bool fell = false;
            for (int k = 0; k < s.plen; k++)
            {
                int vx = s.path[k] % w, vy = s.path[k] / w;
                if ((vx == s.hx && vy == s.hy) || T(s, vx, vy) != 'b') continue;
                s.chg |= Bit(vx, vy); fell = true;
                int yi = YokaiAt(s, vx, vy);
                if (yi >= 0 && Kind(s.yc[yi]) != "kappa" && !Ghost(Kind(s.yc[yi])) && !Sealed(yi)) { Gone(s, yi); s.RemoveAt(yi); }
            }
            if (fell && s.n == 0 && !rWrite && !rGate && s.ki > 0) { Won(s); return; }
        }
        s.turn++; s.ink = rStone ? Math.Min(8, s.inkMax + s.ink) : s.inkMax; s.mom = 0; s.mdx = 0; s.mdy = 0;
        s.visited = Bit(s.hx, s.hy);
        s.plen = 1; s.path[0] = (byte)(s.hy * w + s.hx);
        if (s.ki <= 0) s.status = 2;
    }

    static void Put64(StringBuilder sb, ulong v) =>
        sb.Append((char)(v & 0xFFFF)).Append((char)((v >> 16) & 0xFFFF)).Append((char)((v >> 32) & 0xFFFF)).Append((char)((v >> 48) & 0xFFFF));

    bool noInk;   // leave the painted tiles out of the key (for the dominance test below)
    string Key(St s, bool full)
    {
        var sb = new StringBuilder(24 + s.n * 4);
        sb.Append((char)(s.hx + s.hy * 8)).Append((char)(s.leap + s.ward * 2 + s.katsu * 4 + s.ki * 8));
        Put64(sb, s.wards);
        for (int i = 0; i < s.n; i++) sb.Append(s.yc[i]).Append((char)(s.yx[i] + s.yy[i] * 8 + s.yhp[i] * 64 + (s.ydown[i] ? 1024 : 0)));
        if (rStone) sb.Append((char)(0x300 + s.ink));
        if (hasChg) Put64(sb, s.chg);
        if (rWrite && !noInk) Put64(sb, s.inked);
        sb.Append((char)(0x400 + s.bell));
        if (rShiki)
        {
            sb.Append('h');
            for (int i = 0; i < s.nhand; i++) sb.Append(s.hand[i]);
            sb.Append('a');
            for (int i = 0; i < s.na; i++) sb.Append(s.ak[i]).Append((char)(s.ax[i] + s.ay[i] * 8));
        }
        if (full)
        {
            sb.Append(s.stun ? '!' : '|').Append((char)(s.ink + s.mom * 16 + (s.mdx + 1) * 256 + (s.mdy + 1) * 1024));
            Put64(sb, s.visited);
            Put64(sb, s.revive);
            if (rEnso) for (int i = 0; i < s.plen; i++) sb.Append((char)s.path[i]);
        }
        return sb.ToString();
    }

    // ---- exact search: fewest strokes with no blow taken
    Dictionary<string, St> outD; HashSet<string> mid; bool won; string winTrace;

    void Strokes(St s, string tr)
    {
        if (won) return;
        var e = s.Clone();
        EndStroke(e);
        if (e.status == 1 && e.hits == 0) { won = true; winTrace = tr; return; }   // the circle, or a shikigami, finished it
        if (e.status == 0 && e.hits == 0)
        {
            string k = Key(e, false);
            if (!outD.ContainsKey(k)) { e.stroke = tr; outD[k] = e; }
        }
        if (s.ink <= 0) return;
        for (int d = 0; d < 4; d++)
        {
            Try(s, tr, 0, d);
            if (s.leap > 0) Try(s, tr, 1, d);
            if (s.ward > 0) Try(s, tr, 2, d);
            // to keep the search finite, the solver only sets a shikigami before it has moved in a stroke
            if (rShiki && s.nhand > 0 && s.plen == 1) Try(s, tr, 4, d);
        }
        if (s.katsu > 0) Try(s, tr, 3, 0);
        // the bell is rung at the start of a stroke or not at all: when in the stroke makes no difference
        if (s.bell > 0 && !s.stun && s.plen == 1) Try(s, tr, 5, 0);
    }

    void Try(St s, string tr, int kind, int d)
    {
        if (won) return;
        var c = s.Clone();
        bool ok; string tag;
        switch (kind)
        {
            case 0: ok = ActMove(c, DX[d], DY[d]); tag = TAG[d]; break;
            case 1: ok = ActLeap(c, DX[d], DY[d]); tag = "leap" + TAG[d]; break;
            case 2: ok = ActWard(c, DX[d], DY[d]); tag = "ward" + TAG[d]; break;
            case 4: ok = ActShiki(c, DX[d], DY[d]); tag = "shiki" + TAG[d]; break;
            case 5: ok = ActBell(c); tag = "BELL"; break;
            default: ok = ActKatsu(c); tag = "KATSU"; break;
        }
        if (!ok) return;
        string tr2 = tr + tag + " ";
        if (c.status == 1) { won = true; winTrace = tr2; return; }
        if (!mid.Add(Key(c, true))) return;
        Strokes(c, tr2);
    }

    // A koan is one stroke with no answer: count every winning stroke.
    long nodes; int wins; string firstWin;
    void Koan(St s, string tr, long limit)
    {
        if (nodes > limit || s.ink <= 0) return;
        for (int kind = 0; kind < 4; kind++)
            for (int d = 0; d < (kind == 3 ? 1 : 4); d++)
            {
                if ((kind == 1 && s.leap <= 0) || (kind == 2 && s.ward <= 0) || (kind == 3 && s.katsu <= 0)) continue;
                var c = s.Clone();
                bool ok = kind == 0 ? ActMove(c, DX[d], DY[d]) : kind == 1 ? ActLeap(c, DX[d], DY[d]) : kind == 2 ? ActWard(c, DX[d], DY[d]) : ActKatsu(c);
                if (!ok) continue;
                nodes++;
                string tag = kind == 0 ? TAG[d] : kind == 1 ? "leap" + TAG[d] : kind == 2 ? "ward" + TAG[d] : "KATSU";
                if (c.status == 1) { wins++; if (firstWin == null) firstWin = tr + tag; continue; }
                Koan(c, tr + tag + " ", limit);
            }
    }
    public Result SolveKoan(long limit)
    {
        nodes = 0; wins = 0; firstWin = null;
        Koan(start, "", limit);
        var r = new Result { states = (int)Math.Min(nodes, int.MaxValue), capped = nodes > limit };
        if (wins > 0 && !r.capped) { r.par = 1; r.ways = wins; r.trace = firstWin; }
        return r;
    }

    public int Beam = 0;   // writing stages only: how many positions to carry from stroke to stroke (0 = all, exact)
    public Result Solve(int cap, int maxDepth = 12, double seconds = 1e9)
    {
        var res = new Result();
        var clock = System.Diagnostics.Stopwatch.StartNew();
        var frontier = new List<St> { start };
        var seen = new HashSet<string> { Key(start, false) };
        var ways = new Dictionary<string, double> { [Key(start, false)] = 1 };
        // writing: with everything else equal, a board with more tiles painted is never worse, so a
        // position is dropped when one already seen has painted all it has and more
        var dom = new Dictionary<string, List<ulong>>();
        for (int depth = 1; depth <= maxDepth; depth++)
        {
            var next = new List<St>();
            var layer = new HashSet<string>();
            double W = 0; St winFrom = null; string winStroke = "";
            foreach (var s in frontier)
            {
                outD = new Dictionary<string, St>(); mid = new HashSet<string>(); won = false;
                Strokes(s, "");
                double ws = ways[Key(s, false)];
                if (won) { W += ws; if (winFrom == null) { winFrom = s; winStroke = winTrace; } continue; }
                foreach (var kv in outD)
                {
                    if (rWrite)
                    {
                        noInk = true; string bk = Key(kv.Value, false); noInk = false;
                        if (!dom.TryGetValue(bk, out var lst)) dom[bk] = lst = new List<ulong>();
                        ulong m = kv.Value.inked;
                        if (lst.Any(x => (x & m) == m)) continue;
                        lst.RemoveAll(x => (x & m) == x);
                        lst.Add(m);
                    }
                    if (seen.Add(kv.Key)) { kv.Value.parent = s; next.Add(kv.Value); layer.Add(kv.Key); ways[kv.Key] = ws; }
                    else if (layer.Contains(kv.Key)) ways[kv.Key] += ws;
                }
                if ((seen.Count > cap && !(rWrite && Beam > 0)) || clock.Elapsed.TotalSeconds > seconds) { res.states = seen.Count; res.capped = true; return res; }
            }
            res.states = seen.Count;
            if (W > 0)
            {
                var parts = new List<string> { winStroke };
                for (var p = winFrom; p != null && p.parent != null; p = p.parent) parts.Add(p.stroke);
                parts.Reverse();
                res.par = depth; res.ways = W; res.trace = string.Join(" / ", parts.Select(x => x.Trim()));
                return res;
            }
            if (next.Count == 0) return res;
            if (rWrite && Beam > 0)
            {
                // a character can be painted in very many orders: keep the positions with the most painted
                if (next.Count > Beam) next = next.OrderByDescending(x => BitOperations.PopCount(x.inked)).Take(Beam).ToList();
            }
            else if (seen.Count > cap) { res.capped = true; return res; }
            frontier = next;
        }
        return res;
    }
}

sealed class LevelOut
{
    public int chapter { get; set; } public int seg { get; set; }
    public string name { get; set; } = "";
    public string[] rows { get; set; } = Array.Empty<string>();
    public string[] waza { get; set; } = Array.Empty<string>();
    public string[] rules { get; set; } = Array.Empty<string>();
    public int ink { get; set; } = 4;
    public int par { get; set; } public double ways { get; set; } public int states { get; set; }
    public double score { get; set; } public string trace { get; set; } = "";
}

// One run of generated stages inside a chapter.
sealed record Seg(int chapter, int seg, int count, string[] wazaSets, string palette, string must,
    int minY, int maxY, int parLo, int parHi, double water, double ice, double fire, string rules = "", int inkLo = 4, int inkHi = 4);

static class Gen
{
    static Result SolveRows(string[] rows, string[] waza, int cap, string[] rules = null, int ink = 4)
    {
        var sim = new Sim(rows, ink <= 0 ? 4 : ink, 3, waza.Contains("leap"), waza.Contains("ward"), waza.Contains("katsu"), rules, waza.Contains("bell"));
        if (rules != null && rules.Contains("write")) sim.Beam = 1200;
        return rules != null && (rules.Contains("koan") || rules.Contains("garden")) ? sim.SolveKoan(20_000_000) : sim.Solve(cap);
    }

    static double Score(Result r, string[] rows)
    {
        int ny = rows.Sum(l => l.Count(c => Sim.DEF.ContainsKey(c)));
        return r.par * 10 + Math.Clamp(8 - Math.Log2(r.ways + 1), 0, 8) + ny * 0.5;
    }

    public static void SolveFile(string inPath, string outPath)
    {
        var levels = JsonSerializer.Deserialize<List<LevelOut>>(File.ReadAllText(inPath));
        // JOZU_CAP: how many positions a board may take before it is given up (the long search);
        // JOZU_PAR: how many boards at once, since a long search needs the memory
        int cap = int.TryParse(Environment.GetEnvironmentVariable("JOZU_CAP"), out var c0) ? c0 : 250_000;
        int par = int.TryParse(Environment.GetEnvironmentVariable("JOZU_PAR"), out var p0) ? p0 : -1;
        Parallel.ForEach(levels, new ParallelOptions { MaxDegreeOfParallelism = par }, lv =>
        {
            var sw = System.Diagnostics.Stopwatch.StartNew();
            var r = SolveRows(lv.rows, lv.waza, cap, lv.rules, lv.ink);
            lv.par = r.par; lv.ways = r.ways; lv.states = r.states; lv.trace = r.capped ? "CAPPED" : r.trace;
            if (r.par > 0) lv.score = Score(r, lv.rows);
            lock (levels) Console.WriteLine($"{lv.name,-10} par={lv.par,2} ways={lv.ways,8:0} states={lv.states,8} score={lv.score,5:0.0} {sw.Elapsed.TotalSeconds,5:0.0}s  {lv.trace}");
        });
        File.WriteAllText(outPath, JsonSerializer.Serialize(levels, new JsonSerializerOptions { WriteIndented = true, Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping }));
    }

    // A dry garden: stones scattered on gravel, every open tile reachable.
    static string[] MakeGarden(Random r, Seg g)
    {
        var b = new char[7, 7];
        double p = 0.30 + r.NextDouble() * 0.28;
        for (int y = 0; y < 7; y++) for (int x = 0; x < 7; x++) b[y, x] = r.NextDouble() < p ? '#' : (r.NextDouble() < 0.08 ? 'i' : '.');
        if (r.Next(3) == 0) { int x0 = r.Next(1, 5), y0 = r.Next(1, 5); for (int y = y0; y < y0 + 2; y++) for (int x = x0; x < x0 + 2; x++) b[y, x] = '~'; }
        int hx = r.Next(7), hy = r.Next(7);
        if (b[hy, hx] != '.') return null;
        var seen = new bool[7, 7];
        var st = new Stack<(int, int)>(); st.Push((hx, hy)); seen[hy, hx] = true; int n = 0;
        while (st.Count > 0)
        {
            var (x, y) = st.Pop(); n++;
            foreach (var (dx, dy) in new[] { (1, 0), (-1, 0), (0, 1), (0, -1) })
            {
                int nx = x + dx, ny = y + dy;
                if (nx < 0 || ny < 0 || nx > 6 || ny > 6 || seen[ny, nx] || (b[ny, nx] != '.' && b[ny, nx] != 'i')) continue;
                seen[ny, nx] = true; st.Push((nx, ny));
            }
        }
        if (n < g.inkLo || n > g.inkHi) return null;
        var rows = new string[7];
        for (int y = 0; y < 7; y++)
        {
            var sb = new StringBuilder();
            for (int x = 0; x < 7; x++) sb.Append(x == hx && y == hy ? 'H' : ((b[y, x] == '.' || b[y, x] == 'i') && !seen[y, x] ? '#' : b[y, x]));
            rows[y] = sb.ToString();
        }
        return rows;
    }

    // Characters that can be written with straight strokes on a 7 by 7 board.
    static readonly (string name, string[] rows)[] KANJI =
    {
        ("十|Ten", new[] { "...x...", "...x...", "...x...", "xxxxxxx", "...x...", "...x...", "...x..." }),
        ("口|Mouth", new[] { ".......", ".xxxxx.", ".x...x.", ".x...x.", ".x...x.", ".xxxxx.", "......." }),
        ("日|Sun", new[] { ".xxxxx.", ".x...x.", ".x...x.", ".xxxxx.", ".x...x.", ".x...x.", ".xxxxx." }),
        ("田|Rice Field", new[] { "xxxxxxx", "x..x..x", "x..x..x", "xxxxxxx", "x..x..x", "x..x..x", "xxxxxxx" }),
        ("山|Mountain", new[] { "...x...", "...x...", ".x.x.x.", ".x.x.x.", ".x.x.x.", ".xxxxx.", "......." }),
        ("川|River", new[] { ".x.x.x.", ".x.x.x.", ".x.x.x.", ".x.x.x.", ".x.x.x.", ".x.x.x.", "......." }),
        ("上|Above", new[] { "...x...", "...x...", "...xxx.", "...x...", "...x...", "...x...", "xxxxxxx" }),
        ("下|Below", new[] { "xxxxxxx", "...x...", "...xxx.", "...x...", "...x...", "...x...", "......." }),
        ("中|Middle", new[] { "...x...", ".xxxxx.", ".x.x.x.", ".xxxxx.", "...x...", "...x...", "...x..." }),
        ("王|King", new[] { "xxxxxxx", "...x...", "...x...", ".xxxxx.", "...x...", "...x...", "xxxxxxx" }),
        ("土|Earth", new[] { "...x...", "...x...", ".xxxxx.", "...x...", "...x...", "...x...", "xxxxxxx" }),
        ("工|Craft", new[] { ".xxxxx.", "...x...", "...x...", "...x...", "...x...", "...x...", "xxxxxxx" }),
        ("二|Two", new[] { ".......", ".xxxxx.", ".......", ".......", ".......", "xxxxxxx", "......." }),
        ("三|Three", new[] { ".xxxxx.", ".......", ".......", "..xxx..", ".......", ".......", "xxxxxxx" }),
        ("正|Correct", new[] { "xxxxxxx", "...x...", "...x...", ".x.xxx.", ".x.x...", ".x.x...", "xxxxxxx" }),
        ("止|Stop", new[] { "...x...", "...x...", "...xxx.", ".x.x...", ".x.x...", ".x.x...", "xxxxxxx" }),
        ("干|Dry", new[] { ".xxxxx.", "...x...", "...x...", "xxxxxxx", "...x...", "...x...", "...x..." }),
        ("丁|Block", new[] { "xxxxxxx", "...x...", "...x...", "...x...", "...x...", "...x...", "..xx..." }),
        ("回|Turn", new[] { "xxxxxxx", "x.....x", "x.xxx.x", "x.x.x.x", "x.xxx.x", "x.....x", "xxxxxxx" }),
        ("円|Circle", new[] { "xxxxxxx", "x..x..x", "x..x..x", "xxxxxxx", "x.....x", "x.....x", "x.....x" }),
        // from here on the strokes slant: the second writing chapter
        ("人|Person", new[] { "...x...", "...x...", "...x...", "..x.x..", "..x.x..", ".x...x.", "x.....x" }),
        ("入|Enter", new[] { "..xx...", "...x...", "...x...", "..x.x..", "..x.x..", ".x...x.", "x.....x" }),
        ("大|Great", new[] { "...x...", "...x...", "xxxxxxx", "...x...", "..x.x..", ".x...x.", "x.....x" }),
        ("木|Tree", new[] { "...x...", "xxxxxxx", "...x...", "..xxx..", ".x.x.x.", "x..x..x", "...x..." }),
        ("本|Root", new[] { "...x...", "xxxxxxx", "..xxx..", ".x.x.x.", "x..x..x", "..xxx..", "...x..." }),
        ("小|Small", new[] { "...x...", "...x...", ".x.x.x.", ".x.x.x.", "x..x..x", "...x...", "..xx..." }),
        ("月|Moon", new[] { ".xxxxx.", ".x...x.", ".xxxxx.", ".x...x.", ".xxxxx.", ".x...x.", "x...xx." }),
        ("目|Eye", new[] { ".xxxxx.", ".x...x.", ".xxxxx.", ".x...x.", ".xxxxx.", ".x...x.", ".xxxxx." }),
        ("門|Gate", new[] { "xxx.xxx", "x.x.x.x", "xxx.xxx", "x.....x", "x.....x", "x.....x", "x....xx" }),
        ("井|Well", new[] { "..x.x..", "..x.x..", "xxxxxxx", "..x.x..", "xxxxxxx", "..x.x..", ".x..x.." }),
        ("士|Samurai", new[] { "...x...", "...x...", "xxxxxxx", "...x...", "...x...", "...x...", ".xxxxx." }),
        ("千|Thousand", new[] { "....xx.", ".xxx...", "...x...", "xxxxxxx", "...x...", "...x...", "...x..." }),
        ("天|Heaven", new[] { ".xxxxx.", "...x...", "xxxxxxx", "...x...", "..x.x..", ".x...x.", "x.....x" }),
        ("火|Fire", new[] { "...x...", ".x.x.x.", ".x.x.x.", "...x...", "..x.x..", ".x...x.", "x.....x" }),
        ("出|Go Out", new[] { "...x...", ".x.x.x.", ".xxxxx.", "...x...", "x..x..x", "x..x..x", "xxxxxxx" }),
        ("古|Old", new[] { "...x...", "xxxxxxx", "...x...", ".xxxxx.", ".x...x.", ".x...x.", ".xxxxx." }),
        ("半|Half", new[] { ".x.x.x.", "..xxx..", ".xxxxx.", "...x...", "xxxxxxx", "...x...", "...x..." }),
        ("甲|Armour", new[] { ".xxxxx.", ".x.x.x.", ".xxxxx.", ".x.x.x.", ".xxxxx.", "...x...", "...x..." }),
        ("由|Reason", new[] { "...x...", ".xxxxx.", ".x.x.x.", ".xxxxx.", ".x.x.x.", ".xxxxx.", "......." }),
        ("申|Say", new[] { "...x...", ".xxxxx.", ".x.x.x.", ".xxxxx.", ".x.x.x.", ".xxxxx.", "...x..." }),
        ("旦|Dawn", new[] { ".xxxxx.", ".x...x.", ".xxxxx.", ".x...x.", ".xxxxx.", ".......", "xxxxxxx" }),
        ("白|White", new[] { "...x...", ".xxxxx.", ".x...x.", ".xxxxx.", ".x...x.", ".x...x.", ".xxxxx." }),
        ("百|Hundred", new[] { "xxxxxxx", "...x...", ".xxxxx.", ".x...x.", ".xxxxx.", ".x...x.", ".xxxxx." }),
        ("凸|Convex", new[] { "..xxx..", "..x.x..", "..x.x..", "xxx.xxx", "x.....x", "x.....x", "xxxxxxx" }),
        ("凹|Concave", new[] { "xxx.xxx", "x.x.x.x", "x.x.x.x", "x.xxx.x", "x.....x", "x.....x", "xxxxxxx" }),
        ("力|Strength", new[] { "...x...", "xxxxxx.", "...x.x.", "...x.x.", "..x..x.", ".x...x.", "x..xxx." }),
        ("刀|Sword", new[] { "xxxxxx.", "...x.x.", "...x.x.", "...x.x.", "..x..x.", ".x...x.", "x..xxx." }),
        ("文|Letters", new[] { "...x...", "xxxxxxx", ".x...x.", "..x.x..", "...x...", "..x.x..", "xx...xx" }),
        ("米|Rice", new[] { "x..x..x", ".x.x.x.", "xxxxxxx", "..xxx..", ".x.x.x.", "x..x..x", "...x..." }),
        ("玉|Jewel", new[] { "xxxxxxx", "...x...", "...x...", ".xxxxx.", "...x.x.", "...x...", "xxxxxxx" }),
        ("主|Master", new[] { "...x...", "xxxxxxx", "...x...", ".xxxxx.", "...x...", "...x...", "xxxxxxx" }),
        ("生|Life", new[] { ".x.x...", ".xxxxxx", "x..x...", ".xxxxx.", "...x...", "...x...", "xxxxxxx" }),
        ("手|Hand", new[] { "..xxxx.", "...x...", ".xxxxx.", "...x...", "xxxxxxx", "...x...", "..xx..." }),
    };
    const int STRAIGHT = 20;   // how many of the characters above are made of straight strokes only
    [ThreadStatic] static string lastName;

    // A character to be written: its tiles marked, Suzu and a few yokai on the blank paper around it.
    static string[] MakeWrite(Random r, Seg g)
    {
        var (name, src) = g.rules.Contains("+brush") ? KANJI[r.Next(STRAIGHT, KANJI.Length)] : KANJI[r.Next(STRAIGHT)];
        var b = new char[7, 7];
        for (int y = 0; y < 7; y++) for (int x = 0; x < 7; x++) b[y, x] = src[y][x];
        for (int k = r.Next(0, 3); k > 0; k--) { int x = r.Next(7), y = r.Next(7); if (b[y, x] == '.') b[y, x] = '#'; }
        int hx = r.Next(7), hy = r.Next(7);
        if (b[hy, hx] != '.') return null;
        b[hy, hx] = 'H';
        int ny = r.Next(g.minY, g.maxY + 1);
        for (int k = 0; k < ny; k++)
        {
            char c = g.palette[r.Next(g.palette.Length)];
            bool placed = false;
            for (int tries = 0; tries < 60 && !placed; tries++)
            {
                int x = r.Next(7), y = r.Next(7);
                if (b[y, x] != '.' || Math.Abs(x - hx) + Math.Abs(y - hy) < 3) continue;
                b[y, x] = c; placed = true;
            }
            if (!placed) return null;
        }
        var rows = new string[7];
        for (int y = 0; y < 7; y++) { var sb = new StringBuilder(); for (int x = 0; x < 7; x++) sb.Append(b[y, x]); rows[y] = sb.ToString(); }
        lastName = name;
        return rows;
    }

    static string[] Make(Random r, Seg g)
    {
        lastName = "";
        if (g.rules == "garden") return MakeGarden(r, g);
        if (g.rules.Contains("write")) return MakeWrite(r, g);
        var b = new char[7, 7];
        for (int y = 0; y < 7; y++) for (int x = 0; x < 7; x++) b[y, x] = '.';
        bool sym = r.NextDouble() < 0.65;
        void Put(int x, int y, char c) { if (b[y, x] == '.') { b[y, x] = c; if (sym) { if (b[y, 6 - x] == '.') b[y, 6 - x] = c; } } }
        // water first: a river with fords, a pond, or side channels
        if (r.NextDouble() < g.water)
        {
            int kind = r.Next(4);
            if (kind == 0) { int ry = r.Next(1, 5); for (int x = 0; x < 7; x++) b[ry, x] = '~'; int fords = r.Next(1, 3); for (int k = 0; k < fords; k++) b[ry, r.Next(7)] = '.'; }
            else if (kind == 1) { int x0 = r.Next(1, 4), y0 = r.Next(0, 4), ww = r.Next(2, 4), hh = r.Next(2, 4); for (int y = y0; y < Math.Min(6, y0 + hh); y++) for (int x = x0; x < Math.Min(7, x0 + ww); x++) b[y, x] = '~'; }
            else if (kind == 2) { int y0 = r.Next(0, 3), hh = r.Next(3, 5); for (int y = y0; y < Math.Min(6, y0 + hh); y++) { b[y, 0] = '~'; b[y, 6] = '~'; if (r.Next(2) == 0) { b[y, 1] = '~'; b[y, 5] = '~'; } } }
            else { int cx = r.Next(2, 5); for (int y = 0; y < r.Next(3, 6); y++) b[y, cx] = '~'; }
        }
        if (g.rules.Contains("+bridge"))
        {
            // a river right across the board, with a plank bridge or two
            int ry = r.Next(2, 5);
            for (int x = 0; x < 7; x++) b[ry, x] = '~';
            for (int k = r.Next(1, 3); k > 0; k--) b[ry, r.Next(7)] = 'b';
        }
        if (r.NextDouble() < g.ice)
        {
            int kind = r.Next(3);
            if (kind == 0) { int x0 = r.Next(0, 4), y0 = r.Next(0, 4), ww = r.Next(2, 5), hh = r.Next(2, 5); for (int y = y0; y < Math.Min(6, y0 + hh); y++) for (int x = x0; x < Math.Min(7, x0 + ww); x++) if (b[y, x] == '.') b[y, x] = 'i'; }
            else if (kind == 1) { int cx = r.Next(1, 6); for (int y = r.Next(0, 2); y < r.Next(4, 6); y++) if (b[y, cx] == '.') b[y, cx] = 'i'; int ry = r.Next(1, 5); for (int x = r.Next(0, 2); x < r.Next(5, 7); x++) if (b[ry, x] == '.') b[ry, x] = 'i'; }
            else { for (int k = 0; k < r.Next(4, 10); k++) Put(r.Next(7), r.Next(6), 'i'); }
        }
        int rocks = r.Next(1, 4);
        for (int k = 0; k < rocks; k++) Put(r.Next(0, 4), r.Next(1, 6), '#');
        if (r.NextDouble() < g.fire) for (int k = 0; k < r.Next(1, 4); k++) Put(r.Next(0, 4), r.Next(0, 6), 'f');
        // Suzu
        int hx = 3, hy = 6;
        if (r.NextDouble() < 0.35) { hx = r.Next(7); hy = r.Next(4, 7); }
        if (b[hy, hx] != '.') return null;
        b[hy, hx] = 'H';
        if (g.rules.Contains("+offer"))
            for (int k = r.Next(1, 4); k > 0; k--)
            {
                int x = r.Next(7), y = r.Next(7);
                if (b[y, x] == '.' && Math.Abs(x - hx) + Math.Abs(y - hy) >= 2) b[y, x] = 'm';
            }
        if (g.rules.Contains("+web"))
            for (int k = r.Next(3, 8); k > 0; k--)
            {
                int x = r.Next(7), y = r.Next(7);
                if (b[y, x] == '.') b[y, x] = 'w';
            }
        if (g.rules.Contains("gate"))
        {
            // the torii stands far from where Suzu starts
            bool set = false;
            for (int tries = 0; tries < 60 && !set; tries++)
            {
                int x = r.Next(7), y = r.Next(0, 3);
                if (b[y, x] != '.' || Math.Abs(x - hx) + Math.Abs(y - hy) < 6) continue;
                b[y, x] = 'g'; set = true;
            }
            if (!set) return null;
        }
        // yokai
        int ny = r.Next(g.minY, g.maxY + 1);
        var list = new List<char>(g.must);
        while (list.Count < ny)
        {
            char pc = g.palette[r.Next(g.palette.Length)];
            list.Add(pc);
            if (pc == 'e') list.Add('e');
        }
        foreach (char c in list)
        {
            string kind = Sim.DEF[c].kind;
            bool placed = false;
            for (int tries = 0; tries < 60 && !placed; tries++)
            {
                int x = r.Next(7), y = kind == "tengu" ? r.Next(0, 4) : r.Next(0, 7);
                if (Math.Abs(x - hx) + Math.Abs(y - hy) < (kind == "shinigami" ? 5 : 3)) continue;
                if (kind == "kappa") { if (b[y, x] != '~') continue; }
                else if (b[y, x] != '.' && b[y, x] != 'i') continue;
                b[y, x] = c; placed = true;
            }
            if (!placed) return null;
        }
        var rows = new string[7];
        for (int y = 0; y < 7; y++) { var sb = new StringBuilder(); for (int x = 0; x < 7; x++) sb.Append(b[y, x]); rows[y] = sb.ToString(); }
        return rows;
    }

    // The table of what each chapter's boards are made of.
    public static List<Seg> Segs()
    {
        string[] none = { "" };
        return new List<Seg>
        {
            // chapter, segment, how many, waza sets, palette, must-have, yokai min/max, par lo/hi, water, ice, fire
            new(0, 0, 1, none, "cco", "o", 2, 3, 3, 3, 0, 0, 0),
            new(0, 1, 5, none, "ccooO", "", 3, 5, 3, 6, 0, 0, 0),
            new(1, 0, 2, none, "ttcco", "t", 3, 4, 3, 5, 0.5, 0, 0),
            new(1, 1, 1, new[] { "leap" }, "tTcoO", "t", 3, 5, 4, 5, 0.9, 0, 0),
            new(1, 2, 3, new[] { "leap" }, "tTTcoO", "T", 4, 5, 4, 6, 0.8, 0, 0),
            new(2, 0, 2, new[] { "", "leap" }, "kkcco", "k", 3, 4, 3, 5, 0.2, 0, 0),
            new(2, 1, 1, new[] { "ward", "leap,ward" }, "kkcotT", "k", 3, 5, 4, 5, 0.3, 0, 0),
            new(2, 2, 3, new[] { "ward", "leap,ward", "leap" }, "kkcoOtT", "k", 4, 5, 4, 6, 0.3, 0, 0),
            new(3, 0, 2, new[] { "leap,ward", "leap", "ward" }, "ooOOc", "O", 4, 5, 4, 5, 0.3, 0, 0),
            new(3, 1, 2, new[] { "leap,ward", "leap", "ward" }, "ooOOctTk", "O", 4, 6, 5, 6, 0.4, 0, 0),
            new(3, 2, 2, new[] { "leap", "ward" }, "ooOOctTk", "OO", 5, 6, 5, 7, 0.4, 0, 0),
            new(4, 0, 2, new[] { "leap,ward", "leap", "ward" }, "yyyocO", "yy", 4, 5, 4, 5, 0.5, 0, 0),
            new(4, 1, 2, new[] { "katsu", "leap,katsu" }, "yyoOctk", "y", 4, 6, 5, 6, 0.9, 0, 0),
            new(4, 2, 2, new[] { "katsu", "leap,katsu", "ward,katsu" }, "yyoOOctTk", "yO", 5, 6, 5, 7, 0.8, 0, 0),
            // Snow Country: ice, then umbrellas, then Yuki-onna
            new(5, 0, 3, new[] { "leap", "katsu", "leap,katsu" }, "ooOctT", "o", 4, 5, 4, 6, 0.1, 1, 0),
            new(5, 1, 3, new[] { "leap", "katsu", "ward", "leap,katsu" }, "uuoOctT", "u", 4, 6, 4, 6, 0.2, 1, 0),
            new(5, 2, 3, new[] { "leap", "katsu", "ward", "leap,katsu" }, "uuoOOctTy", "uuT", 5, 6, 5, 7, 0.2, 1, 0),
            new(5, 3, 1, new[] { "leap", "katsu", "" }, "uuoOc", "Wu", 4, 6, 6, 9, 0.1, 1, 0),
            // Kappa Pool
            new(6, 0, 3, new[] { "leap", "katsu", "leap,katsu" }, "ppoc", "p", 4, 5, 4, 6, 1, 0, 0),
            new(6, 1, 3, new[] { "katsu", "ward,katsu", "leap,katsu" }, "ppoOcuty", "ppO", 5, 6, 5, 7, 1, 0.2, 0),
            new(6, 2, 3, new[] { "leap", "leap,katsu" }, "ppoOcutTky", "pt", 5, 7, 5, 8, 1, 0.2, 0),
            new(6, 3, 1, new[] { "leap", "katsu", "leap,katsu", "ward,katsu" }, "ppoOcu", "Ppp", 5, 7, 5, 9, 1, 0, 0),
            // Adashino: fire and walls
            new(7, 0, 4, new[] { "leap", "katsu", "ward", "leap,katsu" }, "nnoOcy", "n", 4, 6, 5, 7, 0.2, 0.1, 1),
            new(7, 1, 5, new[] { "leap", "katsu", "ward", "leap,katsu" }, "nnoOctTyuk", "nnT", 5, 7, 5, 8, 0.4, 0.2, 1),
            new(7, 2, 1, new[] { "leap", "katsu", "leap,katsu" }, "nnoOctTyuk", "nnOT", 6, 8, 6, 10, 0.4, 0.2, 1),
            // Mount Osore: everything
            new(8, 0, 5, new[] { "leap", "katsu", "ward", "leap,katsu" }, "noOctTyukp", "", 6, 7, 5, 8, 0.6, 0.5, 0.5),
            new(8, 1, 5, new[] { "leap", "katsu", "leap,katsu" }, "noOOctTyukp", "O", 6, 7, 6, 9, 0.6, 0.5, 0.5),
            // The Night Parade
            new(9, 0, 4, new[] { "leap", "katsu", "leap,katsu", "ward" }, "noOOctTyukp", "OT", 7, 8, 6, 9, 0.6, 0.5, 0.6),
            new(9, 1, 4, new[] { "leap", "katsu", "leap,katsu" }, "noOOctTyukp", "OO", 6, 8, 7, 10, 0.6, 0.5, 0.6),
            new(9, 2, 1, new[] { "leap", "katsu", "leap,katsu" }, "ckoOnuyt", "cOnuy", 6, 7, 6, 10, 0.5, 0.5, 0.6),
            new(9, 3, 1, new[] { "leap", "katsu", "leap,katsu", "leap,ward" }, "nocO", "Gn", 3, 5, 5, 10, 0.2, 0.6, 0.6),
            // Zen Temple: koan, one stroke each
            new(10, 0, 4, none, "ccook", "", 3, 4, 1, 1, 0.2, 0.3, 0, "koan", 6, 7),
            new(10, 1, 3, new[] { "", "leap" }, "ccooOkkn", "k", 4, 5, 1, 1, 0.3, 0.5, 0, "koan", 8, 9),
            new(10, 2, 3, new[] { "", "leap", "katsu" }, "ccooOkkn", "kO", 5, 6, 1, 1, 0.3, 0.5, 0, "koan", 10, 12),
            // Stone Garden: rake every tile in one stroke (inkLo..inkHi is the number of open tiles)
            new(11, 0, 4, none, "", "", 0, 0, 1, 1, 0, 0, 0, "garden", 11, 15),
            new(11, 1, 3, new[] { "", "leap" }, "", "", 0, 0, 1, 1, 0, 0, 0, "garden", 16, 20),
            new(11, 2, 3, new[] { "", "leap" }, "", "", 0, 0, 1, 1, 0, 0, 0, "garden", 21, 27),
            // The Gate: arrive, do not fight
            new(12, 0, 4, none, "oocct", "o", 3, 4, 3, 4, 0.3, 0, 0, "gate"),
            new(12, 1, 3, new[] { "", "leap" }, "oOtTyuc", "T", 4, 6, 4, 5, 0.4, 0.2, 0.2, "gate"),
            new(12, 2, 3, new[] { "", "leap", "ward" }, "oOtTyuknc", "TO", 5, 7, 4, 7, 0.4, 0.3, 0.3, "gate"),
            // Wet Ink
            new(13, 0, 4, new[] { "", "leap", "katsu" }, "ttToOc", "T", 4, 5, 4, 6, 0.3, 0, 0, "wet"),
            new(13, 1, 3, new[] { "", "leap", "katsu" }, "oOOyuTc", "Oy", 5, 6, 5, 7, 0.3, 0.2, 0.2, "wet"),
            new(13, 2, 3, new[] { "", "leap", "katsu" }, "oOOyuTtkn", "OT", 6, 7, 5, 8, 0.4, 0.3, 0.3, "wet"),
            // Enso: the long brush
            new(14, 0, 4, new[] { "" }, "ccoS", "S", 2, 3, 2, 5, 0.2, 0, 0, "wet,enso", 7, 7),
            new(14, 1, 3, new[] { "", "leap" }, "SOntc", "SS", 3, 4, 2, 6, 0.3, 0.2, 0, "wet,enso", 7, 7),
            new(14, 2, 3, new[] { "", "leap" }, "SOntc", "GS", 3, 5, 2, 8, 0.3, 0.2, 0.2, "wet,enso", 7, 7),
            // The Ink Stone: bank ink, then paint the circle with the short brush
            new(15, 0, 4, new[] { "" }, "ccS", "S", 2, 3, 2, 5, 0.2, 0, 0, "wet,enso,stone"),
            new(15, 1, 3, new[] { "", "leap" }, "SOnc", "SO", 3, 4, 3, 6, 0.3, 0.2, 0, "wet,enso,stone"),
            new(15, 2, 3, new[] { "", "leap" }, "SOnct", "GS", 3, 5, 3, 8, 0.3, 0.2, 0.2, "wet,enso,stone"),
            // No Sword: the brush cannot cut
            new(16, 0, 4, new[] { "", "katsu" }, "ooc", "o", 2, 3, 2, 5, 0.6, 0, 0, "wet,enso,nocut", 7, 7),
            new(16, 1, 3, new[] { "", "katsu", "leap" }, "oOSct", "O", 3, 5, 3, 6, 0.6, 0.2, 0, "wet,enso,nocut", 7, 7),
            new(16, 2, 3, new[] { "katsu", "leap", "leap,katsu" }, "oOSc", "SO", 3, 5, 3, 8, 0.8, 0.2, 0, "wet,enso,nocut", 7, 7),
            // Daruma: topples once per stroke, and gets back up
            new(17, 0, 4, none, "dcco", "d", 3, 4, 3, 5, 0.2, 0, 0),
            new(17, 1, 4, new[] { "", "leap", "katsu" }, "ddoOct", "dd", 4, 6, 4, 7, 0.3, 0.2, 0),
            // Tanuki: a stone until you rest beside it
            new(18, 0, 4, none, "acco", "a", 3, 4, 3, 5, 0.2, 0, 0),
            new(18, 1, 4, new[] { "", "leap", "katsu" }, "aaoOctk", "aa", 4, 6, 4, 7, 0.3, 0.2, 0),
            // The Red Thread: soul-flames that relight while one still burns
            new(19, 0, 4, none, "cco", "ee", 3, 4, 2, 5, 0.2, 0, 0),
            new(19, 1, 4, new[] { "", "leap", "katsu" }, "coOtk", "ee", 4, 6, 3, 7, 0.3, 0.3, 0),
            // Wind: light yokai drift one tile each turn
            new(20, 0, 4, new[] { "", "leap" }, "ccuy", "cc", 3, 5, 3, 5, 0.2, 0, 0, "wind"),
            new(20, 1, 4, new[] { "", "leap", "katsu" }, "ccuyoOt", "ccu", 5, 7, 4, 7, 0.3, 0.2, 0.2, "wind"),
            // Rain: lanterns and fire are out; kappa come ashore
            new(21, 0, 4, new[] { "", "leap" }, "ppcc", "pc", 3, 5, 3, 5, 1, 0, 0.8, "rain"),
            new(21, 1, 4, new[] { "", "leap", "katsu" }, "ppccoOt", "ppc", 5, 7, 4, 7, 1, 0, 0.8, "rain"),
            // Deep Snow: all water is ice
            new(22, 0, 4, new[] { "", "leap" }, "ppoc", "p", 3, 5, 3, 5, 1, 0, 0, "snow"),
            new(22, 1, 4, new[] { "", "leap", "katsu" }, "ppoOctu", "pp", 5, 7, 4, 7, 1, 0, 0, "snow"),
            // Night: the rules are unchanged, only what you can see
            new(23, 0, 4, new[] { "", "leap" }, "ccoo", "cc", 4, 5, 3, 5, 0.2, 0, 0.3, "night"),
            new(23, 1, 4, new[] { "", "leap", "katsu" }, "ccoOtyu", "cc", 5, 7, 4, 7, 0.3, 0.2, 0.3, "night"),
            // Shikigami: what the circle binds can be set down as an ally
            new(24, 0, 4, new[] { "" }, "ccco", "occ", 3, 4, 2, 6, 0.2, 0, 0, "wet,enso,nocut,shiki", 7, 7),
            new(24, 1, 4, new[] { "" }, "ccoOSt", "Occ", 4, 6, 3, 8, 0.3, 0, 0, "wet,enso,nocut,shiki", 7, 7),
            // Shinigami: through anything, and one touch is the end
            new(25, 0, 4, new[] { "", "leap" }, "Xcc", "X", 2, 4, 3, 5, 0.3, 0, 0),
            new(25, 1, 4, new[] { "", "leap", "ward", "katsu" }, "Xoctu", "X", 4, 6, 4, 7, 0.4, 0.2, 0.2),
            // Offerings: walking yokai go to the food, and eat instead of striking
            new(26, 0, 4, none, "ooc", "o", 2, 4, 2, 5, 0.2, 0, 0, "+offer"),
            new(26, 1, 4, new[] { "", "leap", "katsu" }, "oOSuc", "O", 4, 6, 3, 7, 0.3, 0.1, 0, "+offer"),
            // The Temple Bell: once, nothing strikes and nothing moves
            new(27, 0, 4, none, "ooct", "o", 3, 4, 2, 5, 0.2, 0, 0, "+bell"),
            new(27, 1, 4, new[] { "", "leap", "katsu" }, "oOtTuyc", "T", 4, 6, 3, 7, 0.3, 0.2, 0, "+bell"),
            // The Bridge: planks crossed fall in, with whatever followed
            new(28, 0, 4, none, "ooc", "o", 2, 4, 2, 5, 0, 0, 0, "+bridge"),
            new(28, 1, 4, new[] { "", "leap", "katsu" }, "oOSuc", "S", 3, 6, 3, 7, 0, 0, 0, "+bridge"),
            // The Spider: a web ends the stroke
            new(29, 0, 4, none, "ccoo", "o", 3, 4, 3, 5, 0.2, 0, 0, "+web"),
            new(29, 1, 4, new[] { "", "leap", "katsu" }, "coOtu", "", 4, 6, 4, 7, 0.3, 0, 0, "+web"),
            // Kamaitachi: three tiles a turn, and the three must matter
            new(30, 0, 4, new[] { "", "leap" }, "Kco", "K", 3, 4, 3, 5, 0.3, 0, 0),
            new(30, 1, 4, new[] { "", "leap", "ward", "katsu" }, "KKoctu", "KK", 4, 6, 4, 7, 0.4, 0.2, 0),
            // The Seals: only the first yokai left, in reading order, can be harmed
            new(31, 0, 4, none, "ccco", "", 3, 4, 3, 5, 0.2, 0, 0, "order"),
            new(31, 1, 4, new[] { "", "leap", "katsu" }, "ccoOtn", "", 4, 6, 4, 7, 0.3, 0.2, 0, "order"),
            // The Character: paint every marked tile
            new(32, 0, 4, none, "co", "", 1, 2, 2, 5, 0, 0, 0, "write", 6, 8),
            new(32, 1, 4, new[] { "", "leap" }, "coOuty", "", 2, 4, 3, 8, 0, 0, 0, "write", 5, 7),
            // The Lure: an offering on the far side of a plank
            new(33, 0, 4, none, "ooO", "o", 2, 4, 3, 5, 0, 0, 0, "+offer,+bridge"),
            new(33, 1, 4, new[] { "", "leap", "katsu" }, "oOSu", "S", 3, 5, 4, 7, 0, 0, 0, "+offer,+bridge"),
            // The Storm: wind, the bell, and the weasel that rides the wind
            new(34, 0, 4, none, "ccuyK", "Kc", 3, 5, 3, 5, 0.2, 0, 0, "wind,+bell"),
            new(34, 1, 4, new[] { "", "leap" }, "ccuyKoO", "Kcu", 5, 7, 4, 7, 0.3, 0.2, 0, "wind,+bell"),
            // The Knot: seals among webs, and then offerings as well
            new(35, 0, 4, none, "ccoo", "", 3, 4, 4, 6, 0.2, 0, 0, "order,+web"),
            new(35, 1, 4, new[] { "", "leap", "katsu" }, "coOKt", "", 4, 6, 5, 8, 0.3, 0, 0, "order,+web,+offer"),
            // The Brush: characters whose strokes slant
            new(36, 0, 4, none, "co", "", 1, 2, 3, 6, 0, 0, 0, "write,+brush", 5, 6),
            new(36, 1, 4, new[] { "", "leap" }, "coOuK", "", 2, 3, 4, 9, 0, 0, 0, "write,+brush", 5, 6),
        };
    }

    // One attempt at a board for a segment: lay it out, solve it, and keep it only if it passes that
    // chapter's tests. Returns null when the attempt is thrown away.
    public static LevelOut TryOne(Seg g, int seed, double secs)
    {
            var r = new Random(seed);
            var rows = Make(r, g);
            if (rows == null) return null;
            string kanjiName = lastName;
            // JOZU_WAZA=ward: only boards that grant that technique are made; a segment that never
            // grants it grants it alone
            var must = Environment.GetEnvironmentVariable("JOZU_WAZA");
            var sets = g.wazaSets;
            if (!string.IsNullOrEmpty(must))
            {
                sets = sets.Where(x => x.Split(',').Contains(must)).ToArray();
                if (sets.Length == 0) sets = new[] { must };
            }
            var waza = sets[r.Next(sets.Length)].Split(',', StringSplitOptions.RemoveEmptyEntries);
            var feats = g.rules.Split(',', StringSplitOptions.RemoveEmptyEntries).Where(x => x.StartsWith("+") && x != "+brush").ToArray();
            if (feats.Contains("+bell")) waza = waza.Append("bell").ToArray();
            var rules = g.rules.Split(',', StringSplitOptions.RemoveEmptyEntries).Where(x => !x.StartsWith("+"))
                .Select(x => x == "wind" ? "wind:" + "RLDU"[r.Next(4)] : x).ToArray();
            bool B = waza.Contains("bell");
            bool weather = rules.Any(x => x.StartsWith("wind") || x == "rain" || x == "snow");
            int ink = r.Next(g.inkLo, g.inkHi + 1);
            bool garden = rules.Contains("garden");
            if (garden) ink = rows.Sum(l => l.Count(ch => ch == '.' || ch == 'i' || ch == 'H')) - 1;
            bool L = waza.Contains("leap"), Wd = waza.Contains("ward"), K = waza.Contains("katsu");
            var sim = new Sim(rows, ink, 3, L, Wd, K, rules, B);
            Result res;
            double score;
            if (rules.Contains("koan") || garden)
            {
                // keep boards with very few answers that need nearly all the ink
                res = sim.SolveKoan(3_000_000);
                if (res.par != 1 || res.ways > (garden ? 6 : 4)) return null;
                int used = res.trace.Split(' ', StringSplitOptions.RemoveEmptyEntries).Length;
                if (!garden && used < ink - 1) return null;
                score = ink * 10 - res.ways;
            }
            else
            {
                if (sim.Danger(sim.start, sim.start.hx, sim.start.hy)) return null;
                if (g.rules.Contains("+brush")) sim.Beam = 1200;
                res = sim.Solve(rules.Contains("enso") ? 25_000 : 120_000, g.parHi, sim.Beam > 0 ? secs * 4 : secs);
                if (rules.Contains("stone") && res.par > 0 && !res.trace.Split('/').Any(x => x.Trim().Split(' ', StringSplitOptions.RemoveEmptyEntries).Length > 4)) return null;   // must spend banked ink
                if (res.par < g.parLo || res.par > g.parHi) return null;
                if (rules.Contains("shiki") && !res.trace.Contains("shiki")) return null;   // a familiar must actually be set
                if (B && !res.trace.Contains("BELL")) return null;   // a bell that is never rung is not a bell stage
                if (g.palette.Contains('K') && feats.Length == 0 && rules.Length == 0)
                {
                    // the weasel's three steps must change the answer
                    var slow = new Sim(rows, ink, 3, L, Wd, K, rules, B, true).Solve(120_000, g.parHi + 2, secs);
                    if (slow.capped || slow.par == res.par) return null;
                }
                if (weather)
                {
                    // the weather must change the answer, for better or worse
                    var dry = new Sim(rows, ink, 3, L, Wd, K).Solve(120_000, g.parHi + 2, secs);
                    if (dry.capped || dry.par == res.par) return null;
                }
                else if (rules.Contains("order"))
                {
                    // the seals must cost at least a stroke
                    var free = new Sim(rows, ink, 3, L, Wd, K).Solve(120_000, res.par - 1, secs);
                    if (free.capped || free.par <= 0) return null;
                }
                else if (feats.Length > 0)
                {
                    string[] bare = rows.Select(l => l.Replace('m', '.').Replace('b', '.').Replace('w', '.')).ToArray();
                    if (B)
                    {
                        if (!res.trace.Contains("BELL")) return null;
                        var mute = new Sim(rows, ink, 3, L, Wd, K, rules).Solve(120_000, res.par, secs);
                        if (mute.capped || mute.par > 0) return null;   // the bell must be what makes this par possible
                    }
                    else if (feats.Contains("+web"))
                    {
                        var clear = new Sim(bare, ink, 3, L, Wd, K, rules).Solve(120_000, res.par - 1, secs);
                        if (clear.capped || clear.par <= 0) return null;   // the webs must cost at least a stroke
                    }
                    else
                    {
                        var clear = new Sim(bare, ink, 3, L, Wd, K, rules).Solve(120_000, res.par, secs);
                        if (clear.capped || clear.par > 0) return null;   // the offering or the bridge must be what makes this par possible
                    }
                }
                else if (rules.Length > 0 && !rules.Contains("write") && !rules.Contains("gate") && (!rules.Contains("nocut") || rules.Contains("shiki")) && !rules.Contains("night"))
                {
                    // the new rule must be what makes this par possible
                    // for an enso board, the circle itself must matter: compare against wet ink alone
                    var lesser = rules.Contains("shiki") ? rules.Where(x => x != "shiki").ToArray()
                        : rules.Contains("enso") ? rules.Where(x => x != "enso" && x != "stone").ToArray() : Array.Empty<string>();
                    var plain = new Sim(rows, ink, 3, L, Wd, K, lesser).Solve(rules.Contains("enso") ? 25_000 : 120_000, res.par, secs);
                    if (plain.capped || plain.par > 0) return null;
                }
                score = Score(res, rows);
            }
            if (!string.IsNullOrEmpty(must) && res.par > 0)
            {
                // and mastery must need it: without it the same count must be out of reach
                var bare = new Sim(rows, ink, 3, L && must != "leap", Wd && must != "ward", K && must != "katsu", rules, B && must != "bell").Solve(250_000, res.par, secs * 4);
                if (bare.capped || bare.par > 0) return null;
            }
            var lv = new LevelOut { chapter = g.chapter, seg = g.seg, name = kanjiName ?? "", rows = rows, waza = waza, rules = rules, ink = ink, par = res.par, ways = res.ways, states = res.states, trace = res.trace, score = score };
            return lv;
    }

    // pool = true: keep every accepted board of the style chapters (10+), for the assembler to build a ladder from
    public static void Generate(string outPath, int seed, bool pool = false, int only = -1)
    {
        var segs = Segs();
        var jopt = new JsonSerializerOptions { WriteIndented = true, Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping };
        var all = File.Exists(outPath) ? JsonSerializer.Deserialize<List<LevelOut>>(File.ReadAllText(outPath)) : new List<LevelOut>();
        foreach (var g in segs)
        {
            if (pool && g.chapter < 10) continue;
            if (only >= 0 && g.chapter != only) continue;
            if (all.Any(l => l.chapter == g.chapter && l.seg == g.seg)) { Console.WriteLine($"ch{g.chapter} seg{g.seg}: already done"); continue; }
            var found = new List<LevelOut>();
            var lk = new object();
            int want = only >= 0 ? 90 : pool ? 36 : g.count * 5, attempts = 0;
            var sw = System.Diagnostics.Stopwatch.StartNew();
            while (found.Count < want && attempts < 60000 && sw.Elapsed.TotalSeconds < (pool ? 170 : 200))
            {
                int baseSeed = seed * 100003 + g.chapter * 1009 + g.seg * 101 + attempts;
                attempts += 64;
                Parallel.For(0, 64, k =>
                {
                    var lv = TryOne(g, baseSeed + k, 10);
                    if (lv != null) lock (lk) found.Add(lv);
                });
            }
            // spread the picks across the par range, hardest-looking board for each target
            var pick = new List<LevelOut>();
            for (int i = 0; i < g.count; i++)
            {
                // a lone slot is a boss: take the hardest board found
                double target = g.count == 1 ? g.parHi : g.parLo + (g.parHi - g.parLo) * i / (double)(g.count - 1);
                var best = found.Where(f => !pick.Contains(f) && !pick.Any(p => string.Join("", p.rows) == string.Join("", f.rows)))
                    .OrderBy(f => Math.Abs(f.par - target)).ThenByDescending(f => f.score).FirstOrDefault();
                if (best != null) pick.Add(best);
            }
            pick = pick.OrderBy(p => p.score).ToList();
            // one chapter asked for by number: every board found is kept, to be chosen from by hand
            if (pool || only >= 0) pick = found.GroupBy(f => string.Join("", f.rows)).Select(x => x.First()).ToList();
            Console.Out.Flush();
            Console.WriteLine($"ch{g.chapter} seg{g.seg}: tried {attempts}, kept {found.Count}, picked {pick.Count}/{g.count}  pars [{string.Join(",", pick.Select(p => p.par))}]  ({sw.Elapsed.TotalSeconds:0}s)");
            all.AddRange(pick);
            File.WriteAllText(outPath, JsonSerializer.Serialize(all, jopt));
        }
        File.WriteAllText(outPath, JsonSerializer.Serialize(all, new JsonSerializerOptions { WriteIndented = true, Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping }));
    }
}

static class Program
{
    static void Main(string[] a)
    {
        Console.OutputEncoding = Encoding.UTF8;
        if (a.Length >= 3 && a[0] == "solve") Gen.SolveFile(a[1], a[2]);
        else if (a.Length >= 2 && a[0] == "gen") Gen.Generate(a[1], a.Length > 2 ? int.Parse(a[2]) : 1, a.Length > 3 && a[3] == "pool", a.Length > 4 ? int.Parse(a[4]) : -1);
        else Console.WriteLine("usage: solve in.json out.json | gen out.json [seed [pool [chapter]]]");
    }
}
