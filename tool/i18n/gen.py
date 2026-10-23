# -*- coding: utf-8 -*-
import re, glob, sys, os
sys.path.insert(0, os.path.dirname(__file__))
from part1 import T1
from part2 import T2
from part3 import T3
from part4 import T4
from part5 import T5
from rules import RULES

T = {}
for d in (T1, T2, T3, T4, T5):
    T.update(d)

def dq(s):
    return "'" + s.replace('\\', '\\\\').replace("'", "\\'").replace('$', '\\$').replace('\n', '\\n') + "'"

# склейки соседних литералов в исходниках: ищем в проекте
def unescape(s):
    return (s.replace("\\n", "\n").replace("\\'", "'").replace('\\"', '"').replace('\\$', '$').replace('\\\\', '\\'))

root = os.path.join(os.path.dirname(__file__), '..', '..', 'lib')
lit = r"""(?:'(?:[^'\\\n]|\\.)*'|"(?:[^"\\\n]|\\.)*")"""
pat = re.compile(r"(" + lit + r")((?:[ \t]*\n[ \t]*" + lit + r")+)")
missing = []
for f in glob.glob(os.path.join(root, '**/*.dart'), recursive=True):
    s = open(f, encoding='utf-8').read()
    for m in pat.finditer(s):
        parts = re.findall(lit, m.group(0))
        vals = [unescape(p[1:-1]) for p in parts]
        joined = ''.join(vals)
        if not re.search('[А-Яа-яЁё]', joined) or '$' in joined:
            continue
        if joined in T:
            continue
        if all(v in T for v in vals):
            T[joined] = tuple(' '.join(()) or ''.join(
                ((T[v][i] if i < 3 else '') for v in vals)) for i in range(3))
        else:
            missing.append((f, joined))
for f, j in missing:
    print('NO-CONCAT-ENTRY', os.path.basename(f), j[:80])

def emit(idx, name, out):
    lines = ["// СГЕНЕРИРОВАНО tool/i18n/gen.py — не править вручную.", "// ignore_for_file: prefer_single_quotes, lines_longer_than_80_chars", "",
             "const Map<String, String> %s = <String, String>{" % name]
    for k in sorted(T):
        v = T[k][idx]
        if v == '':
            continue
        lines.append("  %s: %s," % (dq(k), dq(v)))
    lines.append("};")
    open(os.path.join(root, 'core', 'l10n', out), 'w', encoding='utf-8').write('\n'.join(lines) + '\n')

emit(0, 'stringsEn', 'strings_en.dart')
emit(1, 'stringsHy', 'strings_hy.dart')
emit(2, 'stringsKa', 'strings_ka.dart')

rl = ["// СГЕНЕРИРОВАНО tool/i18n/gen.py — не править вручную.", "// ignore_for_file: prefer_single_quotes, lines_longer_than_80_chars", "",
"""class _Rule {
  _Rule(String pattern, this.templates) : regex = RegExp(pattern);

  final RegExp regex;
  final Map<String, String> templates;
}

final List<_Rule> _rules = <_Rule>[""" ]
for r in RULES:
    rl.append("  _Rule(r%s, <String, String>{'en': %s, 'hy': %s, 'ka': %s})," % (dq(r[0]).replace("\\\\", "\\").replace("\\$", "$"), dq(r[1]), dq(r[2]), dq(r[3])))
rl.append("""];

/// Переводит динамическую строку по шаблонам. null — если ни одно правило не подошло.
String? translateByRules(String ru, String lang, String Function(String) tr) {
  for (final rule in _rules) {
    final m = rule.regex.firstMatch(ru);
    if (m == null) continue;
    var out = rule.templates[lang];
    if (out == null) return null;
    for (var i = 1; i <= m.groupCount; i++) {
      out = out!.replaceAll('{$i}', tr(m.group(i) ?? ''));
    }
    return out;
  }
  return null;
}
""")
open(os.path.join(root, 'core', 'l10n', 'rules.dart'), 'w', encoding='utf-8').write('\n'.join(rl))
print(len(T), 'entries')
