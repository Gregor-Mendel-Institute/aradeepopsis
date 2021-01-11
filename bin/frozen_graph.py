#!/usr/bin/env python

# Copyright (C) 2019-2020 Patrick Hüther
#
# This file is part of ARADEEPOPSIS.
# ARADEEPOPSIS is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# ARADEEPOPSIS is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with ARADEEPOPSIS.  If not, see <https://www.gnu.org/licenses/>.
# ======================================================================
# Portions of this code are modifications based on work created and
# shared by Google and used according to terms described in the
# Apache 2.0 License.

import tensorflow as tf

# from https://www.tensorflow.org/guide/migrate#a_graphpb_or_graphpbtxt
def wrap_frozen_graph(graph_def, inputs, outputs):
  def _imports_graph_def():
    tf.compat.v1.import_graph_def(graph_def,name="")


  wrapped_import = tf.compat.v1.wrap_function(_imports_graph_def, [])
  import_graph = wrapped_import.graph
  return wrapped_import.prune(
      tf.nest.map_structure(import_graph.as_graph_element, inputs),
      tf.nest.map_structure(import_graph.as_graph_element, outputs))