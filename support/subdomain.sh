#!/bin/sh

# Remove all comments, remove all whitespace (including carriage returns),
# remove empty lines, lowercase everything, and finally print only the first
# word.
cat /vagrant/config/ngrok_subdomain.txt |
	sed -e '/^\s*#/d' -e 's/\s//g' -e '/^$/d' |
	awk '{print tolower($0)}' | awk '{print $1}'
