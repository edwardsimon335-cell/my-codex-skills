#!/usr/bin/env python3
"""Build a portable, feature-oriented HTML PRD from JSON and local media."""
import argparse
import base64
import hashlib
import json
import re
import sys
from datetime import datetime
from urllib.parse import urlparse
from html import escape
from html.parser import HTMLParser
from pathlib import Path
from zoneinfo import ZoneInfo

TEMPLATE = Path(__file__).resolve().parents[1] / 'assets' / 'prd-template.html'
STATUSES = {'todo', 'integrating', 'needs-info', 'done', 'reference'}
MIMES = {'.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg',
         '.webp': 'image/webp', '.gif': 'image/gif', '.mp4': 'video/mp4', '.webm': 'video/webm'}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def strings(value, name, nonempty=True):
    require(isinstance(value, list) and (bool(value) or not nonempty)
            and all(isinstance(s, str) for s in value), f'{name}: expected string array')


def list_items(value, name):
    require(isinstance(value, list) and value, f'{name}: nonempty list required')
    for item in value:
        if isinstance(item, str):
            continue
        require(isinstance(item, dict) and isinstance(item.get('text'), str)
                and item['text'].strip(), f'{name}: expected text or nested item')
        list_items(item.get('children'), name + ' children')


class SavedDocument(HTMLParser):
    def __init__(self):
        super().__init__()
        self.recording = False
        self.parts = []
        self.links = {}

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == 'script' and attrs.get('id') == 'prd-data':
            self.recording = True
        if tag == 'input' and 'data-doc-link' in attrs:
            self.links[attrs['data-doc-link']] = attrs.get('value', '')

    def handle_endtag(self, tag):
        if tag == 'script':
            self.recording = False

    def handle_data(self, data):
        if self.recording:
            self.parts.append(data)


def link_items(data):
    for section in data['sections']:
        for block in section['blocks']:
            if block['type'] == 'links':
                yield from block['items']


def validate(data):
    for name in ('document_id', 'project', 'title'):
        require(isinstance(data.get(name), str) and data[name].strip(), f'{name} is required')
    require(re.fullmatch(r'#[0-9a-fA-F]{6}', data.get('accent', '#b53f35')), 'accent must be #RRGGBB')
    for name in ('background', 'goals'):
        strings(data.get(name), name)
    if data.get('hub_project_id'):
        require(re.fullmatch(r'[a-z][a-z0-9-]*', data['hub_project_id']), 'Invalid hub_project_id')
        url = urlparse(data.get('hub_url', ''))
        require(url.scheme in ('http', 'https') and bool(url.netloc), 'hub_url must be an absolute http/https URL')
    sections, media = data.get('sections'), data.get('media', {})
    require(isinstance(sections, list) and sections, 'sections must be nonempty')
    require(isinstance(media, dict), 'media must be an object')
    for key, item in media.items():
        require(isinstance(item, dict), f'{key}: invalid media')
        require(item.get('kind') in ('image', 'video'), f'{key}: invalid kind')
        require(item.get('provenance') in ('app-capture', 'app-render', 'design-reference'),
                f'{key}: provenance is required')
        require(isinstance(item.get('title'), str) and item['title'], f'{key}: title required')

    def refs(ids, kind='image'):
        strings(ids, 'media references')
        for key in ids:
            require(key in media and media[key]['kind'] == kind, f'Unknown {kind}: {key}')

    section_ids, links = set(), set()
    for section in sections:
        sid = section.get('id', '')
        require(re.fullmatch(r'[a-z][a-z0-9-]*', sid) and sid not in section_ids,
                f'Invalid/duplicate section id: {sid}')
        section_ids.add(sid)
        require(section.get('status') in STATUSES, f'{sid}: invalid status')
        require(isinstance(section.get('title'), str) and section['title'], f'{sid}: title required')
        blocks = section.get('blocks')
        require(isinstance(blocks, list) and blocks, f'{sid}: blocks required')
        require(section.get('layout', 'default') in ('default', 'media-aside'), f'{sid}: invalid layout')
        if section.get('layout') == 'media-aside':
            require(blocks[-1].get('type') == 'motion', f'{sid}: media-aside requires last block motion')
        for block in blocks:
            kind = block.get('type')
            if kind == 'text':
                strings(block.get('paragraphs'), 'paragraphs')
            elif kind == 'list':
                list_items(block.get('items'), 'list items')
                require(isinstance(block.get('ordered', False), bool), 'ordered must be boolean')
            elif kind == 'illustrated':
                refs(block.get('media'))
                require(len(block['media']) <= 2, 'illustrated supports 1–2 pages')
                require(isinstance(block.get('groups'), list) and block['groups'], 'illustrated groups required')
                for group in block['groups']:
                    list_items(group.get('items'), 'group items')
            elif kind == 'table':
                strings(block.get('columns'), 'columns')
                require(isinstance(block.get('rows'), list) and block['rows'], 'table rows required')
                for row in block['rows']:
                    require(isinstance(row.get('cells'), list) and row['cells'], 'Table cells required')
                    for cell in row['cells']:
                        if isinstance(cell, list):
                            list_items(cell, 'cell list')
                        else:
                            require(isinstance(cell, str), 'Cell must be text or string array')
                    require(len(row['cells']) == len(block['columns']), 'Table column count mismatch')
                    if row.get('media'):
                        refs(row['media'])
            elif kind == 'gallery':
                refs(block.get('media'))
            elif kind == 'states':
                require(isinstance(block.get('items'), list) and block['items'], 'states items required')
                for item in block['items']:
                    require(isinstance(item.get('label'), str) and item['label'], 'State label required')
                    refs(item.get('media'))
            elif kind == 'motion':
                refs([block.get('video')], 'video')
                if block.get('stills'):
                    refs(block['stills'])
            elif kind == 'links':
                require(isinstance(block.get('items'), list) and block['items'], 'link items required')
                for item in block['items']:
                    key = item.get('id', '')
                    require(re.fullmatch(r'[a-z][a-z0-9-]*', key) and key not in links,
                            f'Invalid/duplicate link id: {key}')
                    require(isinstance(item.get('title'), str) and item['title'], 'Link title required')
                    require(isinstance(item.get('url', ''), str), 'Link URL must be a string')
                    links.add(key)
            else:
                raise ValueError(f'Unsupported block: {kind}')
    for item in media.values():
        if item.get('poster'):
            refs([item['poster']])


def build(args):
    source, output = Path(args.input).resolve(), Path(args.output).resolve()
    require(source != output, 'Input and output must differ')
    data = json.loads(source.read_text(encoding='utf-8'))
    validate(data)
    if output.exists() and not args.reset_links:
        previous = SavedDocument()
        previous.feed(output.read_text(encoding='utf-8'))
        if previous.parts:
            old = json.loads(''.join(previous.parts))
            if old.get('document_id') == data['document_id']:
                saved = {item['id']: item.get('url', '') for item in link_items(old)}
                saved.update(previous.links)
                for item in link_items(data):
                    if not item.get('url') and item['id'] in saved:
                        item['url'] = saved[item['id']]
    when = datetime.fromisoformat(data['updated_at']) if data.get('updated_at') else (
        datetime.now(ZoneInfo(args.timezone)) if args.timezone else datetime.now().astimezone())
    require(when.tzinfo is not None, 'updated_at must include timezone')
    data['updated_at'], data['updated_label'] = when.isoformat(timespec='minutes'), when.strftime('%Y.%m.%d %H:%M')
    summaries, embedded = [], {}
    for key, item in data.get('media', {}).items():
        file = (source.parent / item['file']).resolve()
        mime = MIMES.get(file.suffix.lower(), '')
        require(mime.startswith(item['kind'] + '/'), f'{key}: unsupported media file')
        require(file not in {source, output}, f'{key}: media cannot be input/output')
        content = file.read_bytes()
        require(bool(content), f'{key}: empty media')
        embedded[key] = {k: item[k] for k in ('title', 'kind', 'provenance', 'poster') if k in item}
        embedded[key]['src'] = f'data:{mime};base64,' + base64.b64encode(content).decode('ascii')
        summaries.append({'id': key, 'file': file.name, 'sha256': hashlib.sha256(content).hexdigest(),
                          'provenance': item['provenance'], 'source': item.get('source', '')})
    data['media'] = embedded
    data['revision'] = hashlib.sha256(json.dumps(data, ensure_ascii=False, sort_keys=True).encode()).hexdigest()[:16]
    payload = json.dumps(data, ensure_ascii=False).replace('<', '\\u003c').replace('&', '\\u0026')
    html = TEMPLATE.read_text(encoding='utf-8').replace('__PAGE_TITLE__', escape(data['title'])).replace('__PRD_DATA__', payload)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(html, encoding='utf-8')
    if args.manifest:
        manifest = Path(args.manifest).resolve()
        require(manifest not in {source, output}, 'Manifest cannot overwrite input/output')
        manifest.parent.mkdir(parents=True, exist_ok=True)
        manifest.write_text(json.dumps({'document_id': data['document_id'], 'updated_at': data['updated_at'],
            'sections': [{'id': s['id'], 'status': s['status']} for s in data['sections']], 'media': summaries,
            'html_sha256': hashlib.sha256(html.encode()).hexdigest()}, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    size = output.stat().st_size
    if size > 20 * 1024 * 1024:
        print('提示：HTML 超过 20MB，可压缩视频或按交付渠道改为相对路径包。', file=sys.stderr)
    print(json.dumps({'output': str(output), 'sections': len(data['sections']), 'bytes': size}, ensure_ascii=False))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', required=True, help='Source JSON; media paths relative to this file')
    parser.add_argument('--output', required=True, help='Self-contained HTML output')
    parser.add_argument('--timezone', help='User timezone, e.g. Asia/Shanghai')
    parser.add_argument('--manifest', help='Optional media provenance / digest JSON')
    parser.add_argument('--reset-links', action='store_true', help='Use only input URLs, ignoring saved output URLs')
    args = parser.parse_args()
    try:
        build(args)
    except (ValueError, KeyError, TypeError, OSError) as error:
        parser.exit(1, f'PRD build failed: {error}\n')


if __name__ == '__main__':
    main()
