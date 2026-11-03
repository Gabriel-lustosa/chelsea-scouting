using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using System.Web.Script.Serialization;

public static class Levantamento
{
    static readonly string[] Metricas = new string[] {
        "jogos","gols","gols_contra_proprio","chutes","xg","xg_sem_penalti","penaltis",
        "passes","passes_certos","passes_chave","passes_ultimo_terco","passes_area","passes_progressivos",
        "conducoes_progressivas","dribles_certos","dribles",
        "desarmes_ganhos","interceptacoes","recuperacoes","recuperacoes_terco_ofensivo","pressoes","bloqueios","cortes",
        "erros_levaram_chute","perdas_bola","duelos_aereos_ganhos","duelos_aereos_perdidos"
    };

    static double D(object o) { return o == null ? 0.0 : Convert.ToDouble(o, CultureInfo.InvariantCulture); }
    static Dictionary<string, object> M(Dictionary<string, object> d, string k)
    {
        object o; return d != null && d.TryGetValue(k, out o) ? o as Dictionary<string, object> : null;
    }
    static string N(Dictionary<string, object> d, string k)
    {
        var s = M(d, k); object o; return s != null && s.TryGetValue("name", out o) ? (string)o : null;
    }
    static double[] Loc(Dictionary<string, object> d, string k)
    {
        object o; if (d == null || !d.TryGetValue(k, out o) || o == null) return null;
        var a = (object[])o; return new double[] { D(a[0]), D(a[1]) };
    }
    static bool Has(Dictionary<string, object> d, string k) { object o; return d != null && d.TryGetValue(k, out o) && o != null; }
    static double DistGol(double[] p) { return Math.Sqrt(Math.Pow(120 - p[0], 2) + Math.Pow(40 - p[1], 2)); }
    static bool NaArea(double[] p) { return p[0] >= 102 && p[1] >= 18 && p[1] <= 62; }

    public static string Setor(string pos)
    {
        if (pos == null) return "Sem posicao";
        if (pos == "Goalkeeper") return "Goleiro";
        if (pos.EndsWith("Back")) return "Defesa";
        if (pos.Contains("Midfield")) return "Meio";
        return "Ataque"; // Wing, Forward, Secondary Striker
    }

    // chave: time|setor  (setor "Time" = total do time; "Sofrido" = o que o adversário fez contra)
    static Dictionary<string, Dictionary<string, double>> acc = new Dictionary<string, Dictionary<string, double>>();
    static Dictionary<string, Dictionary<string, double>> jog = new Dictionary<string, Dictionary<string, double>>();
    static Dictionary<string, string> jogTime = new Dictionary<string, string>();
    static Dictionary<string, Dictionary<string, double>> posMin = new Dictionary<string, Dictionary<string, double>>();

    static void Add(Dictionary<string, Dictionary<string, double>> dic, string key, string m, double v)
    {
        Dictionary<string, double> d;
        if (!dic.TryGetValue(key, out d)) { d = new Dictionary<string, double>(); dic[key] = d; }
        double cur; d.TryGetValue(m, out cur); d[m] = cur + v;
    }

    static void Conta(string time, string adversario, string setor, string jogador, string m, double v)
    {
        Add(acc, time + "|Time", m, v);
        Add(acc, time + "|" + setor, m, v);
        Add(acc, adversario + "|Sofrido", m, v);
        if (jogador != null) { Add(jog, jogador, m, v); }
    }

    static double ParseMin(object o)
    {
        if (o == null) return -1; var p = ((string)o).Split(':');
        return int.Parse(p[0]) + int.Parse(p[1]) / 60.0;
    }

    public static string Roda(string pastaEventos, string pastaLineups, string matchesJson, string saida)
    {
        var js = new JavaScriptSerializer(); js.MaxJsonLength = int.MaxValue;
        var partidas = (object[])js.DeserializeObject(File.ReadAllText(matchesJson, Encoding.UTF8));
        int n = 0;
        foreach (Dictionary<string, object> p in partidas)
        {
            string id = Convert.ToString(p["match_id"]);
            string casa = (string)M(p, "home_team")["home_team_name"];
            string fora = (string)M(p, "away_team")["away_team_name"];
            var ev = (object[])js.DeserializeObject(File.ReadAllText(Path.Combine(pastaEventos, id + ".json"), Encoding.UTF8));
            Add(acc, casa + "|Time", "jogos", 1); Add(acc, fora + "|Time", "jogos", 1);
            Add(acc, casa + "|Sofrido", "jogos", 1); Add(acc, fora + "|Sofrido", "jogos", 1);
            double fim = 0;
            foreach (Dictionary<string, object> e in ev)
            {
                string tipo = N(e, "type"); string time = N(e, "team");
                if (Has(e, "minute")) fim = Math.Max(fim, D(e["minute"]) + D(e["second"]) / 60.0);
                if (time == null) continue;
                string adv = time == casa ? fora : casa;
                string pos = N(e, "position"); string setor = Setor(pos);
                string jogador = N(e, "player");
                if (jogador != null) jogTime[jogador] = time;
                var loc = Loc(e, "location");
                switch (tipo)
                {
                    case "Shot":
                    {
                        var s = M(e, "shot"); double xg = D(s["statsbomb_xg"]);
                        bool pen = N(s, "type") == "Penalty";
                        Conta(time, adv, setor, jogador, "chutes", 1);
                        Conta(time, adv, setor, jogador, "xg", xg);
                        if (!pen) Conta(time, adv, setor, jogador, "xg_sem_penalti", xg); else Conta(time, adv, setor, jogador, "penaltis", 1);
                        if (N(s, "outcome") == "Goal") Conta(time, adv, setor, jogador, "gols", 1);
                        break;
                    }
                    case "Own Goal For":
                        Add(acc, time + "|Time", "gols", 1); Add(acc, time + "|Time", "gols_contra_proprio", 1);
                        Add(acc, adv + "|Sofrido", "gols", 1); Add(acc, adv + "|Sofrido", "gols_contra_proprio", 1);
                        break;
                    case "Pass":
                    {
                        var ps = M(e, "pass");
                        string ptipo = N(ps, "type");
                        if (ptipo == "Throw-in") break;
                        bool certo = !Has(ps, "outcome");
                        var fimP = Loc(ps, "end_location");
                        Conta(time, adv, setor, jogador, "passes", 1);
                        if (certo) Conta(time, adv, setor, jogador, "passes_certos", 1);
                        if (Has(ps, "shot_assist") || Has(ps, "goal_assist")) Conta(time, adv, setor, jogador, "passes_chave", 1);
                        if (certo && loc != null && fimP != null)
                        {
                            if (loc[0] < 80 && fimP[0] >= 80) Conta(time, adv, setor, jogador, "passes_ultimo_terco", 1);
                            if (!NaArea(loc) && NaArea(fimP)) Conta(time, adv, setor, jogador, "passes_area", 1);
                            bool bolaParada = ptipo == "Corner" || ptipo == "Free Kick" || ptipo == "Goal Kick" || ptipo == "Kick Off";
                            if (!bolaParada && fimP[0] >= 60 && DistGol(fimP) <= 0.75 * DistGol(loc)) Conta(time, adv, setor, jogador, "passes_progressivos", 1);
                        }
                        break;
                    }
                    case "Carry":
                    {
                        var fimC = Loc(M(e, "carry"), "end_location");
                        if (loc != null && fimC != null && fimC[0] >= 60 && DistGol(fimC) <= 0.75 * DistGol(loc) && (fimC[0] - loc[0]) >= 5)
                            Conta(time, adv, setor, jogador, "conducoes_progressivas", 1);
                        break;
                    }
                    case "Dribble":
                        Conta(time, adv, setor, jogador, "dribles", 1);
                        if (N(M(e, "dribble"), "outcome") == "Complete") Conta(time, adv, setor, jogador, "dribles_certos", 1);
                        break;
                    case "Duel":
                    {
                        var du = M(e, "duel"); string o = N(du, "outcome");
                        if (N(du, "type") == "Tackle" && (o == "Won" || o == "Success In Play" || o == "Success Out")) Conta(time, adv, setor, jogador, "desarmes_ganhos", 1);
                        if (N(du, "type") == "Aerial Lost") Conta(time, adv, setor, jogador, "duelos_aereos_perdidos", 1);
                        break;
                    }
                    case "Interception":
                    {
                        string o = N(M(e, "interception"), "outcome");
                        if (o == "Won" || o == "Success In Play" || o == "Success Out") Conta(time, adv, setor, jogador, "interceptacoes", 1);
                        break;
                    }
                    case "Ball Recovery":
                        if (!Has(M(e, "ball_recovery"), "recovery_failure"))
                        {
                            Conta(time, adv, setor, jogador, "recuperacoes", 1);
                            if (loc != null && loc[0] >= 80) Conta(time, adv, setor, jogador, "recuperacoes_terco_ofensivo", 1);
                        }
                        break;
                    case "Pressure": Conta(time, adv, setor, jogador, "pressoes", 1); break;
                    case "Block": Conta(time, adv, setor, jogador, "bloqueios", 1); break;
                    case "Clearance": Conta(time, adv, setor, jogador, "cortes", 1); break;
                    case "Error": Conta(time, adv, setor, jogador, "erros_levaram_chute", 1); break;
                    case "Dispossessed": Conta(time, adv, setor, jogador, "perdas_bola", 1); break;
                    case "Miscontrol": Conta(time, adv, setor, jogador, "perdas_bola", 1); break;
                }
                // duelo aéreo ganho aparece como atributo em vários tipos de evento
                foreach (string k in new string[] { "pass", "shot", "clearance", "miscontrol" })
                {
                    var sub = M(e, k); object aw;
                    if (sub != null && sub.TryGetValue("aerial_won", out aw) && aw is bool && (bool)aw) Conta(time, adv, setor, jogador, "duelos_aereos_ganhos", 1);
                }
            }
            // minutos por jogador e posição, pelas escalações
            string lp = Path.Combine(pastaLineups, id + ".json");
            if (File.Exists(lp))
            {
                var lu = (object[])js.DeserializeObject(File.ReadAllText(lp, Encoding.UTF8));
                foreach (Dictionary<string, object> t in lu)
                {
                    string tn = (string)t["team_name"];
                    foreach (Dictionary<string, object> pl in (object[])t["lineup"])
                    {
                        string nome = (string)pl["player_name"]; jogTime[nome] = tn;
                        object posso; if (!pl.TryGetValue("positions", out posso) || posso == null) continue;
                        foreach (Dictionary<string, object> ps in (object[])posso)
                        {
                            double ini = ParseMin(ps["from"]); double ate = ParseMin(ps.ContainsKey("to") ? ps["to"] : null);
                            if (ate < 0) ate = fim;
                            double min = Math.Max(0, ate - ini);
                            Add(jog, nome, "minutos", min);
                            Add(posMin, nome, (string)ps["position"], min);
                        }
                    }
                }
            }
            n++;
        }

        var ci = CultureInfo.InvariantCulture;
        using (var w = new StreamWriter(Path.Combine(saida, "times_setores.csv"), false, new UTF8Encoding(false)))
        {
            w.WriteLine("time;setor;" + string.Join(";", Metricas));
            foreach (var kv in acc.OrderBy(x => x.Key))
            {
                var parts = kv.Key.Split('|');
                w.WriteLine(parts[0] + ";" + parts[1] + ";" + string.Join(";", Metricas.Select(m => { double v; kv.Value.TryGetValue(m, out v); return v.ToString("0.####", ci); })));
            }
        }
        using (var w = new StreamWriter(Path.Combine(saida, "jogadores.csv"), false, new UTF8Encoding(false)))
        {
            w.WriteLine("jogador;time;posicao_principal;setor;minutos;" + string.Join(";", Metricas.Skip(1)));
            foreach (var kv in jog.OrderBy(x => x.Key))
            {
                string pp = null; Dictionary<string, double> pm;
                if (posMin.TryGetValue(kv.Key, out pm) && pm.Count > 0) pp = pm.OrderByDescending(x => x.Value).First().Key;
                string t; jogTime.TryGetValue(kv.Key, out t);
                double mins; kv.Value.TryGetValue("minutos", out mins);
                w.WriteLine(kv.Key + ";" + t + ";" + pp + ";" + Setor(pp) + ";" + mins.ToString("0.#", ci) + ";" + string.Join(";", Metricas.Skip(1).Select(m => { double v; kv.Value.TryGetValue(m, out v); return v.ToString("0.####", ci); })));
            }
        }
        return n + " partidas processadas";
    }
}
