using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Text;
using Microsoft.VisualBasic.FileIO;

public static class FiltraCsv
{
    // Lê um .csv.gz e grava só as linhas cuja coluna `coluna` está em `valores`.
    public static int Roda(string gz, string coluna, string[] valores, string saida)
    {
        var set = new HashSet<string>(valores);
        int n = 0;
        using (var fs = File.OpenRead(gz))
        using (var z = new GZipStream(fs, CompressionMode.Decompress))
        using (var sr = new StreamReader(z, Encoding.UTF8))
        using (var p = new TextFieldParser(sr))
        using (var w = new StreamWriter(saida, false, new UTF8Encoding(false)))
        {
            p.TextFieldType = FieldType.Delimited; p.SetDelimiters(","); p.HasFieldsEnclosedInQuotes = true;
            var cab = p.ReadFields();
            int idx = Array.IndexOf(cab, coluna);
            if (idx < 0) throw new Exception("coluna nao encontrada: " + coluna + " em " + string.Join(",", cab));
            w.WriteLine(string.Join(",", cab.Select(Q)));
            while (!p.EndOfData)
            {
                var f = p.ReadFields();
                if (f.Length > idx && set.Contains(f[idx])) { w.WriteLine(string.Join(",", f.Select(Q))); n++; }
            }
        }
        return n;
    }
    static string Q(string s) { return "\"" + (s ?? "").Replace("\"", "\"\"") + "\""; }
}
