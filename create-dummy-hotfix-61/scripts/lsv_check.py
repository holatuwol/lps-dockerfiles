#!/usr/bin/env python

from datetime import datetime
from functools import reduce
import json
import pandas as pd
import re
import requests
import subprocess

from jira import get_issues
import git

lsv_tickets = ['LSV-545', 'LSV-511', 'LSV-535', 'LSV-460', 'LSV-562', 'LSV-995', 'LSV-994', 'LSV-976', 'LSV-407', 'LSV-408', 'LSV-399', 'LSV-454', 'LSV-600', 'LSV-636', 'LSV-692', 'LSV-327', 'LSV-289', 'LSV-287', 'LSV-262', 'LSV-666', 'LSV-1149', 'LSV-992', 'LSV-393', 'LSV-397', 'LSV-450', 'LSV-449', 'LSV-634', 'LSV-614', 'LSV-658', 'LSV-675', 'LSV-361', 'LSV-422', 'LSV-697', 'LSV-819', 'LSV-977', 'LSV-980', 'LSV-766', 'LSV-851', 'LSV-1004', 'LSV-987', 'LSV-985', 'LSV-1093', 'LSV-1179', 'LSV-7', 'LSV-6', 'LSV-194', 'LSV-184', 'LSV-311', 'LSV-224', 'LSV-238', 'LSV-260', 'LSV-275', 'LSV-203', 'LSV-242', 'LSV-278', 'LSV-196', 'LSV-171', 'LSV-122', 'LSV-302', 'LSV-412', 'LSV-382', 'LSV-301', 'LSV-335', 'LSV-229', 'LSV-363', 'LSV-351', 'LSV-391', 'LSV-461', 'LSV-340', 'LSV-373', 'LSV-1', 'LSV-2', 'LSV-12', 'LSV-21', 'LSV-23', 'LSV-27', 'LSV-36', 'LSV-37', 'LSV-45', 'LSV-55', 'LSV-64', 'LSV-65', 'LSV-71', 'LSV-80', 'LSV-99', 'LSV-102', 'LSV-103', 'LSV-106', 'LSV-123', 'LSV-134', 'LSV-135', 'LSV-136', 'LSV-140', 'LSV-141', 'LSV-142', 'LSV-143', 'LSV-153', 'LSV-158', 'LSV-169', 'LSV-173', 'LSV-175', 'LSV-186', 'LSV-187', 'LSV-204', 'LSV-212', 'LSV-221', 'LSV-222', 'LSV-225', 'LSV-234', 'LSV-705', 'LSV-818']

def get_changed_files(baseline, changed_files, issue):
	git_hashes = [x for x in git.log('--reverse', '--pretty=%H', baseline, '--grep=%s' % issue).split('\n') if x != '']

	for git_hash in git_hashes:
		changed_files.update(git.show('--pretty=', '--name-only', git_hash).split('\n'))

	return changed_files

data = []

old_data = pd.read_csv('lsv_check.csv').to_dict('records')

for i, ticket in enumerate(lsv_tickets):
	print('Checking %s...' % ticket)

	lps_query = 'project = LPS and issue in linkedIssues(%s)' % ticket
	lpe_query = 'project = LPE and issueFunction in linkedIssuesOf("%s")' % lps_query
	
	datum = old_data[i] if i < len(old_data) else {'LSV': ticket}

	if 'LPS' in datum:
		linked_lps = [] if type(datum['LPS']) == float else datum['LPS'].split(' ')
	else:
		linked_lps = get_issues(lps_query, []).keys()
		datum['LPS'] = ' '.join(linked_lps)

	if 'LPE' in datum:
		linked_lpe = [] if type(datum['LPE']) == float else datum['LPE'].split(' ')
	else:
		linked_lpe = get_issues(lpe_query, []).keys()
		datum['LPE'] = ' '.join(linked_lpe)

	linked_issues = list(linked_lpe) + list(linked_lps)

	if 'Baseline' not in datum or 'Files' not in datum:
		for baseline in ['fix-pack-base-6210-portal-174', 'fix-pack-de-102-7010', 'fix-pack-dxp-28-7110', 'fix-pack-dxp-20-7210', 'fix-pack-20-7310', '7.4.13-u62']:
			changed_files = reduce(lambda a, b: get_changed_files(baseline, a, b), linked_issues, set())

			if len(changed_files) == 0:
				continue

			datum['Baseline'] = baseline
			break

		datum['Files'] = '\n'.join(sorted(changed_files))

	datum['Committed'] = len(reduce(lambda a, b: get_changed_files('origin/liferaywebteam-6120-final', a, b), linked_issues, set())) > 0

	data.append(datum)

pd.DataFrame(data).to_csv('lsv_check.csv', index=False)