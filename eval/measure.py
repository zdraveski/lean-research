"""Measure one research run: cost from the main session and its subagent transcripts, pages from pages.csv, evidence from notes and report.
Usage: python -I measure.py <notes_folder> <label> <main_session.jsonl>
The whole session is the run; agent files are read from <session without .jsonl>/subagents/agent-*.jsonl.
Appends one row to results.csv next to this script and prints it. Works for any lean-research or deep-research run
whose researchers logged through fetch.sh; for a run without pages.csv the page columns stay empty."""
import csv, glob, json, os, re, sys, io
from datetime import datetime
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
HERE = os.path.dirname(os.path.abspath(__file__))
URL = re.compile(r'https?://(?:[^\s()\]>"\'`|,]|\([^\s()]*\))+')  # keeps "(5)" inside a PDF name

def transcript(path):
    turns, ts = {}, []
    for line in open(path, encoding='utf-8', errors='replace'):
        try: o = json.loads(line)
        except ValueError: continue
        if o.get('timestamp'): ts.append(o['timestamp'])
        m = o.get('message')
        if isinstance(m, dict) and m.get('usage') and m.get('id'): turns[m['id']] = m['usage']  # one turn spans several lines with the same id
    u = list(turns.values())
    g = lambda k: sum(x.get(k, 0) for x in u)
    ctx = [x.get('input_tokens', 0) + x.get('cache_read_input_tokens', 0) + x.get('cache_creation_input_tokens', 0) for x in u]
    t = lambda s: datetime.fromisoformat(s.replace('Z', '+00:00'))
    return dict(turns=len(u), fresh=g('input_tokens'), cw=g('cache_creation_input_tokens'), cr=g('cache_read_input_tokens'),
                output=g('output_tokens'), first_ctx=ctx[0] if ctx else 0,
                start=t(ts[0]) if ts else None, end=t(ts[-1]) if ts else None)

def urls(path):
    if not os.path.exists(path): return set()
    out = set()
    for u in URL.findall(open(path, encoding='utf-8', errors='replace').read()):
        u = u.rstrip('.;:')
        while u.endswith(')') and u.count('(') < u.count(')'): u = u[:-1]  # markdown link close, not part of the URL
        out.add(u)
    return out

def is_api(u):  # statistics APIs are read with curl, never through fetch.sh, so pages.csv can't show them
    return re.match(r'https?://api\.', u) is not None

folder, label, session = sys.argv[1], sys.argv[2], sys.argv[3]
if not os.path.exists(session): sys.exit(f'no session file {session}')
if not session.endswith('.jsonl'): sys.exit(f'session file must end in .jsonl: {session}')
M = transcript(session)
T = [transcript(p) for p in sorted(glob.glob(os.path.join(session[:-len('.jsonl')], 'subagents', 'agent-*.jsonl')))]
A = [M] + T
S = lambda k: sum(x[k] for x in A)
span = [x[k] for x in A for k in ('start', 'end') if x[k]]
row = dict(label=label, folder=os.path.basename(folder.rstrip('/\\')), when=datetime.now().isoformat(timespec='minutes'),
           agents=len(T), main_turns=M['turns'], main_input=M['fresh'] + M['cw'] + M['cr'],
           fresh_in=S('fresh'), cache_write=S('cw'), cache_read=S('cr'), input=S('fresh') + S('cw') + S('cr'),
           output=S('output'), turns=S('turns'),
           start_ctx='/'.join(str(x['first_ctx']) for x in T),  # per agent, in file-name order: the writer's 43k would hide a lean researcher's 11k
           turns_each='/'.join(str(x['turns']) for x in T),
           wall_s=round((max(span) - min(span)).total_seconds()) if span else 0)

pc = os.path.join(folder, 'pages.csv')
opened = set()
if os.path.exists(pc):
    lines = open(pc, encoding='utf-8', errors='replace').read().splitlines()
    hdr = None if lines and lines[0].startswith('agent,') else ['agent', 'url', 'start', 'seconds', 'bytes', 'status', 'reader']  # weblog.sh writes no header
    rows = list(csv.DictReader(lines, fieldnames=hdr))
    new = [r for r in rows if r['status'] != 'cache']
    opened = {r['url'] for r in rows if r['status'] in ('ok', 'cache')}
    row.update(opens=len(new), ok=sum(r['status'] == 'ok' for r in new), blocked=sum(r['status'] == 'blocked' for r in new),
               thin=sum(r['status'] == 'thin' for r in new), fetch_s=round(sum(float(r['seconds']) for r in new)),
               lost_s=round(sum(float(r['seconds']) for r in new if r['status'] != 'ok')))
sc = os.path.join(folder, 'searches.csv')
if os.path.exists(sc): row['searches'] = sum(1 for _ in csv.DictReader(open(sc, encoding='utf-8', errors='replace')))

notes = [p for p in glob.glob(os.path.join(folder, '*.md')) if 'inventory' not in os.path.basename(p).lower()]
nu = set().union(*map(urls, notes)) if notes else set()
text = ''.join(open(p, encoding='utf-8', errors='replace').read() for p in notes)
row.update(notes_words=len(text.split()), notes_urls=len(nu), snippet_marks=len(re.findall(r'search snippet', text, re.I)))
# evidence rate: share of cited URLs that were really opened (ok or cached); only meaningful when pages.csv exists
if opened: row['notes_urls_opened_pct'] = round(100 * len({u for u in nu if u in opened or is_api(u)}) / max(len(nu), 1))
rep = os.path.join(os.path.dirname(os.path.dirname(folder.rstrip('/\\'))), 'reports', row['folder'] + '.md')
ru = urls(rep)
row.update(report_words=len(open(rep, encoding='utf-8').read().split()) if os.path.exists(rep) else 0, report_urls=len(ru))
if opened: row['report_urls_opened_pct'] = round(100 * len({u for u in ru if u in opened or is_api(u)}) / max(len(ru), 1))

out = os.path.join(HERE, 'results.csv')
cols = ['label', 'folder', 'when', 'agents', 'main_turns', 'main_input', 'fresh_in', 'cache_write', 'cache_read', 'input', 'output', 'turns', 'start_ctx', 'wall_s', 'opens', 'ok', 'blocked', 'thin',
        'fetch_s', 'lost_s', 'searches', 'notes_words', 'notes_urls', 'notes_urls_opened_pct', 'snippet_marks',
        'report_words', 'report_urls', 'report_urls_opened_pct', 'turns_each']
new_file = not os.path.exists(out)
with open(out, 'a', newline='', encoding='utf-8') as f:
    w = csv.DictWriter(f, cols); new_file and w.writeheader(); w.writerow(row)
for k in cols: print(f'{k:24} {row.get(k, "")}')
