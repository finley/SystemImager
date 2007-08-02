#!/usr/bin/python

import re, string

class deb822:
    def __init__(self, fp):
        self.map = {}
        self.keys = []
        single = re.compile("^(?P<key>\S+):\s+(?P<data>\S.*)$")
        multi = re.compile("^(?P<key>\S+):\s*$")
        multidata = re.compile("^\s(?P<data>.*)$")
        ws = re.compile("^\s*$")
        
        curkey = None
        content = ""
        for line in fp.readlines():
            if ws.match(line):
                if curkey:
                    self.map[curkey] = content[:-1]
                    curkey = None
                    content = ""
                continue
            
            m = single.match(line)
            if m:
                if curkey:
                    self.map[curkey] = content[:-1]
                curkey = m.group('key')
                self.keys.append(curkey)
                self.map[curkey] = m.group('data')
                curkey = None
                content = ""
                continue

            m = multi.match(line)
            if m:
                if curkey:
                    self.map[curkey] = content[:-1]
                curkey = m.group('key')
                self.keys.append(curkey)
                content = "\n"
                continue

            m = multidata.match(line)
            if m:
                content = content + line
                continue

        if curkey:
            self.map[curkey] = content[:-1]

    def dump(self, fd):
        for key in self.keys:
            fd.write(key + ": " + self.map[key] + "\n")

    def isSingleLine(self, s):
        if s.count("\n"):
            return False
        else:
            return True

    def isMultiLine(self, s):
        return not self.isSingleLine(s)

    def _mergeFields(self, s1, s2):
        if not s2:
            return s1
        if not s1:
            return s2
        
        if self.isSingleLine(s1) and self.isSingleLine(s2):
            ## some fields are delimited by a single space, others
            ## a comma followed by a space.  this heuristic assumes
            ## that there are multiple items in one of the string fields
            ## so that we can pick up on the delimiter being used
            delim = ' '
            if (s1 + s2).count(', '):
                delim = ', '

            L = (s1 + delim + s2).split(delim)
            L.sort()

            prev = merged = L[0]
            
            for item in L[1:]:
                ## skip duplicate entries
                if item == prev:
                    continue
                merged = merged + delim + item
                prev = item
            return merged
            
        if self.isMultiLine(s1) and self.isMultiLine(s2):
            for item in s2.splitlines(True):
                if item not in s1.splitlines(True):
                    s1 = s1 + "\n" + item
            return s1

        raise ValueError
    
    def mergeFields(self, key, d1, d2 = None):
        ## this method can work in two ways - abstract that away
        if d2 == None:
            x1 = self
            x2 = d1
        else:
            x1 = d1
            x2 = d2

        ## we only have to do work if both objects contain our key
        ## otherwise, we just take the one that does, or raise an
        ## exception if neither does
        if key in x1.keys and key in x1.keys:
            merged = self._mergeFields(x1.map[key], x2.map[key])
        elif key in x1.keys:
            merged = x1[key]
        elif key in x2.keys:
            merged = x2[key]
        else:
            raise KeyError

        ## back to the two different ways - if this method was called
        ## upon an object, update that object in place.
        ## return nothing in this case, to make the author notice a
        ## problem if she assumes the object itself will not be modified
        if d2 == None:
            self.map[key] = merged
            return None

        return merged
