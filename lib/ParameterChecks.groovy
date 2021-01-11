/*
Copyright (C) 2019-2020 Patrick Hüther

This file is part of ARADEEPOPSIS.
ARADEEPOPSIS is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

ARADEEPOPSIS is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with ARADEEPOPSIS.  If not, see <https://www.gnu.org/licenses/>.
*/

class ParameterChecks {
  static void checkParams(params) {
    assert params.images, "ERROR! Images in png or jpeg format have to be provided!"
    assert params.masks == false || params.masks instanceof String, "ERROR! masks parameter has to be a valid glob pattern to (grayscale) segmentation masks"
    assert params.chunksize instanceof Integer, "ERROR! chunksize parameter has to be an integer!"
    assert params.model in ['A','B','C','DPP'], "ERROR! model parameter must be either A, B, C or DPP!"
    assert params.multiscale instanceof Boolean, "ERROR! multiscale parameter must be set to either false (off) or true (on)"
    assert params.ignore_senescence instanceof Boolean, "ERROR! ignore_senescence parameter must be set to either false (off) or true (on)"
    assert params.save_overlay instanceof Boolean, "ERROR! save_overlay parameter must be set to either false (off) or true (on)"
    assert params.save_mask instanceof Boolean, "ERROR! save_mask parameter must be set to either false (off) or true (on)"
    assert params.save_rosette instanceof Boolean, "ERROR! save_rosette parameter must be set to either false (off) or true (on)"
    assert params.save_hull instanceof Boolean, "ERROR! save_hull parameter must be set to either false (off) or true (on)"
    assert params.polaroid instanceof Boolean, "ERROR! polaroid parameter must be set to either false (off) or true (on)"
    assert params.summary_diagnostics instanceof Boolean, "ERROR! summary_diagnostics parameter must be set to either false (off) or true (on)"
    assert params.shiny instanceof Boolean, "ERROR! shiny parameter must be set to either false (off) or true (on)"
    assert params.ignore_label == false || params.ignore_label in 1..255, "ERROR! ignore_label parameter must either be false or an Integer between 1 and 255"
    assert params.label_spec == false || params.label_spec.contains('='), "ERROR! label_spec parameter must either be false or a quoted(!) comma-separated list of key=value pairs"
    assert params.dpp_checkpoint instanceof String, "ERROR! dpp parameter has to be a valid path containing a pretrained DPP checkpoint"
  }
}