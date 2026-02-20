import re
import os

root = os.path.join(os.path.dirname(__file__), '..', 'lib')

def replace_in_file(path):
    with open(path, 'r', encoding='utf-8') as f:
        s = f.read()

    # Replace double-quoted string literals that do not contain single quotes or escaped quotes
    pattern = re.compile(r'"((?:[^"\\]|\\.)*?)"')

    def repl(m):
        content = m.group(1)
        # Skip if contains single quote
        if "'" in content:
            return m.group(0)
        # Keep interpolation and escapes as-is
        return "'" + content + "'"

    new = pattern.sub(repl, s)

    if new != s:
        with open(path, 'w', encoding='utf-8') as f:
            f.write(new)
        print('Updated', path)

for dirpath, dirnames, filenames in os.walk(root):
    for fn in filenames:
        if fn.endswith('.dart'):
            replace_in_file(os.path.join(dirpath, fn))
print('Done')
