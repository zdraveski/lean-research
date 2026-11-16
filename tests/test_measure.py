import csv, os, shutil, subprocess, sys, tempfile, unittest
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SESSION = os.path.join(HERE, 'fixtures', 'session', 'abc.jsonl')

def run(tmp, notes, session):
    # run a copy: measure.py writes results.csv next to itself
    script = os.path.join(tmp, 'measure.py')
    if not os.path.exists(script): shutil.copy(os.path.join(ROOT, 'eval', 'measure.py'), script)
    return subprocess.run([sys.executable, '-I', script, notes, 'test', session], capture_output=True, text=True)

def rows(tmp):
    with open(os.path.join(tmp, 'results.csv'), encoding='utf-8') as f:
        return list(csv.DictReader(f))

def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f: f.write(text)

class Measure(unittest.TestCase):
    def test_counts_main_session_and_subagents(self):
        with tempfile.TemporaryDirectory() as tmp:
            notes = os.path.join(tmp, 'notes', 'run1'); os.makedirs(notes)
            r = run(tmp, notes, SESSION)
            self.assertEqual(r.returncode, 0, r.stderr)
            row = rows(tmp)[0]
        want = dict(agents='2', turns='6', main_turns='3', main_input='6660', fresh_in='67', cache_write='670',
                    cache_read='6700', input='7437', output='25', wall_s='70', turns_each='2/1', start_ctx='111/444')
        self.assertEqual({k: row[k] for k in want}, want)

    def test_evidence_columns(self):
        with tempfile.TemporaryDirectory() as tmp:
            notes = os.path.join(tmp, 'notes', 'run1')
            write(os.path.join(notes, 'pages.csv'), 'agent,url,start,seconds,bytes,status,reader\n'
                  'a,"http://a.test/1",t,2,100,ok,moli\na,"http://a.test/2",t,3,0,blocked,x\na,"http://a.test/1",t,0,100,cache,cache\n')
            write(os.path.join(notes, 'searches.csv'), 'agent,query,time\na,"q1",t\na,"q2",t\n')
            write(os.path.join(notes, 'n.md'), 'See http://a.test/1 and http://a.test/2 (search snippet).\n')
            write(os.path.join(tmp, 'reports', 'run1.md'), 'Source http://a.test/1\n')
            r = run(tmp, notes, SESSION)
            self.assertEqual(r.returncode, 0, r.stderr)
            row = rows(tmp)[0]
        want = dict(opens='2', ok='1', blocked='1', thin='0', fetch_s='5', lost_s='3', searches='2', notes_urls='2',
                    notes_urls_opened_pct='50', snippet_marks='1', report_urls='1', report_urls_opened_pct='100')
        self.assertEqual({k: row[k] for k in want}, want)

    def test_bad_session_is_an_error(self):
        with tempfile.TemporaryDirectory() as tmp:
            notes = os.path.join(tmp, 'notes', 'run1'); os.makedirs(notes)
            r = run(tmp, notes, os.path.join(tmp, 'missing.jsonl'))
            self.assertNotEqual(r.returncode, 0); self.assertIn('no session file', r.stderr)
            other = os.path.join(tmp, 'abc.txt'); write(other, '{}\n')
            r = run(tmp, notes, other)
            self.assertNotEqual(r.returncode, 0); self.assertIn('.jsonl', r.stderr)
            self.assertFalse(os.path.exists(os.path.join(tmp, 'results.csv')))

    def test_appends_one_row_per_run(self):
        with tempfile.TemporaryDirectory() as tmp:
            notes = os.path.join(tmp, 'notes', 'run1'); os.makedirs(notes)
            for _ in range(2): self.assertEqual(run(tmp, notes, SESSION).returncode, 0)
            self.assertEqual(len(rows(tmp)), 2)

if __name__ == '__main__': unittest.main()
