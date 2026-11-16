import csv, os, shutil, subprocess, sys, tempfile, unittest
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

class Measure(unittest.TestCase):
    def test_counts_main_session_and_subagents(self):
        with tempfile.TemporaryDirectory() as tmp:
            # run a copy: measure.py writes results.csv next to itself
            script = os.path.join(tmp, 'measure.py')
            shutil.copy(os.path.join(ROOT, 'eval', 'measure.py'), script)
            notes = os.path.join(tmp, 'notes', 'run1'); os.makedirs(notes)
            session = os.path.join(HERE, 'fixtures', 'session', 'abc.jsonl')
            r = subprocess.run([sys.executable, '-I', script, notes, 'test', session], capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stderr)
            with open(os.path.join(tmp, 'results.csv'), encoding='utf-8') as f:
                row = list(csv.DictReader(f))[0]
        want = dict(agents='2', turns='6', main_turns='3', main_input='6660', fresh_in='67', cache_write='670',
                    cache_read='6700', input='7437', output='25', wall_s='70', turns_each='2/1', start_ctx='111/444')
        self.assertEqual({k: row[k] for k in want}, want)

if __name__ == '__main__': unittest.main()
