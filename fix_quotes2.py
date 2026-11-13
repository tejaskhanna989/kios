import glob

for f in glob.glob('app/src/main/java/**/*.java', recursive=True):
    with open(f, 'r') as fp:
        content = fp.read()
    content = content.replace('\u2019kios:', '"kios:')
    content = content.replace('\u2019kios', '"kios')
    with open(f, 'w') as fp:
        fp.write(content)
print('Done')
