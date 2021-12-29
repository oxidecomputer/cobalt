// Copyright 2021 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include <optional>
#include <vector>
#include <string>

struct Pixel
{
  char r;
  char g;
  char b;
};

typedef unsigned int uint;

struct VideoSourceValidation {
public:
  static constexpr std::optional<uint> try_decode_as_control(uint c);
  static constexpr std::optional<uint> try_decode_as_terc4(uint c);
  static constexpr bool is_video_preamble(uint ch0, uint ch1, uint ch2);
  static constexpr bool is_video_guard_band(uint ch0, uint ch1, uint ch2);
  static uint decode_data(uint c);
  void validate_characters(uint ch0, uint ch1, uint ch2);
  void save_frame_buffer(std::string& file_path, uint h_active, uint v_active);

  bool previous_h_sync{false};
  bool previous_v_sync{false};

  bool control_period{false};
  bool video_data_period{false};
  bool video_preamble{false};
  bool video_guard_band{false};

  uint frames{0};
  uint control_period_dots{0};
  uint preamble_dots{0};
  uint guard_band_dots{0};

  uint previous_h_active_dots{0};
  uint h_active_dots{0};
  uint v_active_lines{0};

  std::vector<Pixel> buffer{};
};
