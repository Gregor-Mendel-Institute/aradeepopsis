/*
Copyright (C) 2019-2020 Patrick Hüther

This file is part of araDeepopsis.
araDeepopsis free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

araDeepopsis is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with araDeepopsis.  If not, see <https://www.gnu.org/licenses/>.
*/

class ParameterChecks {
  static void checkParams(params) {
    assert params.images, "ERROR! Images in png or jpeg format have to be provided!"
    assert params.chunksize instanceof Integer, "ERROR! chunksize parameter has to be an integer!"
    assert params.model in ['A','B','C'], "ERROR! model parameter must be either A, B or C!"
    assert params.multiscale instanceof Boolean, "ERROR! multiscale parameter must be set to either false (off) or true (on)"
    assert params.ignore_senescence instanceof Boolean, "ERROR! ignore_senescence parameter must be set to either false (off) or true (on)"
    assert params.save_overlay instanceof Boolean, "ERROR! save_overlay parameter must be set to either false (off) or true (on)"
    assert params.save_mask instanceof Boolean, "ERROR! save_mask parameter must be set to either false (off) or true (on)"
    assert params.save_rosette instanceof Boolean, "ERROR! save_rosette parameter must be set to either false (off) or true (on)"
    assert params.save_hull instanceof Boolean, "ERROR! save_hull parameter must be set to either false (off) or true (on)"
    assert params.polaroid instanceof Boolean, "ERROR! polaroid parameter must be set to either false (off) or true (on)"
    assert params.summary_diagnostics instanceof Boolean, "ERROR! summary_diagnostics parameter must be set to either false (off) or true (on)"
    assert params.shiny instanceof Boolean, "ERROR! shiny parameter must be set to either false (off) or true (on)"
  }
}