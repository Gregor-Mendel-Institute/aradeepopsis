class ParameterChecks {
  static void checkParams(params) {
    assert params.images, "ERROR! Images in png or jpeg format have to be provided!"
    assert params.chunksize instanceof Integer, "ERROR! chunksize parameter has to be an integer!"
    assert params.model in 1..3, "ERROR! model parameter must be between 1 and 3!"
    assert params.multiscale instanceof Boolean, "ERROR! multiscale parameter must be set to either false (off) or true (on)"
    assert params.save_overlay instanceof Boolean, "ERROR! save_overlay parameter must be set to either false (off) or true (on)"
    assert params.save_mask instanceof Boolean, "ERROR! save_mask parameter must be set to either false (off) or true (on)"
    assert params.save_original instanceof Boolean, "ERROR! save_original parameter must be set to either false (off) or true (on)"
    assert params.save_rosette instanceof Boolean, "ERROR! save_rosette parameter must be set to either false (off) or true (on)"
    assert params.save_hull instanceof Boolean, "ERROR! save_hull parameter must be set to either false (off) or true (on)"
    assert params.save_histogram instanceof Boolean, "ERROR! save_histogram parameter must be set to either false (off) or true (on)"
    assert params.polaroid instanceof Boolean, "ERROR! polaroid parameter must be set to either false (off) or true (on)"
  }
}