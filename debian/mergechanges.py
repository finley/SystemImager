#!/usr/bin/python

import sys, re
import deb822
import os.path

def isdsc(file):
	if file[-4:] == ".dsc":
		return True
	return False

def ischanges(file):
	if file[-8:] == ".changes":
		return True
	return False

## main ##

changesRe = re.compile("^(?P<pkg>.*)_(?P<version>.*)_(?P<arch>.*).changes$")

for arg in sys.argv[1:]:
	if not os.path.isdir(arg):
		sys.stderr.write("Error: " + arg + " is not a directory.\n")
		sys.exit(1)

contents = os.listdir(sys.argv[1])
## Use the first directory as the baseline, or "master"
dscMaster = None
changesMaster = None
for file in contents:
	fqpath = os.path.join(sys.argv[1], file)
	if isdsc(file):
		dscName = file
		dscMaster = deb822.deb822(open(fqpath))
	if ischanges(file):
		changesName = file
		m = changesRe.match(file)
		pkg = m.group('pkg')
		ver = m.group('version')
		archs = [m.group('arch')]

		changesMaster = deb822.deb822(open(fqpath))
	if dscMaster and changesMaster:
		break

if not dscMaster:
	sys.stderr.write("Error: No .dsc file found in " + sys.argv[1] + "\n")
	sys.exit(1)
	
if not changesMaster:
	sys.stderr.write("Error: No .changes file found in " + sys.argv[1] + "\n")
	sys.exit(1)


## Process all the additional directories
for arg in sys.argv[2:]:
	dscCur = None
	changesCur = None
	contents = os.listdir(arg)
	for file in contents:
		fqpath = os.path.join(arg, file)
		if isdsc(file):
			dscCur = deb822.deb822(open(fqpath))
		if ischanges(file):
			m = changesRe.match(file)
			archs.append(m.group('arch'))
			changesCur = deb822.deb822(open(fqpath))
		if dscCur and changesCur:
			break
		
	if not dscCur:
		sys.stderr.write("Error: No .dsc file found in " + sys.argv[1] + "\n")
		sys.exit(1)
	if not changesCur:
		sys.stderr.write("Error: No .changes file found in " + sys.argv[1] + "\n")
		sys.exit(1)

	dscMaster.mergeFields("Binary", dscCur)
	changesMaster.mergeFields("Binary", changesCur)
	changesMaster.mergeFields("Description", changesCur)
	changesMaster.mergeFields("Files", changesCur)
#	print changesMaster.map["Files"]

filenames = []
newFiles = ""
for s in changesMaster.map["Files"].splitlines(True):
	fields = s.split()
	if len(fields) > 4:
		filename = fields[4]
	else:
		filename = ""
	if filename not in filenames:
		newFiles = newFiles + s
		filenames.append(filename)
changesMaster.map["Files"] = newFiles

dscMaster.dump(open(dscName + ".new", 'w'))

changesOut = pkg + '_' + ver + '_' + archs[0]
for arch in archs[1:]:
	changesOut = changesOut + '+' + arch
changesOut = changesOut + '.changes'

changesMaster.dump(open(changesOut, 'w'))

