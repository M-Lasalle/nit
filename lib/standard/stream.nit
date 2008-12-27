# This file is part of NIT ( http://www.nitlanguage.org ).
#
# Copyright 2004-2008 Jean Privat <jean@pryen.org>
#
# This file is free software, which comes along with NIT.  This software is
# distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
# without  even  the implied warranty of  MERCHANTABILITY or  FITNESS FOR A 
# PARTICULAR PURPOSE.  You can modify it is you want,  provided this header
# is kept unaltered, and a notification of the changes is added.
# You  are  allowed  to  redistribute it and sell it, alone or is a part of
# another product.

# This module handle abstract input and output streams
package stream

import string

# Abstract stream class
class IOS
	# close the stream
	meth close is abstract
end

# Abstract input streams
class IStream
special IOS
	# Read a character. Return its ASCII value, -1 on EOF or timeout
	meth read_char: Int is abstract

	# Read at most i bytes
	meth read(i: Int): String
	do
		var s = new String.with_capacity(i)
		while i > 0 and not eof do
			var c = read_char
			if c >= 0 then
				s.add(c.ascii)
				i -= 1
			end
		end
		return s
	end

	# Read a string until the end of the line.
	meth read_line: String
	do
		assert not eof
		var s = new String
		append_line_to(s)
		return s
	end

	# Read all the stream until the eof.
	meth read_all: String
	do
		var s = ""
		while not eof do
			var c = read_char
			if c >= 0 then s.add(c.ascii)
		end
		return s
	end

	# Read a string until the end of the line and append it to `s'.
	meth append_line_to(s: String)
	do
		while true do
			var x = read_char
			if x == -1 then
				if eof then return
			else
				var c = x.ascii
				s.push(c)
				if c == '\n' then return
			end
		end
	end

	# Is there something to read.
	meth eof: Bool is abstract
end

# Abstract output stream
class OStream
special IOS
	# write a string
	meth write(s: String) is abstract

	# Can the stream be used to write
	meth is_writable: Bool is abstract
end

# Input streams with a buffer
class BufferedIStream
special IStream
	redef meth read_char
	do
		assert not eof
		if _buffer_pos >= _buffer.length then
			fill_buffer
		end
		if _buffer_pos >= _buffer.length then
			return -1
		end
		var c = _buffer[_buffer_pos]
		_buffer_pos += 1
		return c.ascii
	end

	redef meth read(i)
	do
		var s = new String.with_capacity(i)
		var j = _buffer_pos
		var k = _buffer.length
		while i > 0 do
			if j >= k then
				fill_buffer
				if eof then return s
				j = _buffer_pos
				k = _buffer.length
			end
			while j < k and i > 0 do
				s.add(_buffer[j])
				j +=  1
				i -= 1
			end
		end
		_buffer_pos = j
		return s
	end

	redef meth read_all
	do
		var s = ""
		while not eof do
			var j = _buffer_pos
			var k = _buffer.length
			while j < k do
				s.add(_buffer[j])
				j += 1
			end
			_buffer_pos = j
			fill_buffer
		end
		return s
	end   

	redef meth append_line_to(s)
	do
		while true do
			# First phase: look for a '\n'
			var i = _buffer_pos
			while i < _buffer.length and _buffer[i] != '\n' do i += 1

			# if there is something to append
			if i > _buffer_pos then
				# Enlarge the string (if needed)
				s.enlarge(s.length + i - _buffer_pos)

				# Copy from the buffer to the string
				var j = _buffer_pos
				while j < i do
					s.add(_buffer[j])
					j += 1
				end
			end

			if i < _buffer.length then
				# so \n is in _buffer[i]
				_buffer_pos = i + 1 # skip \n
				return
			else
				# so \n is not found
				_buffer_pos = i
				if end_reached then
					return
				else
					fill_buffer
				end
			end
		end
	end

	redef meth eof do return _buffer_pos >= _buffer.length and end_reached

	# The buffer
	attr _buffer: String = null

	# The current position in the buffer
	attr _buffer_pos: Int = 0

	# Fill the buffer
	protected meth fill_buffer is abstract

	# Is the last fill_buffer reach the end 
	protected meth end_reached: Bool is abstract

	# Allocate a `_buffer' for a given `capacity'.
	protected meth prepare_buffer(capacity: Int)
	do
		_buffer = new String.with_capacity(capacity)
		_buffer_pos = 0 # need to read
	end
end

class IOStream
special IStream
special OStream
end

##############################################################"

class FDStream
special IOS
	# File description
	attr _fd: Int

	redef meth close do native_close(_fd)

	private meth native_close(i: Int): Int is extern "stream_FDStream_FDStream_native_close_1"
	private meth native_read_char(i: Int): Int is extern "stream_FDStream_FDStream_native_read_char_1"
	private meth native_read(i: Int, buf: NativeString, len: Int): Int is extern "stream_FDStream_FDStream_native_read_3"
	private meth native_write(i: Int, buf: NativeString, len: Int): Int is extern "stream_FDStream_FDStream_native_write_3"

	init(fd: Int) do _fd = fd
end

class FDIStream
special FDStream
special IStream
	redef readable attr _eof: Bool
	
	redef meth read_char
	do
		var nb = native_read_char(_fd)
		if nb == -1 then _eof = true
		return nb
	end

	init(fd: Int) do end 
end

class FDOStream
special FDStream
special OStream
	redef readable attr _is_writable: Bool

	redef meth write(s)
	do
		var nb = native_write(_fd, s.to_cstring, s.length)
		if nb < s.length then _is_writable = false
	end

	init(fd: Int)
	do
		_is_writable = true
	end
end

class FDIOStream
special FDIStream
special FDOStream
special IOStream
	init(fd: Int)
	do
		_fd = fd
		_is_writable = true
	end
end
