#!/usr/bin/env python

from functools import partial, reduce
import git
from jira import get_issues
import json
import os
import re

ticket_pattern = re.compile('LP[EPS]-[0-9]+')

def extract_tickets(tickets, message):
    result = ticket_pattern.findall(message)

    if result is None:
        return tickets
    
    tickets.update(result)
    return tickets

commits = []

if os.path.isdir('.git'):
    commits = git.log('--pretty=%s', 'fix-pack-base-6120..HEAD').split('\n')
else:
    with open('git_log_subject.txt', 'r') as f:
        commits = [subject.strip() for subject in f.readlines()]

tickets = reduce(extract_tickets, commits, set())

lpe_tickets = {}

if os.path.exists('lpe_tickets.json'):
    with open('lpe_tickets.json', 'r') as f:
        lpe_tickets = json.load(f)

def lookup_tickets(ticket_count, lpe_tickets, next_item):
    i, ticket = next_item
    print('Checking %s (ticket %d/%d)...' % (ticket, i+1, ticket_count))

    if ticket in lpe_tickets:
        return lpe_tickets
    
    if ticket[:3] == 'LPE':
        lpe_tickets[ticket] = [ticket]
        return lpe_tickets
    
    lpe_query = 'project = LPE and issue in linkedIssues(%s)' % ticket
    linked_lpe = get_issues(lpe_query, []).keys()
    lpe_tickets[ticket] = list(linked_lpe)
    return lpe_tickets

lpe_tickets = reduce(partial(lookup_tickets, len(tickets)), enumerate(tickets), lpe_tickets)

with open('lpe_tickets.json', 'w') as f:
    json.dump(lpe_tickets, f)