#!/usr/bin/env python

from bs4 import BeautifulSoup
from datetime import datetime
from fixed_issues import tickets, lpe_tickets
from functools import reduce
import git
import os
import shutil

commit_count = 0

with open('git_log_hash.txt') as f:
	commit_count = len(f.readlines())

input_file = '/scripts/fixpack_documentation.xml'
output_file = 'patch/fixpack_documentation.xml'

with open(input_file, 'r') as f:
	soup = BeautifulSoup(f, features='xml')

# seconds since January 1, 2023
hotfix_time = datetime.utcnow()
hotfix_id = commit_count

fixed_issues = list(set(reduce(lambda a, b: a + lpe_tickets[b], tickets, [])))
fixed_issues = sorted(fixed_issues, key=lambda x: int(x[x.find('-')+1:]))

soup.patch.find('id').string = 'mega-patch-%d-6110' % hotfix_id
soup.patch.find('name').string = 'mega-patch-%d' % hotfix_id
soup.patch.find('version').string = str(hotfix_id)
soup.patch.find('rank').string = str(10000 + hotfix_id)
soup.patch.find('fixed-issues').string = ','.join(fixed_issues)
soup.patch.find('build-date').string = hotfix_time.strftime('%a, %d %b %Y %H:%M:%S +0000')

replacements = soup.patch.find('full-file-replacements')

def get_replace_file_tag(folder_name):
	print(folder_name)
	for file_name in os.listdir('patch/jdk6/%s' % folder_name):
		file_path = 'patch/jdk6/%s/%s' % (folder_name, file_name)

		if not os.path.isfile(file_path):
			continue

		new_tag = soup.new_tag('replace-file')
		new_tag.string = '%s/%s' % (folder_name, file_name)
		yield new_tag

for lib_tag in get_replace_file_tag('GLOBAL_LIB_PATH'):
	replacements.append(lib_tag)

for lib_tag in get_replace_file_tag('WAR_PATH/WEB-INF/lib'):
	replacements.append(lib_tag)

with open(output_file, 'w') as f:
	f.write(soup.prettify())

shutil.make_archive('/source/liferay-mega-patch-%d-6110' % hotfix_id, 'zip', 'patch/')