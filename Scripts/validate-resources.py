"""Check packaged strings, JSON/plists and listing limits; this is not a Swift build."""
from pathlib import Path
import json, plistlib, re

root=Path(__file__).resolve().parents[1]
source='\n'.join(p.read_text(encoding='utf-8') for p in (root/'Sources').rglob('*.swift'))
keys=set(re.findall(r'\bL\("((?:\\.|[^"\\])*)"\)',source))
counts={}
for locale in ('en','he'):
    text=(root/f'Resources/{locale}.lproj/Localizable.strings').read_text(encoding='utf-8')
    entries=re.findall(r'^"((?:\\.|[^"\\])*)"\s*=\s*"((?:\\.|[^"\\])*)";$',text,re.M)
    catalog=dict(entries)
    assert len(entries)==len(catalog),f'Duplicate {locale} keys'
    assert keys<=catalog.keys(),f'Missing {locale} keys: {keys-catalog.keys()}'
    assert all(value.strip() for value in catalog.values()),f'Empty {locale} values'
    counts[locale]=len(catalog)
for path in list(root.rglob('*.json'))+list(root.rglob('*.storekit')):
    if any(part in ('build','.build','.git') for part in path.parts):continue
    json.loads(path.read_text(encoding='utf-8'))
plistlib.loads((root/'Resources/PrivacyInfo.xcprivacy').read_bytes())
for locale in ('en-US','he'):
    for name,limit in [('name.txt',30),('subtitle.txt',30),('keywords.txt',100),('description.txt',4000),('promotional_text.txt',170),('whats_new.txt',4000)]:
        path=root/f'app-store/{locale}/{name}'
        value=path.read_text(encoding='utf-8').strip()
        assert value and len(value)<=limit,(locale,name,len(value),limit)
print(json.dumps({'resourceChecks':'passed','localizedEntries':counts,'literalKeysChecked':len(keys),'SwiftCompilation':'not performed by this script'}))
