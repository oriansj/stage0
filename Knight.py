import os, os.path
import string
import array
import time
import cherrypy
import User_Interface as UI

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
		return UI.returnPage()

	@cherrypy.expose
	def RESET(self):
		UI.Reset_lilith()
		return UI.returnPage()

	@cherrypy.expose
	def DEBUG(self, Inst=""):
		UI.Watchpoints
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

if __name__ == '__main__':
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
