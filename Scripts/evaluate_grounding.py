"""Mac MLX probe using pinned app weights/prompts and a compiled Swift validator.
Synthetic data only. Not an iPhone performance test or proof of no hallucinations.
Usage: python Scripts/evaluate_grounding.py --work PATH --validator PATH
Install mlx-lm==0.24.0 in an isolated environment first.
"""
import argparse, hashlib, json, pathlib, subprocess, time
from huggingface_hub import snapshot_download
from mlx_lm import load, generate
from mlx_lm.sample_utils import make_sampler

parser = argparse.ArgumentParser()
parser.add_argument('--work', type=pathlib.Path, required=True)
parser.add_argument('--manifest', type=pathlib.Path)
parser.add_argument('--validator', type=pathlib.Path, required=True)
args = parser.parse_args()
root = pathlib.Path(__file__).resolve().parents[1]
args.work.mkdir(parents=True, exist_ok=True)
manifest = json.loads(args.manifest.read_text()) if args.manifest else json.loads((root/'Resources/ModelManifests.json').read_text())[0]
folder = snapshot_download(manifest['repo'], revision=manifest['revision'],
    allow_patterns=[f['path'] for f in manifest['files']], local_dir=args.work/'model')
for asset in manifest['files']:
    path = pathlib.Path(folder)/asset['path']
    assert path.stat().st_size == asset['size']
    with path.open('rb') as stream:
        digest = hashlib.sha256()
        for block in iter(lambda: stream.read(1024*1024), b''): digest.update(block)
    assert digest.hexdigest() == asset['sha256']
print('Pinned model hashes verified', flush=True)
model, tokenizer = load(folder)
system = subprocess.check_output([str(args.validator), '--prompt'], text=True)
retry = subprocess.check_output([str(args.validator), '--retry'], text=True)
results = []
for case in json.loads((root/'Tests/Evaluation/grounding.json').read_text()):
    attempts = []
    for attempt in range(2):
        user = '<UNTRUSTED_CONTENT_JSON>\n'+json.dumps(case['text'],ensure_ascii=False).replace('<','\\u003c').replace('>','\\u003e')+'\n</UNTRUSTED_CONTENT_JSON>'
        prompt = tokenizer.apply_chat_template([{'role':'system','content':system if attempt == 0 else retry},{'role':'user','content':user}], tokenize=False, add_generation_prompt=True, enable_thinking=False)
        start = time.monotonic()
        output = generate(model,tokenizer,prompt=prompt,max_tokens=512,sampler=make_sampler(0.0),verbose=False)
        raw = args.work/'current.json'; raw.write_text(output)
        source = args.work/'source.txt'; source.write_text(case['text'])
        checked = subprocess.run([str(args.validator),str(raw),str(source)],capture_output=True,text=True)
        issues = []
        if checked.returncode:
            issues.append('validation_rejected')
        else:
            value=json.loads(checked.stdout)
            claims=value['title']+' '+value['summary']
            if any(term.casefold() in claims.casefold() for term in case.get('forbidden_claims', [])): issues.append('instruction_presented_as_fact')
            if 'allowed_people' in case and any(person not in case['allowed_people'] for person in value['people']): issues.append('incorrect_person_entity')
            dates=value['dates']
            if case.get('no_iso') and any(d.get('iso8601') for d in dates): issues.append('invented_precise_date')
            if 'allowed_iso' in case and any(d.get('iso8601') and d['iso8601'] not in case['allowed_iso'] for d in dates): issues.append('incorrect_timestamp')
            if case.get('no_calendar') and any(a['type'] in ['createCalendarEvent','createReminder'] for a in value['proposedActions']): issues.append('unsupported_scheduling')
            for field in ['people','locations']:
                if any(v.casefold() not in case['text'].casefold() for v in value[field]): issues.append('unsupported_'+field)
        attempts.append({'attempt':attempt,'seconds':round(time.monotonic()-start,2),'output':output,'issues':issues})
        if checked.returncode == 0: break
    results.append({'name':case['name'],'input':case['text'],'attempts':attempts})
    (args.work/'results.json').write_text(json.dumps(results,indent=2))
    print(case['name'],attempts[-1]['issues'] or 'automated checks passed; manual review required',flush=True)
