"""Generuje index.html z listą wszystkich PDF-ów w folderze (z podfolderami).

Użycie:  python make_index.py            (w folderze ze schematami)
         python make_index.py "C:\\sciezka\\do\\folderu"
"""
import sys
from html import escape
from pathlib import Path
from urllib.parse import quote

root = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).parent).resolve()
pdfs = sorted(
    (p for p in root.rglob("*") if p.is_file() and p.suffix.lower() == ".pdf"),
    key=lambda p: p.relative_to(root).as_posix().lower(),
)

items = "\n".join(
    f'    <li><a href="{quote(p.relative_to(root).as_posix())}" target="_blank">'
    f'<span class="nr">{i:03d}</span><span class="nazwa">{escape(p.stem)}</span></a></li>'
    for i, p in enumerate(pdfs, 1)
)

TEMPLATE = """<!doctype html>
<html lang="pl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Schematy</title>
<style>
  :root { --bg:#000; --amber:#ffb000; --dim:#a87400; --line:#3a2800; }
  * { box-sizing:border-box; }
  body { margin:0; background:var(--bg); color:var(--amber);
         font-family:"Courier New",ui-monospace,monospace; }
  header { position:sticky; top:0; background:var(--bg); padding:1.2rem 1rem .8rem;
           border-bottom:1px solid var(--line); z-index:1; }
  .wrap { max-width:1000px; margin:0 auto; }
  h1 { margin:0 0 .6rem; letter-spacing:.2em; text-transform:uppercase; font-size:1.4rem;
       text-shadow:0 0 8px rgba(255,176,0,.5); }
  #q { width:100%; padding:.6rem .8rem; font:inherit; font-size:1rem; color:var(--amber);
       background:#0a0700; border:1px solid var(--dim); outline:none; }
  #q:focus { border-color:var(--amber); box-shadow:0 0 8px rgba(255,176,0,.4); }
  #q::placeholder { color:var(--dim); }
  #licznik { color:var(--dim); font-size:.85rem; margin-top:.4rem; }
  ul { list-style:none; margin:0; padding:1rem; display:grid;
       grid-template-columns:repeat(auto-fill,minmax(200px,1fr)); gap:.5rem; }
  a { display:flex; gap:.8rem; padding:.6rem .8rem; color:var(--amber); text-decoration:none;
      border:1px solid var(--line); background:#070500; transition:.15s; }
  a:hover, a:focus { border-color:var(--amber); background:#1a1200;
                     box-shadow:0 0 10px rgba(255,176,0,.35); outline:none; }
  .nr { color:var(--dim); }
  a:hover .nr { color:var(--amber); }
  li[hidden] { display:none; }
</style>
</head>
<body>
<header><div class="wrap">
  <h1>&gt; Schematy_</h1>
  <input id="q" type="search" placeholder="szukaj numeru schematu..." autofocus>
  <div id="licznik"></div>
</div></header>

<main class="wrap">
  <ul id="lista">
@@ITEMS@@
  </ul>
</main>

<script>
  const q = document.getElementById('q'), lic = document.getElementById('licznik');
  const els = [...document.querySelectorAll('#lista li')];
  function filtruj() {
    const t = q.value.toLowerCase().trim(); let n = 0;
    els.forEach(li => { const ok = li.textContent.toLowerCase().includes(t); li.hidden = !ok; if (ok) n++; });
    lic.textContent = n + ' / ' + els.length + ' schematów';
  }
  q.addEventListener('input', filtruj); filtruj();
</script>
</body>
</html>
"""

(root / "index.html").write_text(TEMPLATE.replace("@@ITEMS@@", items), encoding="utf-8")
print(f"Gotowe: {len(pdfs)} plików PDF -> {root / 'index.html'}")
