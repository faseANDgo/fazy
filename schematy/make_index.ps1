# Generuje index.html z listy PDF-ow w folderze + opcjonalnych danych z schematy.csv
$root = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }

# --- dane opisowe z CSV (kolumny: naam;discipline;groep;titel;revisie;revisiedatum;controller) ---
$meta = @{}
$csvPath = Join-Path $root 'schematy.csv'
if (Test-Path $csvPath) {
    $delim = if ((Get-Content $csvPath -TotalCount 1) -match ';') { ';' } else { ',' }
    Import-Csv -Path $csvPath -Delimiter $delim -Encoding UTF8 | ForEach-Object {
        $k = ([string]$(if ($_.naam) { $_.naam } else { $_.plik })).Trim().ToLower() -replace '\.pdf$',''
        if ($k) { $meta[$k] = $_ }
    }
}

# --- lista PDF-ow ---
$rows = @(Get-ChildItem -Path $root -Recurse -File -Filter *.pdf | Sort-Object FullName | ForEach-Object {
    $rel  = $_.FullName.Substring($root.Length).TrimStart('\','/') -replace '\\','/'
    $href = ($rel -split '/' | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/'
    $m    = $meta[$_.BaseName.ToLower()]
    [ordered]@{
        plik = $_.Name; href = $href
        typ  = [string]$m.discipline; lok = [string]$m.groep; opis = [string]$m.titel
        rew  = [string]$m.revisie; data = [string]$m.revisiedatum; ctrl = [string]$m.controller
    }
})
$json = (ConvertTo-Json -InputObject $rows -Compress).Replace('</', '<\/')

$template = @'
<!doctype html>
<html lang="pl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Schematy</title>
<style>
  :root { --bg:#fff; --row:#edebe9; --rowh:#e1dfdd; --border:transparent; --text:#323130; --muted:#605e5c;
          --accent:#986f0b; --field:#fff; --font:"Segoe UI",system-ui,-apple-system,sans-serif; }
  [data-theme="amber"] { --bg:#000; --row:#070500; --rowh:#1a1200; --border:#3a2800; --text:#ffb000;
          --muted:#a87400; --accent:#ffb000; --field:#0a0700; --font:"Courier New",ui-monospace,monospace; }
  * { box-sizing:border-box; }
  body { margin:0; background:var(--bg); color:var(--text); font:14px/1.35 var(--font); }
  .wrap { max-width:1500px; margin:0 auto; padding:0 12px 24px; }
  .tytul { font-size:22px; font-weight:600; margin:18px 0 6px; }
  .top { position:sticky; top:0; background:var(--bg); z-index:2; padding:12px 0 6px; }
  .bar { display:flex; gap:8px; align-items:center; margin-bottom:8px; }
  #q { flex:1; padding:8px 12px; font:inherit; color:var(--text); background:var(--field);
       border:1px solid var(--muted); border-radius:6px; outline:none; }
  #q:focus { border-color:var(--accent); }
  #q::placeholder { color:var(--muted); }
  button { font:inherit; color:var(--text); background:var(--field); border:1px solid var(--muted);
           border-radius:6px; padding:8px 12px; cursor:pointer; }
  button:hover { border-color:var(--accent); }
  #licznik { color:var(--muted); font-size:12px; white-space:nowrap; }
  .grid { display:grid; grid-template-columns:30px 26px minmax(120px,1.1fr) 50px minmax(90px,.9fr) minmax(200px,3fr) 84px 110px minmax(80px,.8fr);
          column-gap:12px; align-items:center; }
  .head { padding:4px 16px; color:var(--muted); font-weight:600; font-size:13px; }
  .head button { all:unset; cursor:pointer; text-align:left; }
  .head button:hover { color:var(--text); }
  .head .on::after { content:" \25BE"; } .head .asc::after { content:" \25B4"; }
  a.row { padding:10px 16px; margin-bottom:6px; background:var(--row); border:1px solid var(--border);
          border-radius:12px; color:var(--text); text-decoration:none; }
  a.row:hover, a.row:focus { background:var(--rowh); outline:none; border-color:var(--accent); }
  .opis { color:var(--muted); } a.row .muted { color:var(--muted); }
  svg { display:block; }
  .leeg { color:var(--muted); padding:24px; text-align:center; }
  @media (max-width:820px) {
    .grid { grid-template-columns:26px 1fr 90px; }
    .grid > :nth-child(1), .grid > :nth-child(4), .grid > :nth-child(5), .grid > :nth-child(7), .grid > :nth-child(9) { display:none; }
    .opis { grid-column:2 / 4; }
  }
</style>
</head>
<body>
<div class="wrap">
  <h1 class="tytul">Coroos Kapelle Schema's</h1>
  <div class="top">
    <div class="bar">
      <input id="q" type="search" placeholder="Doorzoek deze bibliotheek..." autofocus>
      <span id="licznik"></span>
      <button id="motyw" type="button" title="Zmień wygląd">Motyw</button>
    </div>
    <div class="grid head" id="naglowki"></div>
  </div>
  <div id="lista"></div>
</div>

<script>
const DATA = @@DATA@@;
const KOLUMNY = [['plik','Naam'],['typ','Discipline'],['lok','Groep'],['opis','Titel'],['rew','Revisie'],['data','Revisiedatum'],['ctrl','Controller']];
const ICO_OK  = '<svg width="18" height="18" viewBox="0 0 18 18"><circle cx="9" cy="9" r="8" fill="var(--accent)"/><path d="M5 9.2l2.7 2.6L13 6.5" fill="none" stroke="var(--row)" stroke-width="1.8"/></svg>';
const ICO_PDF = '<svg width="16" height="20" viewBox="0 0 16 20"><path d="M2 1h9l4 4v14H2z" fill="none" stroke="var(--muted)" stroke-width="1.2"/><rect x="4" y="9" width="8" height="3" fill="#c0392b"/><path d="M4 14h8M4 16.5h8" stroke="var(--muted)" stroke-width="1"/></svg>';

let sleutel = 'data', oplopend = false;
const q = document.getElementById('q'), lijst = document.getElementById('lista'),
      lic = document.getElementById('licznik'), kop = document.getElementById('naglowki');

function dataNum(s) { const m = /^(\d+)-(\d+)-(\d+)$/.exec(s || ''); return m ? +m[3]*10000 + +m[2]*100 + +m[1] : 0; }
function waarde(r, k) { return k === 'data' ? dataNum(r.data) : k === 'rew' && /^\d+$/.test(r.rew) ? +r.rew : (r[k] || '').toLowerCase(); }
function cel(tekst, klasa) { const d = document.createElement('div'); if (klasa) d.className = klasa; d.textContent = tekst; return d; }
function ikona(svg) { const d = document.createElement('div'); d.innerHTML = svg; return d; }

function kopjes() {
  kop.innerHTML = ''; kop.append(document.createElement('div'), document.createElement('div'));
  KOLUMNY.forEach(([k, nazwa]) => {
    const b = document.createElement('button'); b.type = 'button'; b.textContent = nazwa;
    if (k === sleutel) b.className = oplopend ? 'asc' : 'on';
    b.onclick = () => { oplopend = (k === sleutel) ? !oplopend : (k !== 'data' && k !== 'rew'); sleutel = k; kopjes(); render(); };
    kop.append(b);
  });
}

function render() {
  const t = q.value.toLowerCase().trim();
  const rijen = DATA.filter(r => !t || [r.plik, r.typ, r.lok, r.opis, r.rew, r.data, r.ctrl].join(' ').toLowerCase().includes(t))
    .sort((a, b) => { const x = waarde(a, sleutel), y = waarde(b, sleutel); return (x < y ? -1 : x > y ? 1 : 0) * (oplopend ? 1 : -1); });
  lic.textContent = rijen.length + ' / ' + DATA.length;
  lijst.innerHTML = '';
  if (!rijen.length) { lijst.append(cel('Brak wyników', 'leeg')); return; }
  const frag = document.createDocumentFragment();
  rijen.forEach(r => {
    const a = document.createElement('a'); a.className = 'grid row'; a.href = r.href; a.target = '_blank';
    a.append(ikona(ICO_OK), ikona(ICO_PDF), cel(r.plik), cel(r.typ), cel(r.lok), cel(r.opis, 'opis'), cel(r.rew), cel(r.data), cel(r.ctrl));
    frag.append(a);
  });
  lijst.append(frag);
}

function motyw(m) { document.documentElement.dataset.theme = m; try { localStorage.setItem('motyw', m); } catch (e) {} }
document.getElementById('motyw').onclick = () => motyw(document.documentElement.dataset.theme === 'amber' ? 'sp' : 'amber');
try { motyw(localStorage.getItem('motyw') || 'sp'); } catch (e) { motyw('sp'); }
q.addEventListener('input', render); kopjes(); render();
</script>
</body>
</html>
'@

$html = $template.Replace('@@DATA@@', $json)
[System.IO.File]::WriteAllText((Join-Path $root 'index.html'), $html, (New-Object System.Text.UTF8Encoding($false)))
$opisane = @($rows | Where-Object { $_.opis -or $_.typ }).Count
Write-Host ("Gotowe: " + $rows.Count + " plikow PDF (" + $opisane + " z opisem z CSV) -> " + (Join-Path $root 'index.html'))
