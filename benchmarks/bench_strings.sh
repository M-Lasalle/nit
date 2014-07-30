#!/bin/bash
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

source ./bench_common.sh
source ./bench_plot.sh

# Default number of times a command must be run with bench_command
# Can be overrided with 'the option -n'
count=2

function usage()
{
	echo "run_bench: [options]* bench_name args"
	echo "  -v: verbose mode"
	echo "  -n count: number of execution for each bar (default: $count)"
	echo "  -h: this help"
	echo ""
	echo "Benches : "
	echo "  all : all benches"
	echo "    - usage : * max_nb_cct loops strlen"
	echo "  iter: bench iterations"
	echo "    - usage : iter max_nb_cct loops strlen"
	echo "  cct: concatenation benching"
	echo "    - usage : cct max_nb_cct loops strlen"
	echo "  substr: substring benching"
	echo "    - usage : substr max_nb_cct loops strlen"
}

function benches()
{
	bench_concat $@;
	bench_iteration $@;
	bench_substr $@;
}

function bench_concat()
{
	if $verbose; then
		echo "*** Benching concat performance ***"
	fi

	prepare_res concat_ropes.out concat_ropes ropes
	if $verbose; then
		echo "Ropes :"
	fi
	for i in `seq 1 "$1"`; do
		if $verbose; then
			echo "String length = $i, Concats/loop = $2, Loops = $3"
		fi
		bench_command $i ropes$i ./chain_concat -m rope --loops $2 --strlen $3 --ccts $i "NIT_GC_CHOOSER=large"
	done

	prepare_res concat_flat.out concat_flat flatstring
	if $verbose; then
		echo "FlatStrings :"
	fi
	for i in `seq 1 "$1"`; do
		if $verbose; then
			echo "String length = $i, Concats/loop = $2, Loops = $3"
		fi
		bench_command $i flatstring$i ./chain_concat -m flatstr --loops $2 --strlen $3 --ccts $i "NIT_GC_CHOOSER=large"
	done

	prepare_res concat_buf.out concat_buf flatbuffer
	if $verbose; then
		echo "FlatBuffers :"
	fi
	for i in `seq 1 "$1"`; do
		if $verbose; then
			echo "String length = $i, Concats/loop = $2, Loops = $3"
		fi
		bench_command $i flatbuffer$i ./chain_concat -m flatbuf --loops $2 --strlen $3 --ccts $i "NIT_GC_CHOOSER=large"
	done

	plot concat.gnu
}

function bench_iteration()
{
	if $verbose; then
		echo "*** Benching iteration performance ***"
	fi

	prepare_res iter_ropes_iter.out iter_ropes_iter ropes_iter
	if $verbose; then
		echo "Ropes by iterator :"
	fi
	for i in `seq 1 "$1"`; do
		if $verbose; then
			echo "String base length = $1, Concats (depth of the rope) = $i, Loops = $3"
		fi
		bench_command $i ropes_iter$i ./iteration_bench -m rope --iter-mode iterator --loops $2 --strlen $3 --ccts $i "NIT_GC_CHOOSER=large"
	done

	prepare_res iter_ropes_index.out iter_ropes_index ropes_index
	if $verbose; then
		echo "Ropes by index :"
	fi
	for i in `seq 1 "$1"`; do
		if $verbose; then
			echo "String base length = $1, Concats (depth of the rope) = $i, Loops = $3"
		fi
		bench_command $i ropes_index$i ./iteration_bench -m rope --iter-mode index --loops $2 --strlen $3 --ccts $i "NIT_GC_CHOOSER=large"
	done

	prepare_res iter_flat_iter.out iter_flat_iter flatstring_iter
	if $verbose; then
		echo "FlatStrings by iterator :"
	fi
	for i in `seq 1 "$1"`; do
		if $verbose; then
			echo "String base length = $1, Concats = $i, Loops = $3"
		fi
		bench_command $i flatstr_iter$i ./iteration_bench -m flatstr --iter-mode iterator --loops $2 --strlen $3 --ccts $i "NIT_GC_CHOOSER=large"
	done

	prepare_res iter_flat_index.out iter_flat_index flatstring_index
	if $verbose; then
		echo "FlatStrings by index :"
	fi
	for i in `seq 1 "$1"`; do
		if $verbose; then
			echo "String base length = $1, Concats = $i, Loops = $3"
		fi
		bench_command $i flatstr_index$i ./iteration_bench -m flatstr --iter-mode index --loops $2 --strlen $3 --ccts $i "NIT_GC_CHOOSER=large"
	done

	prepare_res iter_buf_iter.out iter_buf_iter flatbuffer_iter
	if $verbose; then
		echo "FlatBuffers by iterator :"
	fi
	for i in `seq 1 "$1"`; do
		if $verbose; then
			echo "String base length = $1, Concats = $i, Loops = $3"
		fi
		bench_command $i flatbuf_iter$i ./iteration_bench -m flatbuf --iter-mode iterator --loops $2 --strlen $3 --ccts $i "NIT_GC_CHOOSER=large"
	done

	prepare_res iter_buf_index.out iter_buf_index flatbuffer_index
	if $verbose; then
		echo "FlatBuffers by index:"
	fi
	for i in `seq 1 "$1"`; do
		if $verbose; then
			echo "String base length = $1, Concats = $i, Loops = $3"
		fi
		bench_command $i flatbuf_index$i ./iteration_bench -m flatbuf --iter-mode index --loops $2 --strlen $3 --ccts $i "NIT_GC_CHOOSER=large"
	done

	plot iter.gnu
}

function bench_substr()
{
	if $verbose; then
		echo "*** Benching substring performance ***"
	fi

	prepare_res substr_ropes.out substr_ropes ropes
	if $verbose; then
		echo "Ropes :"
	fi
	for i in `seq 1 "$1"`; do
		if $verbose; then
			echo "String length = $i, loops = $2, Loops = $3"
		fi
		bench_command $i ropes$i ./substr_bench -m rope --loops $2 --strlen $3 --ccts $i "NIT_GC_CHOOSER=large"
	done

	prepare_res substr_flat.out substr_flat flatstring
	if $verbose; then
		echo "FlatStrings :"
	fi
	for i in `seq 1 "$1"`; do
		if $verbose; then
			echo "String length = $i, loops = $2, Loops = $3"
		fi
		bench_command $i flatstring$i ./substr_bench -m flatstr --loops $2 --strlen $3 --ccts $i "NIT_GC_CHOOSER=large"
	done

	prepare_res substr_buf.out substr_buf flatbuffer
	if $verbose; then
		echo "FlatBuffers :"
	fi
	for i in `seq 1 "$1"`; do
		if $verbose; then
			echo "String length = $i, loops = $2, Loops = $3"
		fi
		bench_command $i flatbuffer$i ./substr_bench -m flatbuf --loops $2 --strlen $3 --ccts $i "NIT_GC_CHOOSER=large"
	done

	plot substr.gnu
}

stop=false
while [ "$stop" = false ]; do
	case "$1" in
		-v) verbose=true; shift;;
		-h) usage; exit;;
		-n) count="$2"; shift; shift;;
		*) stop=true
	esac
done

if test $# -ne 4; then
	usage
	exit
fi

if $verbose; then
	echo "Compiling"
fi

../bin/nitg --global ./strings/chain_concat.nit --make-flags "CFLAGS=\"-g -O2 -DNOBOEHM\""
../bin/nitg --global ./strings/iteration_bench.nit --make-flags "CFLAGS=\"-g -O2 -DNOBOEHM\""
../bin/nitg --global ./strings/substr_bench.nit --make-flags "CFLAGS=\"-g -O2 -DNOBOEHM\""

case "$1" in
	iter) shift; bench_iteration $@ ;;
	cct) shift; bench_concat $@ ;;
	substr) shift; bench_substr $@ ;;
	all) shift; benches $@ ;;
	*) usage; exit;;
esac
