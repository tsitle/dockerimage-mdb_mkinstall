#!/usr/bin/env python

#
# by TS, Mar 2019
#

import sys, json, argparse

DEF_RADICALE_SERVER_LOC = 'http://127.0.0.1:5232'
DEF_RADICALE_RIGHTS_FN = '/etc/radicale/modo_rights/rights'

DEF_WEBMAIL_ATTACHMENT_FILESIZE_MAX = '10M'

parser = argparse.ArgumentParser(description='Customize Modoboa configuration.')
parser.add_argument('cmd', choices=['build', 'inst'], help='Use "build" when building the Modoboa Docker Image and "inst" when installing the Image')
parser.add_argument('JSONDATAINPUT', metavar='JSON', help='Either JSON-encoded data or "-" to read the JSON data from STDIN')
parser.add_argument('--davhost')
parser.add_argument('--mailhost')
parser.add_argument('--maildomain', required=True)
parser.add_argument('--default_password', help='Only for command "inst"')
parser.add_argument('--secret_key', help='Only for command "inst"')

args = parser.parse_args()
args = vars(args)
#print args

if args['JSONDATAINPUT'] == '-':
	jsonData = json.load(sys.stdin)
else:
	jsonData = json.loads(args['JSONDATAINPUT'])

jsonData['modoboa_stats']['logfile'] = '/var/log/mail/mail.log'

try:
	jsonData['modoboa_radicale']['rights_file_path'] = DEF_RADICALE_RIGHTS_FN
except:
	tmpSubDict = {
		'rights_file_path': DEF_RADICALE_RIGHTS_FN
	}
	jsonData['modoboa_radicale'] = tmpSubDict

if args['davhost'] != None:
	jsonData['modoboa_radicale']['server_location'] = 'https://' + args['davhost'] + '.' + args['maildomain']
elif 'server_location' not in jsonData['modoboa_radicale']:
	jsonData['modoboa_radicale']['server_location'] = DEF_RADICALE_SERVER_LOC

if args['cmd'] == 'inst':
	try:
		jsonData['core']['check_new_versions'] = False
	except:
		tmpSubDict = {
			'check_new_versions': False
		}
		jsonData['core'] = tmpSubDict

	if args['maildomain'] != None:
		jsonData['core']['sender_address'] = 'noreply@' + args['maildomain']
		if args['mailhost'] != None:
			jsonData['modoboa_pdfcredentials']['imap_server_address'] = args['mailhost'] + '.' + args['maildomain']
			jsonData['modoboa_pdfcredentials']['smtp_server_address'] = jsonData['modoboa_pdfcredentials']['imap_server_address']
			jsonData['modoboa_pdfcredentials']['webpanel_url'] = 'https://' + jsonData['modoboa_pdfcredentials']['imap_server_address'] + '/accounts/login/'
	if args['default_password'] != None:
		jsonData['core']['default_password'] = args['default_password'];
	if args['secret_key'] != None:
		jsonData['core']['secret_key'] = args['secret_key'];
	try:
		jsonData['modoboa_webmail']['max_attachment_size'] = DEF_WEBMAIL_ATTACHMENT_FILESIZE_MAX
	except:
		tmpSubDict = {
			'max_attachment_size': DEF_WEBMAIL_ATTACHMENT_FILESIZE_MAX
		}
		jsonData['modoboa_webmail'] = tmpSubDict

try:
	""" For Python v2.x: """
	print json.dumps(jsonData)
except:
	""" For Python v3.x: """
	print(json.dumps(jsonData))
