import importlib.util, pathlib, tempfile, unittest
from lxml import etree as E

BASE=pathlib.Path(__file__).resolve().parents[1]
class BuilderTests(unittest.TestCase):
    def load(self):
        spec=importlib.util.spec_from_file_location('builder',BASE/'build.py')
        m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
    def test_builder_exists(self):
        self.assertTrue((BASE/'build.py').is_file(), 'Source-specific builder is missing')

    def test_input_cannot_be_overwritten_by_output(self):
        spec=importlib.util.spec_from_file_location('builder',BASE/'build.py')
        self.assertIsNotNone(spec)
        if not (BASE/'build.py').exists(): self.fail('Builder does not exist')
        m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
        with tempfile.TemporaryDirectory(dir=BASE.parent.parent) as d:
            source=pathlib.Path(d)/'input.rbxl';source.write_bytes(b'original')
            with self.assertRaises(ValueError):m.safe_output(source,pathlib.Path(d))
            self.assertEqual(source.read_bytes(),b'original')
    def test_recursive_output_rejected(self):
        m=self.load()
        with self.assertRaises(ValueError):m.safe_output(BASE/'some_input.rbxl',m.ROOT/'output')
    def test_other_source_rejected_before_writing(self):
        m=self.load()
        with tempfile.TemporaryDirectory(dir=BASE.parent.parent) as d:
            source=pathlib.Path(d)/'wrong.rbxl';source.write_bytes(b'original')
            output=pathlib.Path(d)/'build'
            with self.assertRaisesRegex(ValueError,'checksum mismatch'):m.build(source,'not-required',output)
            self.assertFalse(output.exists());self.assertEqual(source.read_bytes(),b'original')
    def test_archives_are_deterministic(self):
        m=self.load()
        with tempfile.TemporaryDirectory(dir=BASE.parent.parent) as d:
            root=pathlib.Path(d)/'source';root.mkdir();(root/'a.txt').write_text('same input')
            a,b=pathlib.Path(d)/'a.zip',pathlib.Path(d)/'b.zip'
            m.archive(a,root);m.archive(b,root)
            self.assertEqual(a.read_bytes(),b.read_bytes())
    def test_dangling_and_duplicate_references_fail(self):
        import sys;sys.path.insert(0,str(BASE));from validate import references
        dangling=E.fromstring(b'<roblox><Item referent="A"><Properties><Ref name="Part1">B</Ref></Properties></Item></roblox>')
        with self.assertRaisesRegex(ValueError,'unresolved'):references(dangling,'fixture')
        duplicate=E.fromstring(b'<roblox><Item referent="A"/><Item referent="A"/></roblox>')
        with self.assertRaisesRegex(ValueError,'duplicate'):references(duplicate,'fixture')

if __name__=='__main__':unittest.main()
