import sys, unittest, subprocess, tempfile, os, shutil
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from luau_pack import pack, restore

class LiteralPackingTests(unittest.TestCase):
    def test_comments_escapes_and_long_literals_keep_their_meaning(self):
        source='''-- a comment containing "ignored"\nlocal a="line\\n\\\"face\\\""\nlocal b=[==[text -- not a comment\n\\ literal]==]\n--[=[ block "comment" ]=]\nlocal c='\\065\\x42\\u{43}'\nprint(a,b,c,7 - -2,1 .. "x")\n'''
        packed=pack(source)
        self.assertNotIn('ignored',packed)
        self.assertNotIn('face',packed)
        for code in (packed,restore(packed)):
            with tempfile.TemporaryDirectory() as d:
                p=Path(d)/'test.luau';p.write_text(code)
                luau=os.environ.get('FUNCOMBAT_LUAU') or shutil.which('luau')
                if not luau:self.skipTest('Set FUNCOMBAT_LUAU to run the literal behavior test')
                r=subprocess.run([luau,str(p)],capture_output=True,text=True)
                self.assertEqual(r.returncode,0,r.stderr)
                if code==packed:expected=r.stdout
                else:self.assertEqual(r.stdout,expected)

    def test_string_and_comment_markers_inside_literals_do_not_change_code(self):
        source='local a="--[=[hello]=]";local b=[=["quoted"]=];print(a,b)'
        self.assertIn('hello',restore(pack(source)))
        self.assertEqual(pack(source),pack(source))

    def test_truncated_quoted_or_long_string_is_rejected(self):
        for source in ('return "unfinished','return [=[unfinished'):
            with self.assertRaises(ValueError):pack(source)

    def test_leading_decimal_and_string_argument_sugar_compile_and_match(self):
        source='local function f(a) return a end;print(.25,-.75,f "original",f [=[long argument]=])'
        luau=os.environ.get('FUNCOMBAT_LUAU') or shutil.which('luau')
        if not luau:self.skipTest('Set FUNCOMBAT_LUAU to run the literal behavior test')
        results=[]
        with tempfile.TemporaryDirectory() as d:
            for i,code in enumerate((source,pack(source),restore(pack(source)))):
                p=Path(d)/f'test_{i}.luau';p.write_text(code)
                r=subprocess.run([luau,str(p)],capture_output=True,text=True)
                self.assertEqual(r.returncode,0,r.stderr);results.append(r.stdout)
        self.assertEqual(results[0],results[1]);self.assertEqual(results[1],results[2])

if __name__=='__main__':unittest.main()
