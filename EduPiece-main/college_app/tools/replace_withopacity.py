import re
import os

root = os.path.join(os.path.dirname(__file__), '..', 'lib')

pattern = re.compile(r'\.withOpacity\(\s*([^\)]+?)\s*\)')

for dirpath, dirnames, filenames in os.walk(root):
    for fn in filenames:
        if fn.endswith('.dart'):
            path = os.path.join(dirpath, fn)
            with open(path, 'r', encoding='utf-8') as f:
                s = f.read()
            new = pattern.sub(r'.withAlpha((\1*255).round())', s)
            if new != s:
                with open(path, 'w', encoding='utf-8') as f:
                    f.write(new)
                print('Updated', path)
print('Done')
