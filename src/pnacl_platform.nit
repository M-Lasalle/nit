# This file is part of NIT ( http://www.nitlanguage.org )
#
# Copyright 2014 Johan Kayser <kayser.johan@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Compile program for the PNaCl platform
module pnacl_platform

import platform
import abstract_compiler

redef class ToolContext
	redef fun platform_from_name(name)
	do
		if name == "pnacl" then return new PnaclPlatform
		return super
	end
end

class PnaclPlatform
	super Platform

	redef fun supports_libunwind do return false

	redef fun no_main do return true

	redef fun toolchain(toolcontext) do return new PnaclToolchain(toolcontext)
end

class PnaclToolchain
	super MakefileToolchain

	redef fun write_files(compiler, compile_dir, cfiles)
	do
		var app_name = compiler.mainmodule.name

		# create compile_dir
		var dir = compile_dir
		if not dir.file_exists then dir.mkdir

		# compile normal C files
		super(compiler, compile_dir, cfiles)

		# Gather extra C files generated elsewhere than in super
		for f in compiler.extern_bodies do
			if f isa ExternCFile then cfiles.add(f.filename.basename(""))
		end

		# Outname
		var outname = toolcontext.opt_output.value
		if outname == null then outname = "{compiler.mainmodule.name}"

		var ofiles = new Array[String]
		for cfile in cfiles do ofiles.add(cfile.substring(0, cfile.length-2) + ".o")

		## Generate makefile
		var file = "{dir}/Makefile"
		"""
# This file was generated by Nit, any modification will be lost.

# Get pepper directory for toolchain and includes.
#
# If NACL_SDK_ROOT is not set, then assume it can be found five directories up.
#
THIS_MAKEFILE := $(abspath $(lastword $(MAKEFILE_LIST)))
NACL_SDK_ROOT ?= $(abspath $(dir $(THIS_MAKEFILE))../../../..)

# Project Build flags
WARNINGS := -Wall -pedantic -Werror -Wno-long-long -Wno-unused-value -Wno-unused-label -Wno-duplicate-decl-specifier -Wno-switch -Wno-embedded-directive
CXXFLAGS := -pthread $(WARNINGS)

CXXFLAGS += -g -O0 # Debug
# CXXFLAGS += -O3  # Release

#
# Compute tool paths
#
GETOS := python $(NACL_SDK_ROOT)/tools/getos.py
OSHELPERS = python $(NACL_SDK_ROOT)/tools/oshelpers.py
OSNAME := $(shell $(GETOS))

PNACL_TC_PATH := $(abspath $(NACL_SDK_ROOT)/toolchain/$(OSNAME)_pnacl)
PNACL_CXX := $(PNACL_TC_PATH)/bin/pnacl-clang
PNACL_FINALIZE := $(PNACL_TC_PATH)/bin/pnacl-finalize
CXXFLAGS += -I$(NACL_SDK_ROOT)/include
LDFLAGS := -L$(NACL_SDK_ROOT)/lib/pnacl/Release -lppapi_cpp -lppapi

#
# Disable DOS PATH warning when using Cygwin based tools Windows
#
CYGWIN ?= nodosfilewarning
export CYGWIN

# Declare the ALL target first, to make the 'all' target the default build
all: ../{{{outname}}}/{{{app_name}}}.pexe

.c.o:
	$(PNACL_CXX) -c $< -g -O0 $(CXXFLAGS)

{{{app_name}}}.pexe: {{{ofiles.join(" ")}}}
	$(PNACL_CXX) -o $@ $^ $(LDFLAGS)

../{{{outname}}}/{{{app_name}}}.pexe: {{{app_name}}}.pexe
	$(PNACL_FINALIZE) -o $@ $<
		""".write_to_file(file)

		### generate the minimal index.html
		if not outname.file_exists then outname.mkdir
		file = "{outname}/index.html"

		if not file.file_exists then """
<!DOCTYPE html>
<html>
  <!--
  This file was generated by Nit, any modification will be lost.
  -->
<head>
	<title>{{{app_name}}}</title>
	<script src="js/pnacl_js.js"></script>
</head>
<body onload="pageDidLoad()">
	<h1>PNaCl : Minimal HTML for {{{app_name}}}</h1>
	<p>
  <!--
  Load the published pexe.
  Note: Since this module does not use any real-estate in the browser, its
  width and height are set to 0.

  Note: The <embed> element is wrapped inside a <div>, which has both a 'load'
  and a 'message' event listener attached.  This wrapping method is used
  instead of attaching the event listeners directly to the <embed> element to
  ensure that the listeners are active before the NaCl module 'load' event
  fires.  This also allows you to use PPB_Messaging.PostMessage() (in C) or
  pp::Instance.PostMessage() (in C++) from within the initialization code in
  your module.
  -->
		<div id="listener">
			<script type="text/javascript">
				var listener = document.getElementById('listener');
				listener.addEventListener('load', moduleDidLoad, true);
				listener.addEventListener('message', handleMessage, true);
			</script>

			<embed id="{{{app_name}}}"
				width=0 height=0
				src="{{{app_name}}}.nmf"
				type="application/x-pnacl" />
		</div>
		</p>
		<h2>Status <code id="statusField">NO-STATUS</code></h2>
</body>
</html>
		""".write_to_file(file)

		### generate pnacl_js.js in a folder named 'js'
		dir = "{outname}/js/"
		if not dir.file_exists then dir.mkdir
		file = "{dir}/pnacl_js.js"
		if not file.file_exists then """
// This file was generated by Nit, any modification will be lost.

{{{app_name}}}Module = null;  // Global application object.
statusText = 'NO-STATUS';

// Indicate load success.
function moduleDidLoad() {
	{{{app_name}}}Module = document.getElementById('{{{app_name}}}');
	updateStatus('SUCCESS');
	// Send a message to the Native Client module like that
	//{{{app_name}}}Module.postMessage('Hello World');
}

// The 'message' event handler.  This handler is fired when the NaCl module
// posts a message to the browser by calling PPB_Messaging.PostMessage()
// (in C) or pp::Instance.PostMessage() (in C++).  This implementation
// simply displays the content of the message in an alert panel.
function handleMessage(message_event) {
	console.log(message_event.data);
}

// If the page loads before the Native Client module loads, then set the
// status message indicating that the module is still loading.  Otherwise,
// do not change the status message.
function pageDidLoad() {
	if ({{{app_name}}}Module == null) {
	        updateStatus('LOADING...');
	} else {
		// It's possible that the Native Client module onload event fired
		// before the page's onload event.  In this case, the status message
		// will reflect 'SUCCESS', but won't be displayed.  This call will
		// display the current message.
		updateStatus();
	}
}

// Set the global status message.  If the element with id 'statusField'
// exists, then set its HTML to the status message as well.
// opt_message The message test.  If this is null or undefined, then
// attempt to set the element with id 'statusField' to the value of
// |statusText|.
function updateStatus(opt_message) {
	if (opt_message)
	        statusText = opt_message;
	var statusField = document.getElementById('statusField');
	if (statusField) {
	        statusField.innerHTML = statusText;
	}
}
		""".write_to_file(file)

		### generate the manifest file : app_name.nmf
		# used to point the HTML to the Native Client module
		# and optionally provide additional commands to the PNaCl translator in Chrome
		file = "{outname}/{app_name}.nmf"
		"""
{
	"program": {
		"portable": {
			"pnacl-translate": {
				"url": "{{{app_name}}}.pexe"
			}
		}
	}
}
		""".write_to_file(file)
	end

	redef fun write_makefile(compiler, compile_dir, cfiles)
	do
		# Do nothing, already done in `write_files`
	end

	redef fun compile_c_code(compiler, compile_dir)
	do
		# Generate the pexe
		toolcontext.exec_and_check(["make", "-C", compile_dir], "PNaCl project error")
	end
end
