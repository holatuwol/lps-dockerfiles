from __future__ import print_function

from bs4 import BeautifulSoup
import datetime
import requests

print('Checking for latest release')
r = requests.get('https://releases.liferay.com/tools/workspace/')

soup = BeautifulSoup(r.content, 'html.parser')

latest_version = None
latest_version_timestamp = None

# Find the latest release

for row in soup.find_all('tr'):
	cells = row.find_all('td')

	if len(cells) < 5:
		continue

	timestamp_string = cells[2].get_text().strip()

	if len(timestamp_string) == 0:
		continue

	timestamp = datetime.datetime.strptime(timestamp_string, '%d-%b-%Y %H:%M')

	if latest_version_timestamp is None or timestamp > latest_version_timestamp:
		latest_version = cells[1].get_text().strip()
		latest_version_timestamp = timestamp

# Find the latest Linux release

print('Checking for Linux version of %s' % latest_version)
r = requests.get('https://releases.liferay.com/tools/workspace/%s' % latest_version)

soup = BeautifulSoup(r.content, 'html.parser')

linux_release_name = None

for row in soup.find_all('tr'):
	cells = row.find_all('td')

	if len(cells) <= 1:
		continue

	release_name = cells[1].get_text().strip()

	if release_name.find('linux') >= 0:
		linux_release_name = release_name

# Download the latest Linux release

with open('LiferayWorkspace-installer.run', 'wb') as f:
	r = requests.get('https://releases.liferay.com/tools/workspace/%s%s' % (latest_version, linux_release_name))
	f.write(r.content)
