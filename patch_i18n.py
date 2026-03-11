import re

with open('lib/i18n.dart', 'r') as f:
    content = f.read()

# Add en translation
en_match = re.search(r"('auto_voice': 'Auto Voice',)", content)
content = content[:en_match.end()] + "\n      'auto_draw': 'Auto Draw',\n      'manual_draw': 'Manual Draw'," + content[en_match.end():]

# Add zh translation
zh_match = re.search(r"('auto_voice': '自动语音',)", content)
content = content[:zh_match.end()] + "\n      'auto_draw': '自动绘图',\n      'manual_draw': '手动绘图'," + content[zh_match.end():]

with open('lib/i18n.dart', 'w') as f:
    f.write(content)
