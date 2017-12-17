## Copyright (C) 2016 Jeremiah Orians
## This file is part of stage0.
##
## stage0 is free software: you an redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.
##
## stage0 is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with stage0.  If not, see <http://www.gnu.org/licenses/>.

import os, os.path
import string
import array
import time
import cherrypy
import User_Interface as UI
import sys

class StringGenerator(object):
	@cherrypy.expose
	def index(self):
		return UI.returnPage()

	@cherrypy.expose
	def Memory(self, col=8, row=8, value=0):
		if 0 > int(col) or 0 > int(row):
			return "Out of range"
		if int(value, 16) > 255:
			return "Too big"
		UI.Set_Memory(int(col)+(int(row) * 16) + UI.Current_Page , int(value, 16))
		return UI.returnPage()

	@cherrypy.expose
	def Register(self, Reg="", value=0):
		UI.Set_Register(int(Reg[1:]), int(value, 16))
		return UI.returnPage()

	@cherrypy.expose
	def RUN(self):
		UI.Step_lilith()
		if UI.Current_IP in UI.Watchpoints:
			raise cherrypy.HTTPRedirect("/")
		return UI.returnPage()

	@cherrypy.expose
	def STEP(self):
		UI.Step_lilith()
		return UI.returnPage()

	@cherrypy.expose
	def STOP(self):
		print("Stopping after: " + str(UI.Count) + " Instructions" )
		return UI.returnPage()

	@cherrypy.expose
	def RESET(self):
		UI.Reset_lilith()
		return UI.returnPage()

	@cherrypy.expose
	def DEBUG(self, Inst=""):
		if int(Inst, 16) in UI.Watchpoints:
			UI.Watchpoints.remove(int(Inst, 16))
			print("Watchpoint Deleted: " + Inst)
		else:
			UI.Watchpoints.add(int(Inst, 16))
		return UI.returnPage()

	@cherrypy.expose
	def PAGEDOWN(self):
		UI.Current_Page = UI.Current_Page + 4096
		return UI.returnPage()

	@cherrypy.expose
	def PAGEUP(self):
		UI.Current_Page = UI.Current_Page - 4096
		if 0 > UI.Current_Page:
			UI.Current_Page = 0
		return UI.returnPage()

	@cherrypy.expose
	def WINDOW(self, Window=0):
		UI.Current_Page = int(Window, 16)
		return UI.returnPage()

	@cherrypy.expose
	def SPEEDBREAKPOINT(self):
		UI.Step_lilith()
		while UI.Current_IP not in UI.Watchpoints:
			UI.Step_lilith()
			if UI.Count == UI.Debug_Point:
				break
		return UI.returnPage()

if __name__ == '__main__':
	 UI.main(sys.argv[1:])
	 conf = {
		  '/': {
				'tools.sessions.on': True,
				'tools.staticdir.root': os.path.abspath(os.getcwd())
		},
		  '/generator': {
				'request.dispatch': cherrypy.dispatch.MethodDispatcher(),
				'tools.response_headers.on': True,
				'tools.response_headers.headers': [('Content-Type', 'text/plain')],
		},
		  '/static': {
				'tools.staticdir.on': True,
				'tools.staticdir.dir': './public'
		}
	}

	 webapp = StringGenerator()
	 webapp.generator = StringGenerator()
	 cherrypy.quickstart(webapp, '/', conf)
