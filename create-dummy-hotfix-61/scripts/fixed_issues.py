#!/usr/bin/env python

from functools import reduce
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

commits = git.log('--pretty=%s', 'fix-pack-base-6120..HEAD').split('\n')
tickets = reduce(extract_tickets, commits, set())

lpe_tickets = {}

if os.path.exists('lpe_tickets.json'):
    with open('lpe_tickets.json', 'r') as f:
        lpe_tickets = json.load(f)

def lookup_tickets(tickets, ticket):
    print('Checking %s...' % ticket)

    if ticket in tickets:
        return tickets
    
    if ticket[:3] == 'LPE':
        tickets[ticket] = [ticket]
        return tickets
    
    lpe_query = 'project = LPE and issue in linkedIssues(%s)' % ticket
    linked_lpe = get_issues(lpe_query, []).keys()
    tickets[ticket] = list(linked_lpe)
    return tickets

lpe_tickets = reduce(lookup_tickets, tickets, lpe_tickets)

with open('lpe_tickets.json', 'w') as f:
    json.dump(lpe_tickets, f)