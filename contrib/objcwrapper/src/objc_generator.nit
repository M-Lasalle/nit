# This file is part of NIT ( http://www.nitlanguage.org ).
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

# Code generation
module objc_generator

import opts

import objc_model

redef class Sys

	# Path to the output file
	var opt_output = new OptionString("Output file", "-o")

	# Shall `init` methods/constructors be wrapped as methods?
	#
	# By default, these methods/constructors are wrapped as extern constructors.
	# So initializing an extern Objective-C object looks like:
	# ~~~nitish
	# var o = new NSArray.init_with_array(some_other_array)
	# ~~~
	#
	# If this option is set, the object must first be allocated and then initialized.
	# This is closer to the Objective-C behavior:
	# ~~~nitish
	# var o = new NSArray
	# o.init_with_array(some_other_array)
	# ~~~
	var opt_init_as_methods = new OptionBool(
		"Wrap `init...` constructors as Nit methods instead of Nit constructors",
		"--init-as-methods")

	private var objc_to_nit_types: Map[String, String] is lazy do
		var types = new HashMap[String, String]
		types["char"] = "Byte"
		types["short"] = "Int"
		types["short int"] = "Int"
		types["int"] = "Int"
		types["long"] = "Int"
		types["long int"] = "Int"
		types["long long"] = "Int"
		types["long long int"] = "Int"
		types["float"] = "Float"
		types["double"] = "Float"
		types["long double"] = "Float"

		types["NSUInteger"] = "Int"
		types["BOOL"] = "Bool"
		types["id"] = "NSObject"
		types["constid"] = "NSObject"
		types["SEL"] = "NSObject"
		types["void"] = "Pointer"

		return types
	end
end

redef class ObjcModel
	redef fun knows_type(objc_type) do return super or
		objc_to_nit_types.keys.has(objc_type)
end

# Wrapper generator
class CodeGenerator

	# `ObjcModel` to wrap
	var model: ObjcModel

	# Generate Nit code to wrap `classes`
	fun generate
	do
		var classes = model.classes

		# Open specified path or stdin
		var file
		var path = opt_output.value
		if path != null then
			if path.file_extension != "nit" then
				print_error "Warning: output file path does not end with '.nit'"
			end

			file = new FileWriter.open(path)
		else
			file = stdout
		end

		# Generate code
		file.write "import cocoa::foundation\n\n"
		for classe in classes do
			write_class(classe, file)
		end

		if path != null then file.close
	end

	private fun write_class(classe: ObjcClass, file: Writer)
	do
		# Class header
		file.write """

extern class {{{classe.name}}} in "ObjC" `{ {{{classe.name}}} * `}
"""

		# Supers
		for super_name in classe.super_names do file.write """
	super {{{super_name}}}
"""
		if classe.super_names.is_empty then file.write """
	super NSObject
"""

		file.write "\n"

		# Constructor or constructors
		write_constructors(classe, file)

		# Attributes
		for attribute in classe.attributes do
			write_attribute(attribute, file)
		end

		# Methods
		for method in classe.methods do
			if not model.knows_all_types(method) then method.is_commented = true

			if not opt_init_as_methods.value and method.is_init then continue

			write_method_signature(method, file)
			write_objc_method_call(method, file)
		end

		file.write """
end
"""
	end

	private fun write_constructors(classe: ObjcClass, file: Writer)
	do
		if opt_init_as_methods.value then
			# A single constructor for `alloc`
			file.write """
	new in "ObjC" `{
		return [{{{classe.name}}} alloc];
	`}

"""
			return
		end

		# A constructor per `init...` method
		for method in classe.methods do
			if not method.is_init then continue

			if not model.knows_all_types(method) then method.is_commented = true

			write_method_signature(method, file)

				write_objc_init_call(classe.name, method, file)
		end
	end

	private fun write_attribute(attribute: ObjcAttribute, file: Writer)
	do
		if not model.knows_type(attribute.return_type) then attribute.is_commented = true

		write_attribute_getter(attribute, file)
		# TODO write_attribute_setter if there is no `readonly` annotation
	end

	private fun write_attribute_getter(attribute: ObjcAttribute, file: Writer)
	do
		var nit_attr_name = attribute.name.to_snake_case
		var nit_attr_type = attribute.return_type.objc_to_nit_type

		var c = attribute.comment_str

		file.write """
{{{c}}}	fun {{{nit_attr_name}}}: {{{nit_attr_type}}} in "ObjC" `{
{{{c}}}		return [self {{{attribute.name}}}];
{{{c}}}	`}

"""
	end

	private fun write_attribute_setter(attribute: ObjcAttribute, file: Writer)
	do
		var nit_attr_name = attribute.name.to_snake_case
		var nit_attr_type = attribute.return_type.objc_to_nit_type

		var c = attribute.comment_str

		file.write """
{{{c}}}	fun {{{nit_attr_name}}}=(value: {{{nit_attr_type}}}) in "ObjC" `{
{{{c}}}		return self.{{{attribute.name}}} = value;
{{{c}}}	`}

"""
	end

	private fun write_method_signature(method: ObjcMethod, file: Writer)
	do
		var c = method.comment_str

		# Build Nit method name
		var name = ""
		for param in method.params do
			name += param.name[0].to_upper.to_s + param.name.substring_from(1)
		end
		name = name.to_snake_case

		if name == "init" then name = ""

		# Kind of method
		var fun_keyword = "fun"
		if not opt_init_as_methods.value and method.is_init then
			fun_keyword = "new"
		end

		# Params
		var params = new Array[String]
		for param in method.params do
			if param.is_single then break
			params.add "{param.variable_name}: {param.return_type.objc_to_nit_type}"
		end

		var params_with_par = ""
		if params.not_empty then params_with_par = "({params.join(", ")})"

		# Return
		var ret = ""
		if method.return_type != "void" and fun_keyword != "new" then
			ret = ": {method.return_type.objc_to_nit_type}"
		end

		file.write """
{{{c}}}	{{{fun_keyword}}} {{{name}}}{{{params_with_par}}}{{{ret}}} in "ObjC" `{
"""
	end

	# Write a combined call to alloc and to a constructor/method
	private fun write_objc_init_call(class_name: String, method: ObjcMethod, file: Writer)
	do
		# Method name and other params
		var params = new Array[String]
		for param in method.params do
			if not param.is_single then
				params.add "{param.name}: {param.variable_name}"
			else params.add param.name
		end

		var c = method.comment_str

		file.write """
{{{c}}}		return [[{{{class_name}}} alloc] {{{params.join(" ")}}}];
{{{c}}}	`}

"""
	end

	private fun write_objc_method_call(method: ObjcMethod, file: Writer)
	do
		# Is there a value to return?
		var ret = ""
		if method.return_type != "void" then ret = "return "

		# Method name and other params
		var params = new Array[String]
		for param in method.params do
			if not param.is_single then
				params.add "{param.name}: {param.variable_name}"
			else params.add param.name
		end

		var c = method.comment_str

		file.write """
{{{c}}}		{{{ret}}}[self {{{params.join(" ")}}}];
{{{c}}}	`}

"""
	end
end

redef class Text
	# Nit equivalent to this type
	private fun objc_to_nit_type: String
	do
		var types = sys.objc_to_nit_types

		if types.has_key(self) then
			return types[self]
		else
			return to_s
		end
	end
end

redef class Property
	private fun comment_str: String do if is_commented then
		return "#"
	else return ""
end