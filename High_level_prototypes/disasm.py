#!/usr/bin/env python3

# Copyright (C) 2020 Mark Jenkins <mark@markjenkins.ca>
# This file is part of stage0.
#
# stage0 is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# stage0 is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with stage0.  If not, see <http://www.gnu.org/licenses/>.

from __future__ import division

from os.path import dirname, join as path_join
from binascii import hexlify, unhexlify
from sys import stdout
from collections import deque
from itertools import count
from string import printable
from argparse import ArgumentParser, FileType

# The following globals, class and function definitions are copy-pasted
# from M1.py in https://github.com/markjenkins/knightpies
#
# Please don't include any other code in this section. See the comment
# marking the section end.
#
# From a code reading perspective, we recommend skipping this section
# and jumping to the real heart and soul of the disassembler
#
# These global variable definitions were copy-pasted from M1.py in
# https://github.com/markjenkins/knightpies
# revision e10fbd920ae4cf7b4b29c60986d0bab9993aef84
#
# This redundancy can be cleaned up once knightpies reaches maturity and is
# merged into the stage0 project
#
# Doing fancy things like a git submodule and manipulating sys.path
# was not considered worth it for this small amount of borrowed code
TOK_TYPE_MACRO, TOK_TYPE_ATOM, TOK_TYPE_STR, TOK_TYPE_DATA, \
    TOK_TYPE_COMMENT, TOK_TYPE_NEWLINE = range(6)
TOK_TYPE, TOK_EXPR, TOK_FILENAME, TOK_LINENUM = range(4)
MACRO_NAME, MACRO_VALUE = 0, 1

# This exception definition was copy-pasted from M1.py in
# https://github.com/markjenkins/knightpies
# revision e10fbd920ae4cf7b4b29c60986d0bab9993aef84
#
# This redundancy can be cleaned up once knightpies reaches maturity and is
# merged into the stage0 project
#
# Doing fancy things like a git submodule and manipulating sys.path
# was not considered worth it for this small amount of borrowed code
class MultipleDefinitionsException(Exception):
    pass

# This function was copy-pasted from M1.py in
# https://github.com/markjenkins/knightpies
# revision e10fbd920ae4cf7b4b29c60986d0bab9993aef84
#
# Python 2.2.0 compatability via COMPAT_TRUE which M1.py
# imports from pythoncompat.py were replaced with the True constant
# available from Python 2.2.1 onward.
#
# This redundancy can be cleaned up once knightpies reaches maturity and is
# merged into the stage0 project
#
# Doing fancy things like a git submodule and manipulating sys.path
# was not considered worth it for this small amount of borrowed code
def read_atom(first_char, f):
    buf = first_char
    while True:
        c = f.read(1)
        if c in ('', "\n", "\t", " "):
            break
        else:
            buf += c
    return buf, c

# This function was copy-pasted from M1.py in
# https://github.com/markjenkins/knightpies
# revision e10fbd920ae4cf7b4b29c60986d0bab9993aef84
#
# Python 2.2.0 compatability via COMPAT_TRUE which M1.py
# imports from pythoncompat.py were replaced with the True constant
# available from Python 2.2.1 onward.
#
# This redundancy can be cleaned up once knightpies reaches maturity and is
# merged into the stage0 project
#
# Doing fancy things like a git submodule and manipulating sys.path
# was not considered worth it for this small amount of borrowed code
def read_until_newline_or_EOF(f):
    comment_buffer = ''
    while True:
        c = f.read(1)
        if c == '' or c=='\n' or c=='\r':
            return c, comment_buffer
        else:
            comment_buffer += c

# This function was copy-pasted from M1.py in
# https://github.com/markjenkins/knightpies
# revision e10fbd920ae4cf7b4b29c60986d0bab9993aef84
#
# Python 2.2.0 compatability via COMPAT_TRUE and COMPAT_FALSE which M1.py
# imports from pythoncompat.py were replaced with True and False constants
# available from Python 2.2.1 onward.
#
# This redundancy can be cleaned up once knightpies reaches maturity and is
# merged into the stage0 project
#
# Doing fancy things like a git submodule and manipulating sys.path
# was not considered worth it for this small amount of borrowed code
def tokenize_file(f):
    line_num = 1
    string_char, string_buf = None, None
    while True:
        c = f.read(1)
        if c=='':
            if string_char != None:
                raise Exception("unmatched %s quote in %s line %s",
                                string_char, f.name, line_num)
            break
        # look for being in string stage first, as these are not
        # interupted by newline or comments
        elif (string_char != None):
            if string_char == c:
                if string_char == '"':
                    yield (TOK_TYPE_STR, string_buf, f.name, line_num)
                elif string_char == "'":
                    yield (TOK_TYPE_DATA, string_buf, f.name, line_num)
                else:
                    assert False # we should never reach here
                string_char, string_buf = None, None
            else:
                string_buf += c
        elif c == '#' or c == ';':
            c, comment = read_until_newline_or_EOF(f)
            yield (TOK_TYPE_COMMENT, comment, f.name, line_num)
            if c!= '':
                yield (TOK_TYPE_NEWLINE, '\n', f.name, line_num)
                line_num+=1
            else:
                break
        elif (string_char == None) and (c == '"' or c == "'"):
            string_char = c
            string_buf  = ''
        elif c == '\n':
            yield (TOK_TYPE_NEWLINE, '\n', f.name, line_num)
            line_num+=1
        elif c == ' ' or c == '\t':
            pass
        else:
            atom, trailing_char = read_atom(c, f)
            yield (TOK_TYPE_ATOM, atom, f.name, line_num)
            if trailing_char == '':
                break
            elif trailing_char == '\n':
                yield (TOK_TYPE_NEWLINE, '\n', f.name, line_num)
                line_num+=1

    yield (TOK_TYPE_NEWLINE, '\n', f.name, line_num)

# This function was copy-pasted from M1.py in
# https://github.com/markjenkins/knightpies
# revision e10fbd920ae4cf7b4b29c60986d0bab9993aef84
#
# Python 2.2.0 compatability via COMPAT_TRUE which M1.py
# imports from pythoncompat.py were replaced with the True constant
# available from Python 2.2.1 onward.
#
# This redundancy can be cleaned up once knightpies reaches maturity and is
# merged into the stage0 project
#
# Doing fancy things like a git submodule and manipulating sys.path
# was not considered worth it for this small amount of borrowed code
def upgrade_token_stream_to_include_macro(input_tokens):
    input_tokens_iter = iter(input_tokens)
    while True:
        try:
            tok = next(input_tokens_iter)
        except StopIteration:
            break

        tok_type, tok_expr, tok_filename, tok_linenum = tok
        # if we have a DEFINE atom we're going to yield a TOK_TYPE_MACRO
        # based on the next two tokens
        if tok_type == TOK_TYPE_ATOM and tok_expr == "DEFINE":
            # look ahead to token after DEFINE
            try:
                macro_name_tok = next(input_tokens_iter)
            except StopIteration:
                raise Exception(
                    "%s ended with uncompleted DEFINE" % tok_filename
                )

            # enforce next token after DEFINE atom must be an atom,
            # not newline or string
            if (macro_name_tok[TOK_TYPE] == TOK_TYPE_STR or
                macro_name_tok[TOK_TYPE] == TOK_TYPE_DATA ):
                raise Exception(
                    "Using a string for macro name %s not supported "
                    "line %s from %s" % (
                        tok_expr, tok_linenum, tok_filename) )
            elif macro_name_tok[TOK_TYPE] == TOK_TYPE_NEWLINE:
                raise Exception(
                    "You can not have a newline in a DEFINE "
                    "line %s from %s" % (
                        tok_expr, tok_linenum, tok_filename) )
            assert macro_name_tok[TOK_TYPE] == TOK_TYPE_ATOM

            # look ahead to second token after DEFINE
            try:
                macro_value_tok = next(input_tokens_iter)
            except StopIteration:
                raise Exception(
                    "%s ended with uncompleted DEFINE" % tok_filename
                )

            # enforce second token after DEFINE atom must be atom or string
            if macro_value_tok[TOK_TYPE] == TOK_TYPE_NEWLINE:
                raise Exception(
                    "You can not have a newline in a DEFINE "
                    "line %s from %s" % (
                        tok_expr, tok_linenum, tok_filename) )

            # make a macro type token which has a two element tuple
            # of name token and value token as the TOK_EXPR component
            yield (
                TOK_TYPE_MACRO,
                (macro_name_tok, macro_value_tok),
                tok_filename, tok_linenum
            )
        # else any atom token that's not DEFINE and two tokens after it
        # or any str or newline token, we just pass it through
        else:
            yield tok

# This function was copy-pasted from M1.py in
# https://github.com/markjenkins/knightpies
# revision e10fbd920ae4cf7b4b29c60986d0bab9993aef84
#
# This redundancy can be cleaned up once knightpies reaches maturity and is
# merged into the stage0 project
#
# Doing fancy things like a git submodule and manipulating sys.path
# was not considered worth it for this small amount of borrowed code
def get_macros_defined_and_add_to_sym_table(f, symbols=None):
    # start a new dictionary if one wasn't provided, putting this in the
    # function definition would cause there to be one dictionary at build time
    if symbols == None:
        symbols = {}

    for tok in upgrade_token_stream_to_include_macro(tokenize_file(f)):
        if tok[TOK_TYPE] == TOK_TYPE_MACRO:
            tok_type, tok_expr, tok_filename, tok_linenum = tok
            macro_name = tok_expr[MACRO_NAME][TOK_EXPR]
            if macro_name in symbols:
                raise MultipleDefinitionsException(
                    "DEFINE %s on line %s of %s is a duplicate definition"
                    % (macro_name, tok_linenum, tok_filename) )
            symbols[macro_name] = tok_expr[MACRO_VALUE]
    return symbols

# END globals, classes, and functions imported from knightpies M1.py

# Everything below is the unique code of disasm.py

V1_STRING_PAD_ALIGN = 4
V2_STRING_PAD_ALIGN = 1
NULL_STRING_PAD_OPTIONS = [V1_STRING_PAD_ALIGN, V2_STRING_PAD_ALIGN]
DEFAULT_STRING_NULL_PAD_ALIGN = V1_STRING_PAD_ALIGN
V2_STRING_BY_DEFAULT = DEFAULT_STRING_NULL_PAD_ALIGN == V2_STRING_PAD_ALIGN

ADDRESS_PRINT_MODE_HEX = "hex"
ADDRESS_PRINT_MODE_NONE = "none"
ADDRESS_PRINT_MODE_OPTIONS = [ADDRESS_PRINT_MODE_HEX, ADDRESS_PRINT_MODE_NONE]
DEFAULT_ADDRESS_PRINT_MODE = ADDRESS_PRINT_MODE_HEX

HEX_MODE_ADDRESS_FORMAT = "%.8X"
OUTPUT_COLUMN_SEPERATOR = "\t"

DEFAULT_MAX_DATA_BYTES_PER_LINE = 4
DEFAULT_MAX_DATA_NYBLES_PER_LINE = DEFAULT_MAX_DATA_BYTES_PER_LINE*2 # 4*2==8
DEFAULT_MAX_STRING_SIZE = 1024*1024*1024*256 # 256 MB

DEFAULT_SUPPRESS_NEWLINE_IN_STRING = False

VT = '\x0B'
FF = '\x0C'
DQ = '"'
PRINTABLE_MINUS_VT_FF_DQ = {
    c
    for c in printable
    if c not in (VT, FF)
    }
NULLCHAR = '\x00'
PRINTABLE_MINUS_VT_FF_DQ_PLUS_NULL = PRINTABLE_MINUS_VT_FF_DQ.union(
    {NULLCHAR} )

NUM_REGISTERS = 16

KNIGHT_REGISTER_SYMBOLS = {
    'R%d' % i: i
    for i in range(NUM_REGISTERS)
    }

(INSTRUCT_NYBLES_AFT_PREFIX,
 INSTRUCT_NUM_REG_OPERANDS,
 INSTRUCT_IMMEDIATE_NYBLE_LEN,
 INSTRUCT_SHARED_PREFIX_LOOKUP,
) = range(4)

INSTRUCTION_STRUCTURE = {
    '01': (2, 4, None), # 4 OP Integer Group
    '05': (3, 3, None), # 3 OP Integer Group
    '09': (4, 2, None), # 2 OP Integer Group
    '0D': (5, 1, None), # 1 OP Group
    'E1': (4, 2, 4),    # 2 OP Immediate Group
    'E0': (5, 1, 4),    # 1 OP Immediate Group
    '3C': (2, 0, 4),    # 0 OP Immediate Group
    '42': (6, 0, None), # HALCODE Group
    '00': (6, 0, None), # 0 OP Group '00' prefix
    'FF': (6, 0, None), # 0 OP Group 'FF' prefix
    }

INSTRUCTION_PREFIX_LEN = 2
if __debug__:
    for key in INSTRUCTION_STRUCTURE.keys():
        assert( len(key) == INSTRUCTION_PREFIX_LEN )

class InvalidInstructionDefinitionException(Exception):
    def __init__(self, instruct_name, instruct_hex, msg):
        Exception.__init__(self,
            "definition for %s, %s %s" % (
                instruct_name, instruct_hex, msg))

class LookaheadBuffer(object):
    def __init__(self, iterator):
        self.__iterator = iterator
        self.__buffer = deque()

        # anyone LookaheadBuffer internal calling next() on self.__iterator
        # is responsible for catching StopIteration and setting this
        # So far this is __next__, grow_buffer, and grow_by_predicate
        self.__hit_end = False

    def hit_end(self):
        """If we hit StopIteration on the underlying iterator.
        But this doesn't mean the buffer is empty, callers should
        check unless it's clear from the context, even then, documenting
        LookaheaddBuffer.__len__()==0 is a good idea
        """
        # anyone LookaheadBuffer internal calling next() on self.__iterator
        # is responsible for catching StopIteration and setting this
        # So far this is __next__, grow_buffer, and grow_by_predicate
        return self.__hit_end

    def grow_buffer(self, n):
        if len(self.__buffer) >= n:
            return True
        else:
            while len(self.__buffer) < n:
                try:
                    self.__buffer.append( next(self.__iterator) )
                except StopIteration:
                    self.__hit_end = True
                    break
            return len(self.__buffer) >= n

    def remove_existing_by_predicate(self, predicate):
        while len(self)>0 and predicate(self.peek()):
            yield next(self)

    def grow_by_predicate(self, predicate, n=None,
                          raise_if_not_clearfirst=True,
                          include_some_current_as_passing=False,
    ):
        """Grow the existing buffer by up to n amount as long as predicate
        is true on the elements. Or leave out n to just rely on the predicate.

        The item that fails the predicate will be the last in the buffer
        if any. (n or the underlying iterable running out could leave you
        with one that passes the predicate)

        Default assumption is you've already cleared the buffer first so that
        everything after this call matches your predicate. For your
        protection raise_if_not_clearfirst defaults to True, meaning
        you'll get an exception if the buffer isn't clear.

        If you're aware of elments already in the buffer and want to
        add more matching your predicate, set raise_if_not_clearfirst=False
        to say you know what you're doing.

        Returns a two element tuple(
            pred_last, # the last bool evaluation of predicate
                       # None if hit_end==True

            i,         # the number of elements added that matched the predicate
                       # 0 <= i <= n
                       # i==n implies hit_end==True or pred_last==True
        )

        You probably also want to check LookaheadBuffer.hit_end()
        as that should mean the predicate passed until the end and the
        last element of the buffer passes the predicate
        (though i < n would also be consistent this this)
        """

        # if we're permitted (include_some_current_as_passing) there might
        # be some predicate passing items already in the buffer
        if len(self)>0 and include_some_current_as_passing:
            for i, elem in enumerate(self):
                # if one of the pre-existing items fails
                # we're done
                if not predicate(elem):
                    return False, i

        # the reason we do is the assumption the caller will normally
        # have dealt with the buffer contents first and would be making
        # a mistake if for some reason clear and would be surprised
        # the front of buffer contents don't match the predicate
        elif raise_if_not_clearfirst and len(self)>0:
            raise Exception(
                "grow_by_predicate called with content in buffer "
                "but raise_if_not_clearfirst flag set"
            )
        # these are only used in assert expressions, do don't
        # worry about them if we're in debug mode where assertions do nothing
        if __debug__:
            def i_n_assertion():
                return 0 <= i <= n
            def i_eq_n_assertion():
                return n!=i or self.hit_end() or pred_last
            def i_n_assertions():
                return i_n_assertion() and i_eq_n_assertion()

        existing_passed_element_count = (
            0 if not include_some_current_as_passing
            else len(self) )

        for i in (count(0) if n==None else range(n)):
            try:
                next_in = next(self.__iterator)
                self.__buffer.append( next_in )
            except StopIteration:
                self.__hit_end  = True
                pred_last = None
                assert i_n_assertions()
                return pred_last, existing_passed_element_count+i

            if not predicate(next_in):
                pred_last = False
                assert i_n_assertions()
                return pred_last, existing_passed_element_count+i
        # only if the loop completes, n been exhausted and the predicate
        # passed on every element
        else:
            i+=1
            assert( i==n )
            pred_last = True
            assert i_n_assertions()
            return pred_last, existing_passed_element_count+i

    def next_n(self, n=1, grow=True, raise_if_too_small=True):
        if grow:
            self.grow_buffer(n)
        elif raise_if_too_small and len(self.__buffer) < n:
            raise Exception(
                "LookaheadBuffer too small, growth not allowed "
                "and error checking enabled")

        # important that we not return an iterator because
        # the user may subsequently call return_iterables_to_front()
        return tuple(
            self.__buffer.popleft()
            for i in range( min(n, len(self.__buffer) ) ) )

    def __iter__(self):
        # important that we make this based on a copy in case the user calls
        # return_iterables_to_front()
        return iter(self.as_tuple())

    def as_tuple(self):
        return tuple(self.__buffer)

    def clear(self, as_iter=False, as_tuple=False):
        if as_iter:
            old_buffer = self.__buffer
            self.__buffer = deque()
            return iter(old_buffer)
        elif as_tuple:
            return_tuple = tuple(self.__buffer)
            self.__buffer.clear()
            return return_tuple
        else:
            self.__buffer.clear()

    def __next__(self):
        # support python's builtin next()
        #
        # raises StopIteration if there is nothing left or a default value
        # if one additional argument is provided
        # checking for len(args) == 1 ensures we add at most one extra
        # argumet to python's builtin next()
        #
        # we do it this way instead of self.__buffer.popleft() to ensure
        # StopIteration is thrown
        #
        # cool fact, callers (who are using builtin next() ) can
        # provide a default value
        try:
            next_val = next(iter(self.next_n(n=1, grow=True)))
        except StopIteration:
            self.__hit_end = True
            raise # re raise same StopIteration
        else:
            return next_val

    def __len__(self):
        return len(self.__buffer)

    def return_iterables_to_front(self, *iters):
        for iterable in reversed(iters):
            self.__buffer.extendleft(reversed(iterable))

    def peek(self):
        if len(self.__buffer)==0:
            raise Exception(
                "peek() called when buffer is empty, you should check len()")
        next_val = next(iter(self.__buffer))
        return next_val

def num_nybles_from_immediate(lookup_struct):
    return (0 if None == lookup_struct[INSTRUCT_IMMEDIATE_NYBLE_LEN]
            else lookup_struct[INSTRUCT_IMMEDIATE_NYBLE_LEN])

def num_nybles_from_register_operands_and_immediate(lookup_struct):
    return (
        lookup_struct[INSTRUCT_NUM_REG_OPERANDS] +
        num_nybles_from_immediate(lookup_struct)
    ) # end addition expression

def get_instruction_opcode_len_after_prefix(lookup_struct):
    return lookup_struct[INSTRUCT_NYBLES_AFT_PREFIX]

def get_instruction_opcode_len(instruct_struct):
    return (
        INSTRUCTION_PREFIX_LEN +
        get_instruction_opcode_len_after_prefix(instruct_struct)
        )

def smallest_instruction_nybles(instruct_struct):
    return min(
        (get_instruction_opcode_len(instructfamily) +
         num_nybles_from_register_operands_and_immediate(instructfamily)
        )
        for prefix, instructfamily in instruct_struct.items() )

def filter_M1_py_symbol_table_to_simple_dict(symbols):
    return {
        macro_name: macro_detailed_definition[TOK_EXPR]
        for macro_name, macro_detailed_definition in symbols.items()
    }

def filter_unwanted_symbols(symbols, unwanted):
    return {
        key: value
        for key, value in symbols.items()
        if key not in unwanted
        }

def get_macro_definitions_from_file(definitions_file):
    with open(definitions_file) as f:
        symbols = get_macros_defined_and_add_to_sym_table(f)
    return filter_M1_py_symbol_table_to_simple_dict(symbols)

def get_knight_instruction_definititions_from_file(definitions_file):
    filtered_symbols = filter_unwanted_symbols(
        get_macro_definitions_from_file(definitions_file),
        set( (tuple(KNIGHT_REGISTER_SYMBOLS.keys()) + ('NULL',)) )
        )
    return {
        key: value.upper() # ensure instruction definitions are upper case hex
        for key, value in filtered_symbols.items()
        }

def remove_prefix_from_instruct_hex(instruct_hex):
    return instruct_hex[INSTRUCTION_PREFIX_LEN:]

def expand_instruct_struct_define_if_valid(
        prefix,
        instruct_struct_define,
        pairs_for_this_prefix):
    # validity check, nybles after prefix must be the right length
    for instruct_hex, instruct_name in pairs_for_this_prefix:
        instruct_hex_after_prefix = \
            remove_prefix_from_instruct_hex(instruct_hex)
        nybles_after_prefix = instruct_struct_define[
            INSTRUCT_NYBLES_AFT_PREFIX]
        if len(instruct_hex_after_prefix) != nybles_after_prefix:
            raise InvalidInstructionDefinitionException(
                instruct_name, instruct_hex,
                "does not have %d nybles after prefix (%s) had %d" % (
                    nybles_after_prefix,
                    instruct_hex_after_prefix,
                    len(instruct_hex_after_prefix))
                )
    return ( # start of tuple appending expression
        instruct_struct_define + # tuple appending operator
        ( # start of singleton tuple
            {
                remove_prefix_from_instruct_hex(instruct_hex):
                instruct_name
                for instruct_hex, instruct_name in pairs_for_this_prefix
            }
            ,) # end singleton tuple
    ) # end tuple appending expression

def get_knight_instruction_structure_from_file(
        definitions_file, strict_size_assert=False):
    symbols = get_knight_instruction_definititions_from_file(definitions_file)
    for symname, symvalue in symbols.items():
        if symvalue[0:INSTRUCTION_PREFIX_LEN] not in INSTRUCTION_STRUCTURE:
            raise InvalidInstructionDefinitionException(
                symname, symvalue, "has unknown prefix")

    instruction_pairs_per_prefix = {
        prefix: [
            (symvalue, symname)
            for symname, symvalue in symbols.items()
            if symvalue.startswith(prefix)
        ] # list comprehension
        for prefix in INSTRUCTION_STRUCTURE.keys()
        }

    finished_instruction_struct = {
        prefix:
        expand_instruct_struct_define_if_valid(
            prefix,
            instruct_struct_define,
            instruction_pairs_per_prefix[prefix]
        ) # expand_instruct_struct_define_if_valid
        for prefix, instruct_struct_define in INSTRUCTION_STRUCTURE.items()
        }
    if strict_size_assert:
        assert(
            smallest_instruction_nybles(finished_instruction_struct) ==
            max( len(x) for x in symbols.values()) )
    else:
        assert(
            smallest_instruction_nybles(finished_instruction_struct) <=
            max( len(x) for x in symbols.values()) )

    return finished_instruction_struct

NY_NUM_ANNO = 5
(NY_ANNO_IS_DATA, NY_ANNO_ADDRESS,
 NY_ANNO_FIRST_NYBLE, NY_ANNO_IS_PAIR, NY_ANNO_HEX )= range(NY_NUM_ANNO)

EMPTY_NY_ANNO_IS_PAIR = ()

def construct_annotation(*args):
    assert len(args)==NY_NUM_ANNO
    return tuple(args)

def annotate_nyble_as_not_data(nyble_annotations):
    return (nyble_annotations[0:NY_ANNO_IS_DATA] +
            (False, ) + # NY_ANNO_IS_DATA
            nyble_annotations[NY_ANNO_IS_DATA+1:] )

def annotate_nyble_as_data(nyble_annotations):
    return (nyble_annotations[0:NY_ANNO_IS_DATA] +
            (True, ) + # NY_ANNO_IS_DATA
            nyble_annotations[NY_ANNO_IS_DATA+1:] )

def multiple_annotated_nybles_as_data(annotated_nybles):
    return (
        (x, annotate_nyble_as_data(y))
        for x,y in annotated_nybles
        )

def annotated_nyble_is_data(ny_annotated):
    nyble, annotations = ny_annotated
    return annotations[NY_ANNO_IS_DATA]

# this is a helper called by replace_instructions_in_hex_nyble_stream
# all asserts assume that context
def construct_annotated_instruction(
        instruction_structure,
        instruction_prefix,
        remainder_of_opcode_hex,
        operand_nybles_annotated,
        first_nyble_annotations,
):

    assert( instruction_prefix in instruction_structure )
    instruct_table = instruction_structure[instruction_prefix]

    remainder_opcode_table = instruct_table[INSTRUCT_SHARED_PREFIX_LOOKUP]
    assert(  remainder_of_opcode_hex in remainder_opcode_table )
    opcode_name = remainder_opcode_table[remainder_of_opcode_hex]
    opcode_fullhex = instruction_prefix + remainder_of_opcode_hex# string append

    immediate_len = num_nybles_from_immediate(instruct_table)
    if immediate_len>0:
        # negatives in python slices allow for getting last n
        # so first example here gets last n
        # and second example here is everything up to last n
        immediate_nybles = operand_nybles_annotated[-immediate_len:]
        immediate_nybles_string = ''.join(
            immediate_hex_nyble
            for immediate_hex_nyble, immediate_annotation in immediate_nybles)
        immediate_string_hex = immediate_nybles_string
        immediate_unsigned_value = int(immediate_nybles_string, 16)
        immediate_string = "0x%.4X" % immediate_unsigned_value
        reg_operand_nybles = operand_nybles_annotated[:-immediate_len]
    else:
        immediate_nybles = ()
        immediate_string_hex = ''
        immediate_unsigned_value = None
        immediate_string = ''
        reg_operand_nybles = operand_nybles_annotated

    register_operands_string = ' '.join(
        "R%d" % int(operand_in_hex,16)
        for operand_in_hex, operand_annotations in reg_operand_nybles
        )

    operands_in_hex = ''.join(
        operand_in_hex
        for operand_in_hex, operand_annotations in reg_operand_nybles
        )

    full_instruction_string = (# start expression for string
        "%s %s %s" % (opcode_name, register_operands_string, immediate_string)
    ).strip() # strip() covers case of immediate_string==''

    return (full_instruction_string,
            construct_annotation(
                False, # NY_ANNO_IS_DATA, it's not data its an instruction!
                first_nyble_annotations[NY_ANNO_ADDRESS], # NY_ANNO_ADDRESS
                True, # NY_ANNO_FIRST_NYBLE, instructions start on byte boundary
                EMPTY_NY_ANNO_IS_PAIR, # NY_ANNO_IS_PAIR
                opcode_fullhex + operands_in_hex +
                immediate_string_hex, # NY_ANNO_HEX
            )
    )

def replace_instructions_in_hex_nyble_stream(
        hex_nyble_stream, instruction_structure, ignore_NOP=False):
    # any annotated nybles we pull from hex_nyble_stream might get
    # tossed into this lookahead buffer [first in first out /FIFO with
    # append() and popleft() ] if it turns out that oops, they were not what
    # we thought they were
    lookahead_buffer = LookaheadBuffer(hex_nyble_stream)

    minimal_instruction_size = smallest_instruction_nybles(
        instruction_structure)
    assert( INSTRUCTION_PREFIX_LEN < minimal_instruction_size )

    while True:
        if not lookahead_buffer.grow_buffer(minimal_instruction_size):
            assert( len(lookahead_buffer) < minimal_instruction_size )
            yield from multiple_annotated_nybles_as_data(
                lookahead_buffer.clear(as_iter=True))
            break

        prefix_nybles_w_annotations = lookahead_buffer.next_n(
            INSTRUCTION_PREFIX_LEN, grow=False)

        # if any of the prefix nybles are marked as data, they're both
        # treated as data
        if any( ny_annotations[NY_ANNO_IS_DATA]
                for nydata, ny_annotations in prefix_nybles_w_annotations ):
            yield from multiple_annotated_nybles_as_data(
                prefix_nybles_w_annotations)
        else:
            instruction_prefix = \
                ''.join(
                    nyble
                    for nyble, nyble_annotations in prefix_nybles_w_annotations
                ).upper()
            if instruction_prefix not in instruction_structure:
                yield from multiple_annotated_nybles_as_data(
                    prefix_nybles_w_annotations)
            else:
                instruction_struc_table = instruction_structure[
                    instruction_prefix]

                rest_of_opcode_len = get_instruction_opcode_len_after_prefix(
                    instruction_struc_table)
                operand_len = num_nybles_from_register_operands_and_immediate(
                    instruction_struc_table)

                result = lookahead_buffer.grow_buffer(
                    rest_of_opcode_len + operand_len)

                # if we hit end of file, we treat the two nyble prefix
                # as data we'll go back to the top of the while loop
                # the nybles still available will be in lookahead_buffer
                if not result:
                    yield from multiple_annotated_nybles_as_data(
                        prefix_nybles_w_annotations)
                else:
                    rest_of_opcode_nybles = lookahead_buffer.next_n(
                        rest_of_opcode_len, grow=False)

                    rest_of_opcode_nybles_hex = ''.join(
                        content
                        for content, additional_nyble_annotations in
                        rest_of_opcode_nybles
                        ).upper()
                    remaining_nybles_lookup_table = instruction_struc_table[
                        INSTRUCT_SHARED_PREFIX_LOOKUP]
                    # if the rest of the opcode isn't recognizable
                    if (rest_of_opcode_nybles_hex not in
                        remaining_nybles_lookup_table):
                        # treat the prefix as data
                        yield from multiple_annotated_nybles_as_data(
                            prefix_nybles_w_annotations)
                        # put the rest of opcode nybles back into the
                        # front of our lookahead buffer to be consumed by
                        # next iteration of while True
                        lookahead_buffer.return_iterables_to_front(
                            rest_of_opcode_nybles)
                    else:
                        # no need to grow the buffer to match this read
                        # or to check operand_len nybles are available as we
                        # already did a grow_buffer operation with
                        # both the remainder of opcode length + operand length
                        # and we checked the result
                        operand_nybles_consumed = lookahead_buffer.next_n(
                            operand_len, grow=False)
                        annotated_instruction = construct_annotated_instruction(
                            instruction_structure,
                            instruction_prefix,
                            rest_of_opcode_nybles_hex,
                            operand_nybles_consumed,
                            first_nyble_annotations =
                              prefix_nybles_w_annotations[0][1] )
                        if annotated_instruction[0] == "NOP" and ignore_NOP:
                            yield from multiple_annotated_nybles_as_data(
                                prefix_nybles_w_annotations)
                            yield from multiple_annotated_nybles_as_data(
                                rest_of_opcode_nybles)
                        else:
                            yield annotated_instruction

def enhance_annotations_to_include_sub_annotations_from_pair(
        ny_annotations, sub_annotations):
    return ( ny_annotations[0:NY_ANNO_IS_PAIR] +
             # NY_ANNO_IS_PAIR, will be True in bool() context
             (sub_annotations,) +
             ny_annotations[NY_ANNO_IS_PAIR+1:]
    ) # end tuple addition expression

def make_nyble_pair(annotated_nyble1, annotated_nyble2):
    return (
        (annotated_nyble1[0], annotated_nyble2[0]),
        enhance_annotations_to_include_sub_annotations_from_pair(
            annotated_nyble1[1], annotated_nyble2[1])
    ) # tuple

def all_nyble_pairs_in_iterable(nyble_pair_stream):
    return all(is_nyble_pair(entry)
               for entry in nyble_pair_stream)

def is_nyble_pair(nyble_pair):
    return (isinstance(nyble_pair[0], tuple) and
            nyble_pair[1][NY_ANNO_IS_PAIR])

def make_nyble_data_pair_stream(nyble_data_stream):
    lookahead_buffer = LookaheadBuffer(nyble_data_stream)
    while len(lookahead_buffer)>0 or not lookahead_buffer.hit_end():
        if lookahead_buffer.grow_buffer(2): # 2 nybles per byte
            annotated_nybles = lookahead_buffer.next_n(2,grow=False)
            #( (nyble1, nyble1_annotations),
            #  (nyble2, nyble2_annotations)  ) = annotated_nybles
            if all( annotated_nyble_is_data(an_ny)
                    for an_ny in annotated_nybles ):
                assert len(annotated_nybles) == 2
                yield make_nyble_pair(*annotated_nybles)
            else:
                # the only reason we wouldn't have two data nybles together
                # would be something not data comes first
                # in which case we can yield the first thing and
                # put the rest back for the next pass to work with
                assert not annotated_nyble_is_data(annotated_nybles[0])
                yield annotated_nybles[0]
                lookahead_buffer.return_iterables_to_front(
                            annotated_nybles[1:] )
        else:
            yield from lookahead_buffer.clear(as_iter=True)
            break # redundant, while invariant has us covered

def is_nyble_data_pair(nyble_pair):
    result = is_nyble_pair(nyble_pair)
    pair, annotations = nyble_pair
    assert (not annotations[NY_ANNO_IS_PAIR] or
            annotations[NY_ANNO_IS_PAIR][NY_ANNO_IS_DATA])
    assert not result or bool(annotations[NY_ANNO_IS_PAIR])
    assert not result or len(nyble_pair[0])==2
    return result

def expand_nyble_pair_back_to_two_nybles(nyble_pair):
    assert nyble_pair[1][NY_ANNO_IS_PAIR]
    ( (nyble1, nyble2), annotations ) = nyble_pair
    annotations2 = annotations[NY_ANNO_IS_PAIR]
    annotations1 = (
        annotations[0:NY_ANNO_IS_PAIR] +
        ( (), ) + # NY_ANNO_IS_PAIR
        annotations[NY_ANNO_IS_PAIR+1:]
    )
    return ( (nyble1, annotations1), (nyble2, annotations2) )

def make_nyble_stream_from_pair_stream(nyble_pair_stream):
    for nyble_pair in nyble_pair_stream:
        if is_nyble_data_pair(nyble_pair):
            yield from expand_nyble_pair_back_to_two_nybles(nyble_pair)
        else:
            yield nyble_pair

def ascii_string_char_from_two_nybles(
        nyble1, nyble2, lookset=PRINTABLE_MINUS_VT_FF_DQ):
    return unhexlify(nyble1+nyble2).decode('ascii')

def two_nybles_are_ascii_string_char_in_set(
        nyble1, nyble2, lookset):
    return ascii_string_char_from_two_nybles(nyble1, nyble2) in lookset

def two_nybles_are_ascii_string_char(nyble1, nyble2,
                                     lookset=PRINTABLE_MINUS_VT_FF_DQ):
    return two_nybles_are_ascii_string_char_in_set(nyble1, nyble2, lookset)

def two_nybles_are_ascii_string_char_or_null(nyble1, nyble2):
    return two_nybles_are_ascii_string_char_in_set(
        nyble1, nyble2,
        lookset=PRINTABLE_MINUS_VT_FF_DQ_PLUS_NULL)

def nyble_pairs_are_printable_ascii_data(
        annotated_nyble_or_nybles,
        test_func=two_nybles_are_ascii_string_char):
    if not is_nyble_data_pair(annotated_nyble_or_nybles):
        return False

    ( (nyble1, nyble1_annotations),
      (nyble2, nyble2_annotations), ) = expand_nyble_pair_back_to_two_nybles(
          annotated_nyble_or_nybles)
    try:
        return test_func(nyble1, nyble2)
    except UnicodeDecodeError:
        return False

def nyble_pairs_are_printable_ascii_data_or_null(
        annotated_nyble_or_nybles,
        test_func=two_nybles_are_ascii_string_char_or_null,
        ):
    return nyble_pairs_are_printable_ascii_data(
        annotated_nyble_or_nybles,
        test_func=two_nybles_are_ascii_string_char_or_null
        )

def nyble_pairs_are_not_printable_ascii_data(annotated_nyble_or_nybles):
    return not nyble_pairs_are_printable_ascii_data(annotated_nyble_or_nybles)

def nullpads_for_v1_string(num_printable):
    string_len_w_null = num_printable+1
    # modular arithmatic can tell us how much longer than the alignment
    alignment_exceeded_by = string_len_w_null % V1_STRING_PAD_ALIGN
    # subtraction tells us how many nulls to hit the alignment
    additional_nulls_required = V1_STRING_PAD_ALIGN - alignment_exceeded_by
    # modular arithmatic
    extra_padding = \
        additional_nulls_required % V1_STRING_PAD_ALIGN
    assert( 0<= extra_padding < V1_STRING_PAD_ALIGN )
    return 1 + extra_padding

def make_pair_stream_with_only_printable_and_null(pair_stream):
    for nyble_pair in pair_stream:
        if is_nyble_data_pair(nyble_pair):
            if not nyble_pairs_are_printable_ascii_data_or_null(nyble_pair):
                yield from expand_nyble_pair_back_to_two_nybles(nyble_pair)
            else:
                yield nyble_pair
        else:
            yield nyble_pair

def two_nybles_are_null(nyble1, nyble2):
    return nyble1=='0' and nyble2=='0'

def replace_strings_in_hex_nyble_stream(
        nyble_pair_stream, v2_strings=V2_STRING_BY_DEFAULT,
        max_string_size=DEFAULT_MAX_STRING_SIZE,
):
    lookahead_buffer = LookaheadBuffer(nyble_pair_stream)

    while len(lookahead_buffer)>0 or not lookahead_buffer.hit_end():
        # normally the buffer is empty but hit_end() False
        # there might be something in the buffer if the previous
        # pass tried to identify a string and it found inappropriate
        # something other than nulls after the accepted printable
        # characters came to an end
        # those remaining characters might be useful
        # but we'll remove any at the front that are not
        if ( len(lookahead_buffer)>0 and
             any(nyble_pairs_are_not_printable_ascii_data(elem)
                 for elem in lookahead_buffer) ):
            yield from tuple(
                lookahead_buffer.remove_existing_by_predicate(
                    nyble_pairs_are_not_printable_ascii_data)
            )

        pred_last, num_printable = lookahead_buffer.grow_by_predicate(
            nyble_pairs_are_printable_ascii_data,
            n=max_string_size,
            include_some_current_as_passing=len(lookahead_buffer)>0,
        )
        if num_printable == 0:
            if lookahead_buffer.hit_end():
                break
        # if the predicate passed on the last character, that's a problem
        # as we're looking for a terminating null
        elif pred_last:
            assert all_nyble_pairs_in_iterable(lookahead_buffer)
            yield from lookahead_buffer.clear(as_iter=True)
            # redundant as while loop has this covered
            if lookahead_buffer.hit_end():
                break
        # else (num_printable > 0 and pred_last is False
        #       and not lookahead_buffer.hit_end() )
        #       or
        #      (pred_last is None and lookahead_buffer.hit_end() )
        else:
            # we were stopped by the predicate, so we were not stopped
            # by exhausing the iterator
            #
            # or we were stopped by exhausting the iterator
            # (in which case we'll process what we found and go back to the
            #  top of the loop)
            assert ( (pred_last is False and not lookahead_buffer.hit_end())
                     or
                     (pred_last is None and lookahead_buffer.hit_end()) )

            chars_and_first_null = lookahead_buffer.clear(as_tuple=True)
            chars_no_null = chars_and_first_null[:-1]
            assert all_nyble_pairs_in_iterable(chars_no_null)

            num_nulls_to_terminate = (
                1 if v2_strings
                else nullpads_for_v1_string(num_printable)
            )
            num_additional_nulls = num_nulls_to_terminate-1

            if num_additional_nulls>0:
                assert not v2_strings
                additional_nulls = lookahead_buffer.next_n(
                    num_additional_nulls,
                    grow=True)
                assert len(lookahead_buffer)==0
            else:
                additional_nulls = ()

            all_nulls = (chars_and_first_null[-1],)+additional_nulls

            all_expected_nulls_as_they_should_be = all(
                is_nyble_pair(candidate_null) and
                two_nybles_are_null(*candidate_null[0])
                for candidate_null in all_nulls
            ) # all

            # if the expected nulls really are null char nyble pairs and
            # and there is enough of them to be
            # enough padding then we can construct the string and return it
            if (all_expected_nulls_as_they_should_be and
                len(all_nulls)==num_nulls_to_terminate):
                concat_string = '"%s"' % ''.join(
                    ascii_string_char_from_two_nybles( *nyble_char_pair)
                    for nyble_char_pair, annotations in chars_no_null
                    )
                yield ( concat_string,
                        annotate_nyble_as_not_data( chars_no_null[0][1] )
                ) # tuple expression

            # if something is wrong dump the bytes we hoped were
            # a string back out,
            # but, the bytes the we hoped were terminating and padding
            # null bytes we put back in the LookaheadBuffer so they
            # can be themselves inspected in the next pass through
            # the while loop as the start of a string
            else:
                yield from chars_no_null
                # the first candidate null isn't a printable character
                # as that would have failed the predicate check,
                # so we throw that back to the stream as hex nyble data as well
                first_non_printing = chars_and_first_null[-1]
                yield first_non_printing

                # but any other candidate nulls need to go back into the buffer
                # as they could very well be the start of printable chars with
                # appropriate null padding following
                assert not v2_strings or len(additional_nulls)==0
                lookahead_buffer.return_iterables_to_front(
                    additional_nulls)

                # from here return to top of while, even if
                # lookahead_buffer.hit_end() the few bytes we returned
                # to the front of the buffer could constitute a string!

def consolidate_data_into_chunks_in_hex_nyble_stream(
        hex_nyble_stream, n=DEFAULT_MAX_DATA_NYBLES_PER_LINE):
    if (n % 2)!=0:
        raise Exception(
            "consolidate_data_into_chunks_in_hex_nyble_stream can only do it "
            "in multiples of 2, e.g. two nybles per byte")

    lookahead_buffer = LookaheadBuffer(hex_nyble_stream)

    MAX_DATA_NYBLES_PER_LINE = n

    while len(lookahead_buffer)>0 or not lookahead_buffer.hit_end():
        # anything left over in the lookahead buffer is not data
        # because we didn't handle below after calling grow_by_predicate
        if len(lookahead_buffer)>0:
            assert( len(lookahead_buffer) == 1 ) # no reason for many
            # next item in buffer is some kind of
            # assembler plain text instead of data.
            # pass it through
            yield next(lookahead_buffer)
            assert( len(lookahead_buffer) == 0 )
            continue

        pred_last, num_data = lookahead_buffer.grow_by_predicate(
            annotated_nyble_is_data,
            MAX_DATA_NYBLES_PER_LINE)
        if num_data > 0: # if we found some data
            first_data_nyble_annotated = lookahead_buffer.peek()
            first_data_nyble, first_data_nyble_annotations = \
                first_data_nyble_annotated

            # if the first nyble isn't the first nyble in a pair of nybles from
            # an original byte, something is horibly wrong
            assert first_data_nyble_annotations[NY_ANNO_FIRST_NYBLE]

            # put it in single quotes as one chunk
            nyble_chunk_str = "'%s'" % ''.join( # no characters between data
                    nyble
                    for nyble, annotations in lookahead_buffer.next_n(
                            num_data, grow=False)
            ) # join

            # if the number of nybles isn't even in the final product,
            # something is horibly wrong
            # note, the incusion of two single quotes in the string
            # format above doesn't change this
            assert len(nyble_chunk_str) % 2 == 0

            yield (nyble_chunk_str, first_data_nyble_annotations)
            # hitting the end means we didn't stop because the predicate
            # failed, it means we ran out of data at the end of the file
            if lookahead_buffer.hit_end():
                assert num_data < MAX_DATA_NYBLES_PER_LINE
                assert pred_last==None
                break # technically the while loop variant has this covered
            else:
                # if we didn't hit the end, either we loaded enough
                # data or the predicate stopped us, either way, go back
                # to the top of the while loop to process more
                assert ( num_data==MAX_DATA_NYBLES_PER_LINE or
                         ( not pred_last and len(lookahead_buffer)==1 )
                ) # assert expression
                continue # redundant, we're headed back to top of while loop

        # num_data must be 0
        #
        # if we also hit the end it means we're at end of file,
        # because that means grow_by_predicate wasn't stopped by the
        # predicate
        elif lookahead_buffer.hit_end():
            assert num_data==0 # implied by num_data > 0 testing failing
            assert len(lookahead_buffer)==0
            break # redundant because the while loop invarient covers this
        # but if we're not at the end
        elif not pred_last:
            assert len(lookahead_buffer)==1
            # we'll handle the one item at the top of the loop

def binary_to_annotated_hex(binary_fileobj):
    # nyble is int when iterating over bytes from hexlify, hence chr(nyble)
    for i, nyble in enumerate(hexlify(binary_fileobj.read())):
        yield (chr(nyble).upper(),
               construct_annotation(
                   False,    # NY_ANNO_IS_DATA
                   i//2,     # NY_ANNO_ADDRESS
                   (i%2==0), # NY_ANNO_FIRST_NYBLE
                   EMPTY_NY_ANNO_IS_PAIR, # NY_ANNO_IS_PAIR
                   chr(nyble).upper(), # NY_ANNO_HEX
               ) # construct_annotation
        ) # outer tuple

NEWLINE_TAB_SUPRESS_HEX_FORMAT = "0x%.1X "
def format_string_content_suppress_newline_tab(output_string):
    return output_string.replace(
        "\n", NEWLINE_TAB_SUPRESS_HEX_FORMAT % ord("\n")).replace(
            "\t", NEWLINE_TAB_SUPRESS_HEX_FORMAT % ord("\t") )

def format_not_at_all(string_to_not_format):
    return string_to_not_format

def dissassemble_knight_binary(
        binary_fileobj,
        output_fileobj,
        definitions_file=None,
        string_discovery=True,
        string_null_pad_align=DEFAULT_STRING_NULL_PAD_ALIGN,
        address_printing=DEFAULT_ADDRESS_PRINT_MODE,
        max_data_bytes_per_line=DEFAULT_MAX_DATA_BYTES_PER_LINE,
        suppress_newline_tab_in_string=DEFAULT_SUPPRESS_NEWLINE_IN_STRING,
        ):
    prioritize_mod_4_string_w_4_null_over_nop = \
        string_null_pad_align==V1_STRING_PAD_ALIGN

    string_formatter = (
        format_string_content_suppress_newline_tab
        if suppress_newline_tab_in_string else format_not_at_all
        )

    builtin_definitions = definitions_file==None

    if builtin_definitions:
        definitions_file = get_stage0_knight_defs_filename()
    instruction_structure = get_knight_instruction_structure_from_file(
        definitions_file, strict_size_assert=builtin_definitions)

    # we know the smallest
    if builtin_definitions:
        assert( 8 == smallest_instruction_nybles(instruction_structure))

    nyble_stream = binary_to_annotated_hex(binary_fileobj)

    after_instruction_replacement_stream = \
        replace_instructions_in_hex_nyble_stream(
            nyble_stream,
            instruction_structure,
            ignore_NOP=prioritize_mod_4_string_w_4_null_over_nop,
        ) # replace_instructions_in_hex_nyble_stream

    if string_discovery:
        pair_stream = make_nyble_data_pair_stream(
            after_instruction_replacement_stream)

        printable_plus_null_pair_stream = \
            make_pair_stream_with_only_printable_and_null(pair_stream)

        w_string_pair_stream = replace_strings_in_hex_nyble_stream(
            printable_plus_null_pair_stream,
            v2_strings=string_null_pad_align==V2_STRING_PAD_ALIGN
        )
        after_string_detection_stream = make_nyble_stream_from_pair_stream(
            w_string_pair_stream)
    else:
        after_string_detection_stream = after_instruction_replacement_stream

    # whenever we're doing version 1 strings that are null padded to a multiple
    # of 4 bytes there very well may be four null bytes found as
    # 0x00000000 after a string
    #
    # this is also the NOP opcode so the fact that we search for instructions
    # first can be a problem
    #
    # as such any time version 1 strings are being processed
    # prioritize_mod_4_string_w_4_null_over_nop is true and we ignore
    # NOP on the first instruction pass and restore it later if not absorbed
    # into a string
    #
    # at this point in the code we've already done instruction detection
    # and string detection and we're setting max_data_nybles_per_line,
    # a paramater for the printing of data (not code, not strings)
    #
    # the way we restore NOPs that were not absorbed into strings isn't
    # particularly elegant, it's done below after data is clustered
    # into line sized chunks, as such the paramater for that
    # max_data_nybles_per_line has to be 8 nybles (4 bytes)
    if prioritize_mod_4_string_w_4_null_over_nop:
        max_data_nybles_per_line = 8
    # but, if we're not worried about NOP being substituted, as would be
    # be the case if string_null_pad_align==V2_STRING_PAD_ALIGN
    # (and prioritize_mod_4_string_w_4_null_over_nop==False)
    # then our data bytes per line becomes a user-provided paramater
    else:
        max_data_nybles_per_line = max_data_bytes_per_line*2

    final_stream = consolidate_data_into_chunks_in_hex_nyble_stream(
        after_string_detection_stream,
        n=max_data_nybles_per_line)

    for content, annotations in final_stream:
        is_string = content[0] == '"'

        if address_printing==ADDRESS_PRINT_MODE_HEX:
            output_fileobj.write(
                HEX_MODE_ADDRESS_FORMAT % annotations[NY_ANNO_ADDRESS])
            output_fileobj.write(OUTPUT_COLUMN_SEPERATOR)

        if prioritize_mod_4_string_w_4_null_over_nop and content=="'00000000'":
            output_fileobj.write("NOP")
        elif is_string:
            output_fileobj.write(string_formatter(content))
        else:
            output_fileobj.write(content)

        output_fileobj.write(OUTPUT_COLUMN_SEPERATOR)
        output_fileobj.write('#')
        if is_string:
            output_fileobj.write("STRING")
        elif annotations[NY_ANNO_IS_DATA]:
            output_fileobj.write("DATA")
        else: # is code
            output_fileobj.write(" ")
            output_fileobj.write(annotations[NY_ANNO_HEX])
        output_fileobj.write("\n")

def get_stage0_knight_defs_filename():
    return path_join(dirname(__file__), 'defs')

def run_test_suite():
    from io import BytesIO, StringIO
    inputfilebytes = BytesIO()
    inputfilebytes.write(b'00000000  ff ff                                             |..|\n00000002\n')
    inputfilebytes.seek(0)
    dissassemble_knight_binary(
        inputfilebytes, StringIO(),
    )
    inputfilebytes.close()

if __name__ == "__main__":
    argparser = ArgumentParser()

    argparser.add_argument(
        "-p", "--string-null-pad-align",
        type=int, choices=NULL_STRING_PAD_OPTIONS,
        default=DEFAULT_STRING_NULL_PAD_ALIGN,
        help="4 to use null padding to align strings to a multiple of 4 bytes "
        "as was the case in the original v1 knight binary format or 1 to "
        "only have one null at the end of strings, the v2 knight binary format"
    )

    argparser.add_argument(
        "-a", "--address-mode", type=str,
        default=DEFAULT_ADDRESS_PRINT_MODE, choices=ADDRESS_PRINT_MODE_OPTIONS,
        help="hex for addresses to be printed as a first column in hex "
        "none to not print an address column"
        )

    argparser.add_argument(
        "-D", "--definitions-file", type=str,
        #default=None,  # this is implicit
        help="A file with the assembler definitions, by default this is "
        "High_level_prototypes/defs"
        )

    argparser.add_argument(
        "--disable-string", dest="enable_string", action="store_false",
        help="disable string detection"
        )
    argparser.add_argument(
        "--enable-string", dest="enable_string", action="store_true",
        default=True,
        help="opposite of --disable-string, enable string detection. "
        "String detection is on by default, so you only need this if you "
        "need to be really explicit somewhere"
        )

    argparser.add_argument(
        "--max-data-bytes-per-line", type=int,
        default=DEFAULT_MAX_DATA_BYTES_PER_LINE,
        help="Anything that's not code or string is data, this sets how"
        "many bytes of data are printed at most per line (default 4). "
        "Due to a kludge, only useful when --string-null-pad-align 1"
        )

    argparser.add_argument(
        "--suppress-newline-tab-in-string",
        default=DEFAULT_SUPPRESS_NEWLINE_IN_STRING, action="store_true",
        help="For the Knight.py cherrypy debugger, don't break up newlines"
        )

    argparser.add_argument(
        "--run-test-suite",
        default=False, action="store_true"
    )

    argparser.add_argument(
        "inputfile", help="file to disassemble",
        type=FileType("rb")
    )

    args = argparser.parse_args()

    if args.run_test_suite:
        test_suite_result = run_test_suite()
        exit(test_suite_result)

    # safety check on args.max_data_bytes_per_line to ensure the value
    # used is > 0
    max_data_bytes_per_line = max(1, args.max_data_bytes_per_line)

    dissassemble_knight_binary(
        args.inputfile, stdout,
        definitions_file=args.definitions_file,
        string_discovery=args.enable_string,
        string_null_pad_align=args.string_null_pad_align,
        address_printing=args.address_mode,
        max_data_bytes_per_line=max_data_bytes_per_line,
        suppress_newline_tab_in_string=args.suppress_newline_tab_in_string,
    )
    args.inputfile.close()
